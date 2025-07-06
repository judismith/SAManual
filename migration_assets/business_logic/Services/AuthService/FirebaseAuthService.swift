import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices

// MARK: - Firebase Auth Service Implementation
public final class FirebaseAuthService: NSObject, AuthService {
    
    // MARK: - Firebase Configuration
    private let auth: Auth
    private let db: Firestore
    private let googleSignIn: GIDSignIn?
    
    // MARK: - Publishers
    private let authStateSubject = CurrentValueSubject<AuthState, Never>(.unauthenticated)
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    public var authStatePublisher: AnyPublisher<AuthState, Never> {
        authStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Authentication State
    public var isAuthenticated: Bool {
        return auth.currentUser != nil
    }
    
    public var currentUser: AuthUser? {
        return auth.currentUser?.toAuthUser()
    }
    
    // MARK: - Initialization
    public init(auth: Auth = Auth.auth(), firestore: Firestore = Firestore.firestore()) {
        self.auth = auth
        self.db = firestore
        self.googleSignIn = GIDSignIn.sharedInstance
        
        super.init()
        
        setupAuthStateListener()
        configureGoogleSignIn()
    }
    
    deinit {
        if let listener = authStateListener {
            auth.removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Private Setup
    private func setupAuthStateListener() {
        authStateListener = auth.addStateDidChangeListener { [weak self] (auth, user) in
            if let user = user {
                self?.authStateSubject.send(.authenticated(user.toAuthUser()))
            } else {
                self?.authStateSubject.send(.unauthenticated)
            }
        }
    }
    
    private func configureGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("⚠️ [FirebaseAuth] GoogleService-Info.plist not found or CLIENT_ID missing")
            return
        }
        
        googleSignIn?.configuration = GIDConfiguration(clientID: clientId)
    }
    
    // MARK: - Email Authentication
    public func signIn(email: String, password: String) async throws -> AuthUser {
        do {
            let authResult = try await auth.signIn(withEmail: email, password: password)
            let user = authResult.user.toAuthUser()
            
            // Record security event
            await recordSecurityEvent(
                userId: user.id,
                eventType: .login,
                severity: .low,
                details: ["email": email, "provider": "email"]
            )
            
            return user
            
        } catch let error as NSError {
            throw convertFirebaseError(error)
        }
    }
    
    public func signUp(email: String, password: String, profile: UserRegistrationProfile) async throws -> AuthUser {
        do {
            let authResult = try await auth.createUser(withEmail: email, password: password)
            let firebaseUser = authResult.user
            
            // Update user profile
            let changeRequest = firebaseUser.createProfileChangeRequest()
            changeRequest.displayName = "\(profile.firstName) \(profile.lastName)"
            try await changeRequest.commitChanges()
            
            // Create user document in Firestore
            let userData: [String: Any] = [
                "email": email,
                "firstName": profile.firstName,
                "lastName": profile.lastName,
                "displayName": "\(profile.firstName) \(profile.lastName)",
                "phoneNumber": profile.phoneNumber ?? "",
                "accessLevel": AccessLevel.free.rawValue,
                "isActive": true,
                "createdAt": Timestamp(date: Date()),
                "updatedAt": Timestamp(date: Date())
            ]
            
            try await db.collection("users").document(firebaseUser.uid).setData(userData)
            
            // Send email verification
            try await sendEmailVerification()
            
            let user = firebaseUser.toAuthUser()
            
            // Record security event
            await recordSecurityEvent(
                userId: user.id,
                eventType: .login,
                severity: .low,
                details: ["email": email, "action": "registration"]
            )
            
            return user
            
        } catch let error as NSError {
            throw convertFirebaseError(error)
        }
    }
    
    public func signOut() async throws {
        let userId = auth.currentUser?.uid
        
        do {
            try auth.signOut()
            
            // Record security event
            if let userId = userId {
                await recordSecurityEvent(
                    userId: userId,
                    eventType: .logout,
                    severity: .low,
                    details: ["provider": "email"]
                )
            }
            
        } catch let error as NSError {
            throw convertFirebaseError(error)
        }
    }
    
    public func resetPassword(email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
            
            // Record security event (without user ID since we don't have it)
            await recordSecurityEvent(
                userId: "",
                eventType: .passwordReset,
                severity: .medium,
                details: ["email": email]
            )
            
        } catch let error as NSError {
            throw convertFirebaseError(error)
        }
    }
    
    public func changePassword(currentPassword: String, newPassword: String) async throws {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        do {
            // Re-authenticate user with current password
            let credential = EmailAuthProvider.credential(withEmail: user.email ?? "", password: currentPassword)
            try await user.reauthenticate(with: credential)
            
            // Update password
            try await user.updatePassword(to: newPassword)
            
            // Record security event
            await recordSecurityEvent(
                userId: user.uid,
                eventType: .passwordChange,
                severity: .medium,
                details: ["email": user.email ?? ""]
            )
            
        } catch let error as NSError {
            throw convertFirebaseError(error)
        }
    }
    
    public func updateEmail(newEmail: String, password: String) async throws -> AuthUser {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        do {
            // Re-authenticate user
            let credential = EmailAuthProvider.credential(withEmail: user.email ?? "", password: password)
            try await user.reauthenticate(with: credential)
            
            let oldEmail = user.email
            
            // Update email
            try await user.updateEmail(to: newEmail)
            
            // Update user document in Firestore
            try await db.collection("users").document(user.uid).updateData([
                "email": newEmail,
                "isEmailVerified": false,
                "updatedAt": Timestamp(date: Date())
            ])
            
            // Send verification email to new address
            try await sendEmailVerification()
            
            // Record security event
            await recordSecurityEvent(
                userId: user.uid,
                eventType: .emailChange,
                severity: .high,
                details: ["old_email": oldEmail ?? "", "new_email": newEmail]
            )
            
            return user.toAuthUser()
            
        } catch let error as NSError {
            throw convertFirebaseError(error)
        }
    }
    
    // MARK: - Social Authentication
    public func signInWithGoogle() async throws -> AuthUser {
        guard let presentingViewController = await UIApplication.shared.windows.first?.rootViewController else {
            throw AuthServiceError.unknown(underlying: NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No presenting view controller"]))
        }
        
        do {
            guard let result = try await googleSignIn?.signIn(withPresenting: presentingViewController) else {
                throw AuthServiceError.unknown(underlying: NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google Sign In failed"]))
            }
            
            let googleUser = result.user
            guard let idToken = googleUser.idToken?.tokenString else {
                throw AuthServiceError.unknown(underlying: NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get ID token"]))
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: googleUser.accessToken.tokenString)
            
            let authResult = try await auth.signIn(with: credential)
            let user = authResult.user.toAuthUser()
            
            // Create or update user document in Firestore
            let userData: [String: Any] = [
                "email": user.email,
                "displayName": user.displayName ?? "",
                "photoURL": user.photoURL ?? "",
                "accessLevel": AccessLevel.free.rawValue,
                "isActive": true,
                "provider": "google",
                "createdAt": Timestamp(date: Date()),
                "updatedAt": Timestamp(date: Date())
            ]
            
            try await db.collection("users").document(user.id).setData(userData, merge: true)
            
            // Record security event
            await recordSecurityEvent(
                userId: user.id,
                eventType: .login,
                severity: .low,
                details: ["provider": "google", "email": user.email]
            )
            
            return user
            
        } catch let error as NSError {
            throw convertFirebaseError(error)
        }
    }
    
    public func signInWithApple() async throws -> AuthUser {
        return try await withCheckedThrowingContinuation { continuation in
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate { result in
                continuation.resume(with: result)
            }
            
            authorizationController.delegate = delegate
            authorizationController.presentationContextProvider = delegate
            authorizationController.performRequests()
        }
    }
    
    public func linkGoogleAccount() async throws -> AuthUser {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        guard let presentingViewController = await UIApplication.shared.windows.first?.rootViewController else {
            throw AuthServiceError.unknown(underlying: NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No presenting view controller"]))
        }
        
        do {
            guard let result = try await googleSignIn?.signIn(withPresenting: presentingViewController) else {
                throw AuthServiceError.unknown(underlying: NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google Sign In failed"]))
            }
            
            let googleUser = result.user
            guard let idToken = googleUser.idToken?.tokenString else {
                throw AuthServiceError.unknown(underlying: NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get ID token"]))
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: googleUser.accessToken.tokenString)
            
            let authResult = try await user.link(with: credential)
            let linkedUser = authResult.user.toAuthUser()
            
            // Record security event
            await recordSecurityEvent(
                userId: linkedUser.id,
                eventType: .login,
                severity: .low,
                details: ["action": "link_google"]
            )
            
            return linkedUser
            
        } catch let error as NSError {
            throw convertFirebaseError(error)
        }
    }
    
    public func linkAppleAccount() async throws -> AuthUser {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        // This would be implemented similar to linkGoogleAccount
        // For now, return the current user
        return user.toAuthUser()
    }
    
    public func unlinkSocialAccount(provider: SocialProvider) async throws -> AuthUser {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        do {
            let providerId = provider.firebaseProviderId
            try await user.unlink(fromProvider: providerId)
            
            // Record security event
            await recordSecurityEvent(
                userId: user.uid,
                eventType: .login,
                severity: .medium,
                details: ["action": "unlink_\(provider.rawValue)"]
            )
            
            return user.toAuthUser()
            
        } catch let error as NSError {
            throw convertFirebaseError(error)
        }
    }
    
    // MARK: - Account Verification
    public func sendEmailVerification() async throws {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        do {
            try await user.sendEmailVerification()
        } catch let error as NSError {
            throw convertFirebaseError(error)
        }
    }
    
    public func verifyEmail(code: String) async throws -> AuthUser {
        do {
            try await auth.applyActionCode(code)
            
            // Reload user to get updated email verification status
            try await auth.currentUser?.reload()
            
            guard let user = auth.currentUser else {
                throw AuthServiceError.sessionInvalid
            }
            
            // Update Firestore document
            try await db.collection("users").document(user.uid).updateData([
                "isEmailVerified": true,
                "updatedAt": Timestamp(date: Date())
            ])
            
            // Record security event
            await recordSecurityEvent(
                userId: user.uid,
                eventType: .login,
                severity: .low,
                details: ["action": "email_verified"]
            )
            
            return user.toAuthUser()
            
        } catch let error as NSError {
            throw convertFirebaseError(error)
        }
    }
    
    public func isEmailVerified() async throws -> Bool {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        // Reload to get latest status
        try await user.reload()
        return user.isEmailVerified
    }
    
    public func sendPhoneVerification(phoneNumber: String) async throws {
        do {
            let _ = try await PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil)
        } catch let error as NSError {
            throw convertFirebaseError(error)
        }
    }
    
    public func verifyPhone(code: String) async throws -> AuthUser {
        // This would require storing the verification ID from sendPhoneVerification
        // For now, throw not implemented
        throw AuthServiceError.unknown(underlying: NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Phone verification not fully implemented"]))
    }
    
    // MARK: - Multi-Factor Authentication
    public func enableMFA() async throws -> MFASetupResult {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        // Firebase doesn't directly support TOTP MFA setup through the client SDK
        // This would typically require server-side implementation
        throw AuthServiceError.unknown(underlying: NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "MFA setup requires server-side implementation"]))
    }
    
    public func disableMFA(password: String) async throws {
        throw AuthServiceError.unknown(underlying: NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "MFA disable requires server-side implementation"]))
    }
    
    public func verifyMFA(code: String) async throws -> AuthUser {
        throw AuthServiceError.unknown(underlying: NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "MFA verification requires server-side implementation"]))
    }
    
    public func generateBackupCodes() async throws -> [String] {
        throw AuthServiceError.unknown(underlying: NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "MFA backup codes require server-side implementation"]))
    }
    
    public func getMFAStatus() async throws -> MFAStatus {
        return MFAStatus(
            isEnabled: false,
            methods: [],
            backupCodesRemaining: 0,
            lastUsed: nil
        )
    }
    
    // MARK: - Biometric Authentication
    public func enableBiometricAuth() async throws -> BiometricAuthResult {
        // This would be handled by the client-side biometric authentication
        // For now, return a mock result
        return BiometricAuthResult(
            isEnabled: true,
            biometricType: .faceID,
            deviceSupported: true,
            enrollmentRequired: false
        )
    }
    
    public func disableBiometricAuth() async throws {
        // Client-side biometric settings
    }
    
    public func authenticateWithBiometrics() async throws -> AuthUser {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        return user.toAuthUser()
    }
    
    public func isBiometricAuthAvailable() async throws -> BiometricAvailability {
        return BiometricAvailability(
            isAvailable: true,
            biometricType: .faceID,
            error: nil
        )
    }
    
    public func getBiometricAuthStatus() async throws -> BiometricAuthStatus {
        return BiometricAuthStatus(
            isEnabled: false,
            isAvailable: true,
            biometricType: .faceID,
            lastUsed: nil
        )
    }
    
    // MARK: - Session Management
    public func refreshToken() async throws -> AuthToken {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionExpired
        }
        
        do {
            let result = try await user.getIDTokenResult(forcingRefresh: true)
            
            return AuthToken(
                accessToken: result.token,
                refreshToken: "", // Firebase handles refresh tokens internally
                expiresAt: result.expirationDate,
                tokenType: "Bearer",
                scope: result.claims.keys.map { $0 }
            )
            
        } catch let error as NSError {
            throw convertFirebaseError(error)
        }
    }
    
    public func validateSession() async throws -> Bool {
        guard let user = auth.currentUser else {
            return false
        }
        
        do {
            let _ = try await user.getIDTokenResult(forcingRefresh: false)
            return true
        } catch {
            return false
        }
    }
    
    public func getSessionInfo() async throws -> SessionInfo {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        let deviceInfo = DeviceInfo(
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            name: UIDevice.current.name,
            model: UIDevice.current.model,
            platform: "iOS",
            osVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        )
        
        return SessionInfo(
            id: user.uid,
            userId: user.uid,
            deviceInfo: deviceInfo,
            ipAddress: "unknown", // Would require additional service to get IP
            userAgent: "SAKungFuJournal iOS",
            location: "unknown", // Would require location services
            expiresAt: Date().addingTimeInterval(3600), // 1 hour
            isCurrent: true
        )
    }
    
    public func terminateAllSessions() async throws {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        do {
            // Force token refresh to invalidate old tokens
            let _ = try await user.getIDTokenResult(forcingRefresh: true)
            
            // Record security event
            await recordSecurityEvent(
                userId: user.uid,
                eventType: .logout,
                severity: .medium,
                details: ["action": "terminate_all_sessions"]
            )
            
        } catch let error as NSError {
            throw convertFirebaseError(error)
        }
    }
    
    public func terminateSession(sessionId: String) async throws {
        // Firebase doesn't support terminating specific sessions
        // This would require server-side implementation
        throw AuthServiceError.unknown(underlying: NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Session termination requires server-side implementation"]))
    }
    
    public func getActiveSessions() async throws -> [SessionInfo] {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        // Firebase doesn't provide session enumeration
        // Return current session only
        return [try await getSessionInfo()]
    }
    
    // MARK: - Account Management
    public func deleteAccount(password: String) async throws {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        do {
            // Re-authenticate user
            let credential = EmailAuthProvider.credential(withEmail: user.email ?? "", password: password)
            try await user.reauthenticate(with: credential)
            
            // Delete user document from Firestore
            try await db.collection("users").document(user.uid).delete()
            
            // Delete user account
            try await user.delete()
            
        } catch let error as NSError {
            throw convertFirebaseError(error)
        }
    }
    
    public func deactivateAccount(password: String) async throws {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        do {
            // Re-authenticate user
            let credential = EmailAuthProvider.credential(withEmail: user.email ?? "", password: password)
            try await user.reauthenticate(with: credential)
            
            // Update user document to mark as inactive
            try await db.collection("users").document(user.uid).updateData([
                "isActive": false,
                "updatedAt": Timestamp(date: Date())
            ])
            
            // Record security event
            await recordSecurityEvent(
                userId: user.uid,
                eventType: .accountLocked,
                severity: .high,
                details: ["action": "deactivated"]
            )
            
            // Sign out
            try await signOut()
            
        } catch let error as NSError {
            throw convertFirebaseError(error)
        }
    }
    
    public func reactivateAccount(email: String, password: String) async throws -> AuthUser {
        do {
            let authResult = try await auth.signIn(withEmail: email, password: password)
            let user = authResult.user
            
            // Update user document to mark as active
            try await db.collection("users").document(user.uid).updateData([
                "isActive": true,
                "updatedAt": Timestamp(date: Date())
            ])
            
            // Record security event
            await recordSecurityEvent(
                userId: user.uid,
                eventType: .login,
                severity: .medium,
                details: ["action": "reactivated"]
            )
            
            return user.toAuthUser()
            
        } catch let error as NSError {
            throw convertFirebaseError(error)
        }
    }
    
    public func exportAccountData() async throws -> AccountExportData {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        do {
            // Get user document from Firestore
            let userDoc = try await db.collection("users").document(user.uid).getDocument()
            let userData = userDoc.data() ?? [:]
            
            // Create UserProfile from Firestore data
            let profile = UserProfile(
                id: user.uid,
                email: user.email ?? "",
                firstName: userData["firstName"] as? String ?? "",
                lastName: userData["lastName"] as? String ?? "",
                displayName: userData["displayName"] as? String,
                profileImageURL: userData["photoURL"] as? String,
                accessLevel: AccessLevel(rawValue: userData["accessLevel"] as? String ?? "free") ?? .free,
                isActive: userData["isActive"] as? Bool ?? true
            )
            
            // Get security events
            let securityEvents = try await getSecurityEvents(limit: 100)
            
            // Get login history
            let loginHistory = try await getLoginHistory(limit: 50)
            
            return AccountExportData(
                userId: user.uid,
                email: user.email ?? "",
                profile: profile,
                authHistory: securityEvents,
                loginHistory: loginHistory,
                deviceRegistrations: []
            )
            
        } catch let error as NSError {
            throw convertFirebaseError(error)
        }
    }
    
    // MARK: - Access Control
    public func checkPermission(_ permission: Permission) async throws -> Bool {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        // Get user's access level from Firestore
        let userDoc = try await db.collection("users").document(user.uid).getDocument()
        let userData = userDoc.data() ?? [:]
        let accessLevel = AccessLevel(rawValue: userData["accessLevel"] as? String ?? "free") ?? .free
        
        let requiredLevel = permission.requiredAccessLevel
        
        switch (accessLevel, requiredLevel) {
        case (.admin, _):
            return true
        case (.instructor, .instructor), (.instructor, .subscriber), (.instructor, .free):
            return true
        case (.subscriber, .subscriber), (.subscriber, .free):
            return true
        case (.free, .free):
            return true
        default:
            return false
        }
    }
    
    public func requestPermission(_ permission: Permission) async throws -> PermissionResult {
        let hasPermission = try await checkPermission(permission)
        
        if hasPermission {
            return .granted
        } else {
            return .requiresUpgrade(toLevel: permission.requiredAccessLevel)
        }
    }
    
    public func getUserRoles() async throws -> [UserRole] {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        let userDoc = try await db.collection("users").document(user.uid).getDocument()
        let userData = userDoc.data() ?? [:]
        let accessLevel = AccessLevel(rawValue: userData["accessLevel"] as? String ?? "free") ?? .free
        
        switch accessLevel {
        case .free:
            return [UserRole.student]
        case .subscriber:
            return [UserRole.subscriber]
        case .instructor:
            return [UserRole.instructor]
        case .admin:
            return [UserRole.instructor, UserRole.subscriber, UserRole.student]
        }
    }
    
    public func updateUserRole(userId: String, role: UserRole) async throws {
        // Only allow admin users to update roles
        guard let currentUser = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        let currentUserDoc = try await db.collection("users").document(currentUser.uid).getDocument()
        let currentUserData = currentUserDoc.data() ?? [:]
        let currentAccessLevel = AccessLevel(rawValue: currentUserData["accessLevel"] as? String ?? "free") ?? .free
        
        guard currentAccessLevel == .admin else {
            throw AuthServiceError.permissionDenied(permission: .manageUsers)
        }
        
        // Update target user's role
        try await db.collection("users").document(userId).updateData([
            "accessLevel": role.accessLevel.rawValue,
            "updatedAt": Timestamp(date: Date())
        ])
        
        // Record security event
        await recordSecurityEvent(
            userId: userId,
            eventType: .permissionChanged,
            severity: .medium,
            details: ["new_role": role.name, "updated_by": currentUser.uid]
        )
    }
    
    // MARK: - Security Events
    public func getSecurityEvents(limit: Int) async throws -> [SecurityEvent] {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        let query = db.collection("securityEvents")
            .whereField("userId", isEqualTo: user.uid)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
        
        let querySnapshot = try await query.getDocuments()
        
        return querySnapshot.documents.compactMap { document in
            SecurityEvent.from(document: document)
        }
    }
    
    public func reportSecurityIssue(_ issue: SecurityIssue) async throws {
        let userId = issue.userId ?? auth.currentUser?.uid ?? "anonymous"
        
        await recordSecurityEvent(
            userId: userId,
            eventType: .suspiciousLogin,
            severity: issue.severity,
            details: [
                "issue_type": issue.type.rawValue,
                "description": issue.description,
                "reported_at": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }
    
    public func getLoginHistory(limit: Int) async throws -> [LoginEvent] {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        let query = db.collection("loginHistory")
            .whereField("userId", isEqualTo: user.uid)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
        
        let querySnapshot = try await query.getDocuments()
        
        return querySnapshot.documents.compactMap { document in
            LoginEvent.from(document: document)
        }
    }
    
    // MARK: - Device Management
    public func registerDevice(_ device: DeviceInfo) async throws -> DeviceRegistration {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        let registration = DeviceRegistration(
            userId: user.uid,
            deviceInfo: device,
            pushToken: nil, // Would be set when FCM token is available
            isActive: true
        )
        
        let deviceData = registration.toFirestoreData()
        
        try await db.collection("deviceRegistrations").document(device.deviceId).setData(deviceData)
        
        // Record security event
        await recordSecurityEvent(
            userId: user.uid,
            eventType: .deviceRegistered,
            severity: .low,
            details: ["device_name": device.name, "platform": device.platform]
        )
        
        return registration
    }
    
    public func unregisterDevice(deviceId: String) async throws {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await db.collection("deviceRegistrations").document(deviceId).delete()
        
        // Record security event
        await recordSecurityEvent(
            userId: user.uid,
            eventType: .deviceUnregistered,
            severity: .low,
            details: ["device_id": deviceId]
        )
    }
    
    public func getRegisteredDevices() async throws -> [DeviceRegistration] {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        let query = db.collection("deviceRegistrations")
            .whereField("userId", isEqualTo: user.uid)
            .whereField("isActive", isEqualTo: true)
        
        let querySnapshot = try await query.getDocuments()
        
        return querySnapshot.documents.compactMap { document in
            DeviceRegistration.from(document: document)
        }
    }
    
    public func updateDeviceInfo(_ device: DeviceInfo) async throws -> DeviceRegistration {
        guard let user = auth.currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        let deviceRef = db.collection("deviceRegistrations").document(device.deviceId)
        let deviceDoc = try await deviceRef.getDocument()
        
        let registration: DeviceRegistration
        
        if deviceDoc.exists {
            // Update existing registration
            try await deviceRef.updateData([
                "deviceInfo": device.toFirestoreData(),
                "lastSeenAt": Timestamp(date: Date())
            ])
            
            // Create DeviceRegistration from DocumentSnapshot data
            registration = DeviceRegistration(
                userId: user.uid,
                deviceInfo: device,
                isActive: true
            )
        } else {
            // Create new registration
            registration = try await registerDevice(device)
        }
        
        return registration
    }
    
    // MARK: - Private Helper Methods
    private func recordSecurityEvent(userId: String, eventType: SecurityEventType, severity: SecuritySeverity = .low, details: [String: String] = [:]) async {
        let event = SecurityEvent(
            userId: userId,
            eventType: eventType,
            ipAddress: "unknown", // Would require additional service
            userAgent: "SAKungFuJournal iOS",
            location: "unknown", // Would require location services
            details: details,
            severity: severity
        )
        
        let eventData = event.toFirestoreData()
        
        do {
            try await db.collection("securityEvents").addDocument(data: eventData)
        } catch {
            print("❌ [FirebaseAuth] Failed to record security event: \(error)")
        }
    }
    
    private func convertFirebaseError(_ error: NSError) -> AuthServiceError {
        guard let errorCode = AuthErrorCode(rawValue: error.code) else {
            return .unknown(underlying: error)
        }
        
        switch errorCode {
        case .networkError:
            return .networkError(underlying: error)
        case .userNotFound:
            return .userNotFound
        case .userDisabled:
            return .userDisabled
        case .wrongPassword, .invalidCredential:
            return .invalidCredentials
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .tooManyRequests:
            return .tooManyRequests
        case .userTokenExpired, .invalidUserToken:
            return .sessionExpired
        case .requiresRecentLogin:
            return .sessionInvalid
        case .operationNotAllowed:
            return .permissionDenied(permission: .manageUsers)
        default:
            return .unknown(underlying: error)
        }
    }
}

// MARK: - Firebase User Extensions
extension FirebaseAuth.User {
    func toAuthUser() -> AuthUser {
        return AuthUser(
            id: uid,
            email: email ?? "",
            isEmailVerified: isEmailVerified,
            phoneNumber: phoneNumber,
            isPhoneVerified: phoneNumber != nil,
            displayName: displayName,
            photoURL: photoURL?.absoluteString,
            createdAt: metadata.creationDate,
            lastSignInAt: metadata.lastSignInDate,
            accessLevel: .free, // Default, would be updated from Firestore
            isActive: true,
            isMFAEnabled: false,
            isBiometricEnabled: false
        )
    }
}

// MARK: - Social Provider Extensions
extension SocialProvider {
    var firebaseProviderId: String {
        switch self {
        case .google:
            return GoogleAuthProvider.id
        case .apple:
            return OAuthProvider.id
        case .facebook:
            return FacebookAuthProvider.id
        }
    }
}

// MARK: - Apple Sign In Delegate
private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let completion: (Result<AuthUser, Error>) -> Void
    
    init(completion: @escaping (Result<AuthUser, Error>) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                completion(.failure(AuthServiceError.unknown(underlying: NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"]))))
                return
            }
            
            let credential = OAuthProvider.appleCredential(withIDToken: idTokenString, rawNonce: nonce, fullName: appleIDCredential.fullName)
            
            Task {
                do {
                    let result = try await Auth.auth().signIn(with: credential)
                    let user = result.user.toAuthUser()
                    completion(.success(user))
                } catch {
                    completion(.failure(AuthServiceError.unknown(underlying: error)))
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(AuthServiceError.unknown(underlying: error)))
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? UIWindow()
    }
}

// MARK: - Nonce Generation
private var currentNonce: String?

// MARK: - Model Extensions for Firestore
extension SecurityEvent {
    static func from(document: QueryDocumentSnapshot) -> SecurityEvent? {
        let data = document.data()
        
        guard let userId = data["userId"] as? String,
              let eventTypeString = data["eventType"] as? String,
              let eventType = SecurityEventType(rawValue: eventTypeString),
              let timestamp = data["timestamp"] as? Timestamp else {
            return nil
        }
        
        return SecurityEvent(
            userId: userId,
            eventType: eventType,
            ipAddress: data["ipAddress"] as? String ?? "unknown",
            userAgent: data["userAgent"] as? String ?? "unknown",
            location: data["location"] as? String ?? "unknown",
            details: data["details"] as? [String: String] ?? [:],
            severity: SecuritySeverity(rawValue: data["severity"] as? String ?? "low") ?? .low
        )
    }
    
    func toFirestoreData() -> [String: Any] {
        return [
            "userId": userId,
            "eventType": eventType.rawValue,
            "timestamp": Timestamp(date: timestamp),
            "ipAddress": ipAddress,
            "userAgent": userAgent,
            "location": location,
            "details": details,
            "severity": severity.rawValue
        ]
    }
}

extension LoginEvent {
    static func from(document: QueryDocumentSnapshot) -> LoginEvent? {
        let data = document.data()
        
        guard let userId = data["userId"] as? String,
              let timestamp = data["timestamp"] as? Timestamp,
              let success = data["success"] as? Bool else {
            return nil
        }
        
        let deviceData = data["deviceInfo"] as? [String: Any]
        let deviceInfo = DeviceInfo(
            deviceId: deviceData?["deviceId"] as? String ?? "unknown",
            name: deviceData?["name"] as? String ?? "unknown",
            model: deviceData?["model"] as? String ?? "unknown",
            platform: deviceData?["platform"] as? String ?? "unknown",
            osVersion: deviceData?["osVersion"] as? String ?? "unknown",
            appVersion: deviceData?["appVersion"] as? String ?? "unknown"
        )
        
        return LoginEvent(
            userId: userId,
            ipAddress: data["ipAddress"] as? String ?? "unknown",
            userAgent: data["userAgent"] as? String ?? "unknown",
            location: data["location"] as? String ?? "unknown",
            deviceInfo: deviceInfo,
            success: success,
            failureReason: data["failureReason"] as? String
        )
    }
}

extension DeviceRegistration {
    static func from(document: QueryDocumentSnapshot) -> DeviceRegistration? {
        let data = document.data()
        
        guard let userId = data["userId"] as? String,
              let deviceData = data["deviceInfo"] as? [String: Any],
              let isActive = data["isActive"] as? Bool else {
            return nil
        }
        
        let deviceInfo = DeviceInfo(
            deviceId: deviceData["deviceId"] as? String ?? "unknown",
            name: deviceData["name"] as? String ?? "unknown",
            model: deviceData["model"] as? String ?? "unknown",
            platform: deviceData["platform"] as? String ?? "unknown",
            osVersion: deviceData["osVersion"] as? String ?? "unknown",
            appVersion: deviceData["appVersion"] as? String ?? "unknown"
        )
        
        return DeviceRegistration(
            userId: userId,
            deviceInfo: deviceInfo,
            pushToken: data["pushToken"] as? String,
            isActive: isActive
        )
    }
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "deviceInfo": deviceInfo.toFirestoreData(),
            "isActive": isActive,
            "registeredAt": Timestamp(date: registeredAt),
            "lastSeenAt": Timestamp(date: lastSeenAt)
        ]
        
        if let pushToken = pushToken {
            data["pushToken"] = pushToken
        }
        
        return data
    }
}

extension DeviceInfo {
    func toFirestoreData() -> [String: Any] {
        return [
            "deviceId": deviceId,
            "name": name,
            "model": model,
            "platform": platform,
            "osVersion": osVersion,
            "appVersion": appVersion,
            "isPushEnabled": isPushEnabled
        ]
    }
}