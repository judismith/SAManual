import Foundation
import Combine

// MARK: - Mock Auth Service Implementation
public final class MockAuthService: AuthService {
    
    // MARK: - In-Memory Storage
    private var users: [String: AuthUser] = [:]
    private var sessions: [String: SessionInfo] = [:]
    private var securityEvents: [String: [SecurityEvent]] = [:]
    private var loginHistory: [String: [LoginEvent]] = [:]
    private var deviceRegistrations: [String: [DeviceRegistration]] = [:]
    private var _currentUser: AuthUser?
    private var currentSession: SessionInfo?
    
    // MARK: - Authentication State
    public var isAuthenticated: Bool {
        return _currentUser != nil
    }
    
    public var currentUser: AuthUser? {
        return _currentUser
    }
    
    // MARK: - Publishers
    private let authStateSubject = CurrentValueSubject<AuthState, Never>(.unauthenticated)
    
    public var authStatePublisher: AnyPublisher<AuthState, Never> {
        authStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    public init() {
        seedSampleData()
    }
    
    // MARK: - Email Authentication
    public func signIn(email: String, password: String) async throws -> AuthUser {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Find user by email
        guard let user = users.values.first(where: { $0.email == email }) else {
            await recordSecurityEvent(userId: "", eventType: .login, severity: .medium, details: ["email": email, "result": "user_not_found"])
            throw AuthServiceError.userNotFound
        }
        
        // Mock password validation (in reality, this would be properly hashed)
        let expectedPassword = "password123" // Mock password for all users
        guard password == expectedPassword else {
            await recordSecurityEvent(userId: user.id, eventType: .login, severity: .medium, details: ["email": email, "result": "invalid_password"])
            await recordLoginEvent(userId: user.id, success: false, failureReason: "Invalid password")
            throw AuthServiceError.invalidCredentials
        }
        
        // Check if user is active
        guard user.isActive else {
            await recordSecurityEvent(userId: user.id, eventType: .login, severity: .high, details: ["email": email, "result": "account_disabled"])
            throw AuthServiceError.userDisabled
        }
        
        // Create updated user with new lastSignInAt (since AuthUser is immutable)
        let updatedUser = AuthUser(
            id: user.id,
            email: user.email,
            isEmailVerified: user.isEmailVerified,
            phoneNumber: user.phoneNumber,
            isPhoneVerified: user.isPhoneVerified,
            displayName: user.displayName,
            photoURL: user.photoURL,
            createdAt: user.createdAt,
            lastSignInAt: Date(),
            metadata: user.metadata,
            providerData: user.providerData,
            customClaims: user.customClaims,
            accessLevel: user.accessLevel,
            roles: user.roles,
            isActive: user.isActive,
            isMFAEnabled: user.isMFAEnabled,
            isBiometricEnabled: user.isBiometricEnabled
        )
        users[user.id] = updatedUser
        
        // Set current user and session
        _currentUser = updatedUser
        currentSession = createSession(for: updatedUser)
        
        // Record successful login
        await recordSecurityEvent(userId: updatedUser.id, eventType: .login, severity: .low, details: ["email": email, "result": "success"])
        await recordLoginEvent(userId: updatedUser.id, success: true)
        
        // Update auth state
        authStateSubject.send(.authenticated(updatedUser))
        
        return updatedUser
    }
    
    public func signUp(email: String, password: String, profile: UserRegistrationProfile) async throws -> AuthUser {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Check for duplicate email
        if users.values.contains(where: { $0.email == email }) {
            throw AuthServiceError.emailAlreadyInUse
        }
        
        // Validate password strength (mock validation)
        if password.count < 8 {
            throw AuthServiceError.weakPassword
        }
        
        // Create new user
        let userId = UUID().uuidString
        let newUser = AuthUser(
            id: userId,
            email: email,
            isEmailVerified: false,
            phoneNumber: profile.phoneNumber,
            isPhoneVerified: false,
            displayName: "\(profile.firstName) \(profile.lastName)",
            createdAt: Date(),
            lastSignInAt: Date(),
            accessLevel: .free,
            isActive: true,
            isMFAEnabled: false,
            isBiometricEnabled: false
        )
        
        users[userId] = newUser
        
        // Set as current user
        _currentUser = newUser
        currentSession = createSession(for: newUser)
        
        // Record registration event
        await recordSecurityEvent(userId: userId, eventType: .login, severity: .low, details: ["email": email, "result": "registration_success"])
        
        // Update auth state
        authStateSubject.send(.authenticated(newUser))
        
        return newUser
    }
    
    public func signOut() async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        if let user = currentUser {
            await recordSecurityEvent(userId: user.id, eventType: .logout, severity: .low, details: ["email": user.email])
        }
        
        // Clear current user and session
        if let session = currentSession {
            sessions.removeValue(forKey: session.id)
        }
        
        _currentUser = nil
        currentSession = nil
        
        // Update auth state
        authStateSubject.send(.unauthenticated)
    }
    
    public func resetPassword(email: String) async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        guard let user = users.values.first(where: { $0.email == email }) else {
            throw AuthServiceError.userNotFound
        }
        
        await recordSecurityEvent(userId: user.id, eventType: .passwordReset, severity: .medium, details: ["email": email])
        
        // In a real implementation, this would send a reset email
        print("🔐 [MOCK] Password reset email sent to \(email)")
    }
    
    public func changePassword(currentPassword: String, newPassword: String) async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        // Mock current password validation
        guard currentPassword == "password123" else {
            throw AuthServiceError.invalidCredentials
        }
        
        // Validate new password strength
        if newPassword.count < 8 {
            throw AuthServiceError.weakPassword
        }
        
        await recordSecurityEvent(userId: user.id, eventType: .passwordChange, severity: .medium, details: ["email": user.email])
        
        print("🔐 [MOCK] Password changed for user \(user.email)")
    }
    
    public func updateEmail(newEmail: String, password: String) async throws -> AuthUser {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        // Validate password
        guard password == "password123" else {
            throw AuthServiceError.invalidCredentials
        }
        
        // Check for duplicate email
        if users.values.contains(where: { $0.email == newEmail && $0.id != user.id }) {
            throw AuthServiceError.emailAlreadyInUse
        }
        
        let oldEmail = user.email
        
        // Create updated user with new email (since AuthUser is immutable)
        let updatedUser = AuthUser(
            id: user.id,
            email: newEmail,
            isEmailVerified: false, // Need to re-verify new email
            phoneNumber: user.phoneNumber,
            isPhoneVerified: user.isPhoneVerified,
            displayName: user.displayName,
            photoURL: user.photoURL,
            createdAt: user.createdAt,
            lastSignInAt: user.lastSignInAt,
            metadata: user.metadata,
            providerData: user.providerData,
            customClaims: user.customClaims,
            accessLevel: user.accessLevel,
            roles: user.roles,
            isActive: user.isActive,
            isMFAEnabled: user.isMFAEnabled,
            isBiometricEnabled: user.isBiometricEnabled
        )
        
        users[user.id] = updatedUser
        _currentUser = updatedUser
        
        await recordSecurityEvent(userId: user.id, eventType: .emailChange, severity: .high, details: ["old_email": oldEmail, "new_email": newEmail])
        
        // Update auth state
        authStateSubject.send(.authenticated(updatedUser))
        
        return updatedUser
    }
    
    // MARK: - Social Authentication
    public func signInWithGoogle() async throws -> AuthUser {
        // Simulate OAuth flow delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Mock Google OAuth response
        let googleUser = AuthUser(
            id: "google-user-123",
            email: "user@gmail.com",
            isEmailVerified: true,
            displayName: "Google User",
            photoURL: "https://lh3.googleusercontent.com/mock-photo",
            accessLevel: .free,
            isActive: true
        )
        
        users[googleUser.id] = googleUser
        _currentUser = googleUser
        currentSession = createSession(for: googleUser)
        
        await recordSecurityEvent(userId: googleUser.id, eventType: .login, severity: .low, details: ["provider": "google", "email": googleUser.email])
        
        authStateSubject.send(.authenticated(googleUser))
        return googleUser
    }
    
    public func signInWithApple() async throws -> AuthUser {
        // Simulate Apple Sign In flow delay
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        let appleUser = AuthUser(
            id: "apple-user-456",
            email: "user@privaterelay.appleid.com",
            isEmailVerified: true,
            displayName: "Apple User",
            accessLevel: .free,
            isActive: true
        )
        
        users[appleUser.id] = appleUser
        _currentUser = appleUser
        currentSession = createSession(for: appleUser)
        
        await recordSecurityEvent(userId: appleUser.id, eventType: .login, severity: .low, details: ["provider": "apple", "email": appleUser.email])
        
        authStateSubject.send(.authenticated(appleUser))
        return appleUser
    }
    
    public func linkGoogleAccount() async throws -> AuthUser {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Mock linking Google account
        users[user.id] = user
        
        await recordSecurityEvent(userId: user.id, eventType: .login, severity: .low, details: ["action": "link_google"])
        
        return user
    }
    
    public func linkAppleAccount() async throws -> AuthUser {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        users[user.id] = user
        
        await recordSecurityEvent(userId: user.id, eventType: .login, severity: .low, details: ["action": "link_apple"])
        
        return user
    }
    
    public func unlinkSocialAccount(provider: SocialProvider) async throws -> AuthUser {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        users[user.id] = user
        
        await recordSecurityEvent(userId: user.id, eventType: .login, severity: .medium, details: ["action": "unlink_\(provider.rawValue)"])
        
        return user
    }
    
    // MARK: - Account Verification
    public func sendEmailVerification() async throws {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        print("📧 [MOCK] Email verification sent to \(user.email)")
    }
    
    public func verifyEmail(code: String) async throws -> AuthUser {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        // Mock verification code validation
        guard code == "123456" else {
            throw AuthServiceError.invalidCredentials
        }
        
        // Create updated user with email verified (since AuthUser is immutable)
        let updatedUser = AuthUser(
            id: user.id,
            email: user.email,
            isEmailVerified: true,
            phoneNumber: user.phoneNumber,
            isPhoneVerified: user.isPhoneVerified,
            displayName: user.displayName,
            photoURL: user.photoURL,
            createdAt: user.createdAt,
            lastSignInAt: user.lastSignInAt,
            metadata: user.metadata,
            providerData: user.providerData,
            customClaims: user.customClaims,
            accessLevel: user.accessLevel,
            roles: user.roles,
            isActive: user.isActive,
            isMFAEnabled: user.isMFAEnabled,
            isBiometricEnabled: user.isBiometricEnabled
        )
        
        users[user.id] = updatedUser
        _currentUser = updatedUser
        
        await recordSecurityEvent(userId: user.id, eventType: .login, severity: .low, details: ["action": "email_verified"])
        
        authStateSubject.send(.authenticated(updatedUser))
        return updatedUser
    }
    
    public func isEmailVerified() async throws -> Bool {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        return user.isEmailVerified
    }
    
    public func sendPhoneVerification(phoneNumber: String) async throws {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        print("📱 [MOCK] SMS verification sent to \(phoneNumber)")
    }
    
    public func verifyPhone(code: String) async throws -> AuthUser {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        guard code == "654321" else {
            throw AuthServiceError.invalidCredentials
        }
        
        let updatedUser = AuthUser(
            id: user.id,
            email: user.email,
            isEmailVerified: user.isEmailVerified,
            phoneNumber: user.phoneNumber,
            isPhoneVerified: true,
            displayName: user.displayName,
            photoURL: user.photoURL,
            createdAt: user.createdAt,
            lastSignInAt: user.lastSignInAt,
            metadata: user.metadata,
            providerData: user.providerData,
            customClaims: user.customClaims,
            accessLevel: user.accessLevel,
            roles: user.roles,
            isActive: user.isActive,
            isMFAEnabled: user.isMFAEnabled,
            isBiometricEnabled: user.isBiometricEnabled
        )
        users[user.id] = updatedUser
        _currentUser = updatedUser
        
        await recordSecurityEvent(userId: user.id, eventType: .login, severity: .low, details: ["action": "phone_verified"])
        
        authStateSubject.send(.authenticated(updatedUser))
        return updatedUser
    }
    
    // MARK: - Multi-Factor Authentication
    public func enableMFA() async throws -> MFASetupResult {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let secret = "MOCK-MFA-SECRET-\(user.id)"
        let qrCodeURL = "https://chart.googleapis.com/chart?chs=200x200&chld=M|0&cht=qr&chl=mock-qr-code"
        let backupCodes = ["12345678", "87654321", "11223344", "44332211", "55667788"]
        
        let updatedUser = AuthUser(
            id: user.id,
            email: user.email,
            isEmailVerified: user.isEmailVerified,
            phoneNumber: user.phoneNumber,
            isPhoneVerified: user.isPhoneVerified,
            displayName: user.displayName,
            photoURL: user.photoURL,
            createdAt: user.createdAt,
            lastSignInAt: user.lastSignInAt,
            metadata: user.metadata,
            providerData: user.providerData,
            customClaims: user.customClaims,
            accessLevel: user.accessLevel,
            roles: user.roles,
            isActive: user.isActive,
            isMFAEnabled: true,
            isBiometricEnabled: user.isBiometricEnabled
        )
        users[user.id] = updatedUser
        _currentUser = updatedUser
        
        await recordSecurityEvent(userId: user.id, eventType: .mfaEnabled, severity: .medium, details: ["email": user.email])
        
        return MFASetupResult(
            secret: secret,
            qrCodeURL: qrCodeURL,
            backupCodes: backupCodes,
            isEnabled: true
        )
    }
    
    public func disableMFA(password: String) async throws {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        guard password == "password123" else {
            throw AuthServiceError.invalidCredentials
        }
        
        let updatedUser = AuthUser(
            id: user.id,
            email: user.email,
            isEmailVerified: user.isEmailVerified,
            phoneNumber: user.phoneNumber,
            isPhoneVerified: user.isPhoneVerified,
            displayName: user.displayName,
            photoURL: user.photoURL,
            createdAt: user.createdAt,
            lastSignInAt: user.lastSignInAt,
            metadata: user.metadata,
            providerData: user.providerData,
            customClaims: user.customClaims,
            accessLevel: user.accessLevel,
            roles: user.roles,
            isActive: user.isActive,
            isMFAEnabled: false,
            isBiometricEnabled: user.isBiometricEnabled
        )
        users[user.id] = updatedUser
        _currentUser = updatedUser
        
        await recordSecurityEvent(userId: user.id, eventType: .mfaDisabled, severity: .medium, details: ["email": user.email])
    }
    
    public func verifyMFA(code: String) async throws -> AuthUser {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Mock MFA code validation
        guard code == "123456" || code == "12345678" else { // TOTP or backup code
            throw AuthServiceError.invalidMFACode
        }
        
        return user
    }
    
    public func generateBackupCodes() async throws -> [String] {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        guard user.isMFAEnabled else {
            throw AuthServiceError.mfaRequired
        }
        
        let backupCodes = ["11111111", "22222222", "33333333", "44444444", "55555555"]
        
        await recordSecurityEvent(userId: user.id, eventType: .login, severity: .medium, details: ["action": "backup_codes_generated"])
        
        return backupCodes
    }
    
    public func getMFAStatus() async throws -> MFAStatus {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        return MFAStatus(
            isEnabled: user.isMFAEnabled,
            methods: user.isMFAEnabled ? [.totp, .backupCodes] : [],
            backupCodesRemaining: user.isMFAEnabled ? 5 : 0,
            lastUsed: user.isMFAEnabled ? Date().addingTimeInterval(-86400) : nil // 1 day ago
        )
    }
    
    // MARK: - Biometric Authentication
    public func enableBiometricAuth() async throws -> BiometricAuthResult {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        let updatedUser = AuthUser(
            id: user.id,
            email: user.email,
            isEmailVerified: user.isEmailVerified,
            phoneNumber: user.phoneNumber,
            isPhoneVerified: user.isPhoneVerified,
            displayName: user.displayName,
            photoURL: user.photoURL,
            createdAt: user.createdAt,
            lastSignInAt: user.lastSignInAt,
            metadata: user.metadata,
            providerData: user.providerData,
            customClaims: user.customClaims,
            accessLevel: user.accessLevel,
            roles: user.roles,
            isActive: user.isActive,
            isMFAEnabled: user.isMFAEnabled,
            isBiometricEnabled: true
        )
        users[user.id] = updatedUser
        _currentUser = updatedUser
        
        await recordSecurityEvent(userId: user.id, eventType: .biometricEnabled, severity: .low, details: ["type": "face_id"])
        
        return BiometricAuthResult(
            isEnabled: true,
            biometricType: .faceID,
            deviceSupported: true,
            enrollmentRequired: false
        )
    }
    
    public func disableBiometricAuth() async throws {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let updatedUser = AuthUser(
            id: user.id,
            email: user.email,
            isEmailVerified: user.isEmailVerified,
            phoneNumber: user.phoneNumber,
            isPhoneVerified: user.isPhoneVerified,
            displayName: user.displayName,
            photoURL: user.photoURL,
            createdAt: user.createdAt,
            lastSignInAt: user.lastSignInAt,
            metadata: user.metadata,
            providerData: user.providerData,
            customClaims: user.customClaims,
            accessLevel: user.accessLevel,
            roles: user.roles,
            isActive: user.isActive,
            isMFAEnabled: user.isMFAEnabled,
            isBiometricEnabled: false
        )
        users[user.id] = updatedUser
        _currentUser = updatedUser
        
        await recordSecurityEvent(userId: user.id, eventType: .biometricDisabled, severity: .low, details: ["type": "face_id"])
    }
    
    public func authenticateWithBiometrics() async throws -> AuthUser {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        guard user.isBiometricEnabled else {
            throw AuthServiceError.biometricNotEnrolled
        }
        
        // Mock biometric authentication (always succeeds in mock)
        return user
    }
    
    public func isBiometricAuthAvailable() async throws -> BiometricAvailability {
        return BiometricAvailability(
            isAvailable: true,
            biometricType: .faceID,
            error: nil
        )
    }
    
    public func getBiometricAuthStatus() async throws -> BiometricAuthStatus {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        return BiometricAuthStatus(
            isEnabled: user.isBiometricEnabled,
            isAvailable: true,
            biometricType: .faceID,
            lastUsed: user.isBiometricEnabled ? Date().addingTimeInterval(-3600) : nil // 1 hour ago
        )
    }
    
    // MARK: - Session Management
    public func refreshToken() async throws -> AuthToken {
        guard let user = currentUser else {
            throw AuthServiceError.sessionExpired
        }
        
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        return AuthToken(
            accessToken: "mock-access-token-\(user.id)",
            refreshToken: "mock-refresh-token-\(user.id)",
            expiresAt: Date().addingTimeInterval(3600), // 1 hour
            tokenType: "Bearer",
            scope: ["read", "write"]
        )
    }
    
    public func validateSession() async throws -> Bool {
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        return currentUser != nil && currentSession != nil
    }
    
    public func getSessionInfo() async throws -> SessionInfo {
        guard let session = currentSession else {
            throw AuthServiceError.sessionInvalid
        }
        
        return session
    }
    
    public func terminateAllSessions() async throws {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Remove all sessions for the user
        sessions = sessions.filter { $0.value.userId != user.id }
        currentSession = nil
        
        await recordSecurityEvent(userId: user.id, eventType: .logout, severity: .medium, details: ["action": "terminate_all_sessions"])
    }
    
    public func terminateSession(sessionId: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard let session = sessions[sessionId] else {
            throw AuthServiceError.sessionInvalid
        }
        
        sessions.removeValue(forKey: sessionId)
        
        if currentSession?.id == sessionId {
            currentSession = nil
        }
        
        await recordSecurityEvent(userId: session.userId, eventType: .logout, severity: .low, details: ["action": "terminate_session", "session_id": sessionId])
    }
    
    public func getActiveSessions() async throws -> [SessionInfo] {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        return sessions.values.filter { $0.userId == user.id }
    }
    
    // MARK: - Account Management
    public func deleteAccount(password: String) async throws {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        guard password == "password123" else {
            throw AuthServiceError.invalidCredentials
        }
        
        // Remove user data
        users.removeValue(forKey: user.id)
        securityEvents.removeValue(forKey: user.id)
        loginHistory.removeValue(forKey: user.id)
        deviceRegistrations.removeValue(forKey: user.id)
        
        // Clear current session
        _currentUser = nil
        currentSession = nil
        
        authStateSubject.send(.unauthenticated)
    }
    
    public func deactivateAccount(password: String) async throws {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        guard password == "password123" else {
            throw AuthServiceError.invalidCredentials
        }
        
        let updatedUser = AuthUser(
            id: user.id,
            email: user.email,
            isEmailVerified: user.isEmailVerified,
            phoneNumber: user.phoneNumber,
            isPhoneVerified: user.isPhoneVerified,
            displayName: user.displayName,
            photoURL: user.photoURL,
            createdAt: user.createdAt,
            lastSignInAt: user.lastSignInAt,
            metadata: user.metadata,
            providerData: user.providerData,
            customClaims: user.customClaims,
            accessLevel: user.accessLevel,
            roles: user.roles,
            isActive: false,
            isMFAEnabled: user.isMFAEnabled,
            isBiometricEnabled: user.isBiometricEnabled
        )
        users[user.id] = updatedUser
        
        await recordSecurityEvent(userId: user.id, eventType: .accountLocked, severity: .high, details: ["action": "deactivated"])
        
        // Sign out
        try await signOut()
    }
    
    public func reactivateAccount(email: String, password: String) async throws -> AuthUser {
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        guard let user = users.values.first(where: { $0.email == email && !$0.isActive }) else {
            throw AuthServiceError.userNotFound
        }
        
        guard password == "password123" else {
            throw AuthServiceError.invalidCredentials
        }
        
        let updatedUser = AuthUser(
            id: user.id,
            email: user.email,
            isEmailVerified: user.isEmailVerified,
            phoneNumber: user.phoneNumber,
            isPhoneVerified: user.isPhoneVerified,
            displayName: user.displayName,
            photoURL: user.photoURL,
            createdAt: user.createdAt,
            lastSignInAt: user.lastSignInAt,
            metadata: user.metadata,
            providerData: user.providerData,
            customClaims: user.customClaims,
            accessLevel: user.accessLevel,
            roles: user.roles,
            isActive: true,
            isMFAEnabled: user.isMFAEnabled,
            isBiometricEnabled: user.isBiometricEnabled
        )
        users[user.id] = updatedUser
        
        await recordSecurityEvent(userId: user.id, eventType: .login, severity: .medium, details: ["action": "reactivated"])
        
        return updatedUser
    }
    
    public func exportAccountData() async throws -> AccountExportData {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Create a mock UserProfile for export
        let mockProfile = UserProfile(
            email: user.email,
            firstName: user.displayName?.components(separatedBy: " ").first ?? "",
            lastName: user.displayName?.components(separatedBy: " ").last ?? "",
            accessLevel: user.accessLevel
        )
        
        return AccountExportData(
            userId: user.id,
            email: user.email,
            profile: mockProfile,
            authHistory: securityEvents[user.id] ?? [],
            loginHistory: loginHistory[user.id] ?? [],
            deviceRegistrations: deviceRegistrations[user.id] ?? []
        )
    }
    
    // MARK: - Access Control
    public func checkPermission(_ permission: Permission) async throws -> Bool {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Mock permission checking based on access level
        let requiredLevel = permission.requiredAccessLevel
        
        switch (user.accessLevel, requiredLevel) {
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
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        switch user.accessLevel {
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
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        guard let user = users[userId] else {
            throw AuthServiceError.userNotFound
        }
        
        // Update access level based on role
        let updatedUser = AuthUser(
            id: user.id,
            email: user.email,
            isEmailVerified: user.isEmailVerified,
            phoneNumber: user.phoneNumber,
            isPhoneVerified: user.isPhoneVerified,
            displayName: user.displayName,
            photoURL: user.photoURL,
            createdAt: user.createdAt,
            lastSignInAt: user.lastSignInAt,
            metadata: user.metadata,
            providerData: user.providerData,
            customClaims: user.customClaims,
            accessLevel: role.accessLevel,
            roles: user.roles,
            isActive: user.isActive,
            isMFAEnabled: user.isMFAEnabled,
            isBiometricEnabled: user.isBiometricEnabled
        )
        users[userId] = updatedUser
        
        if currentUser?.id == userId {
            _currentUser = updatedUser
            authStateSubject.send(.authenticated(updatedUser))
        }
        
        await recordSecurityEvent(userId: userId, eventType: .permissionChanged, severity: .medium, details: ["new_role": role.name])
    }
    
    // MARK: - Security Events
    public func getSecurityEvents(limit: Int) async throws -> [SecurityEvent] {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        let events = securityEvents[user.id] ?? []
        return Array(events.suffix(limit).reversed()) // Most recent first
    }
    
    public func reportSecurityIssue(_ issue: SecurityIssue) async throws {
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let userId = issue.userId ?? currentUser?.id ?? "anonymous"
        
        await recordSecurityEvent(
            userId: userId,
            eventType: .suspiciousLogin,
            severity: issue.severity,
            details: ["issue_type": issue.type.rawValue, "description": issue.description]
        )
        
        print("🚨 [MOCK] Security issue reported: \(issue.type.displayName)")
    }
    
    public func getLoginHistory(limit: Int) async throws -> [LoginEvent] {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        let history = loginHistory[user.id] ?? []
        return Array(history.suffix(limit).reversed()) // Most recent first
    }
    
    // MARK: - Device Management
    public func registerDevice(_ device: DeviceInfo) async throws -> DeviceRegistration {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let registration = DeviceRegistration(
            userId: user.id,
            deviceInfo: device,
            pushToken: "mock-push-token-\(device.deviceId)",
            isActive: true
        )
        
        var userDevices = deviceRegistrations[user.id] ?? []
        userDevices.append(registration)
        deviceRegistrations[user.id] = userDevices
        
        await recordSecurityEvent(userId: user.id, eventType: .deviceRegistered, severity: .low, details: ["device_name": device.name, "platform": device.platform])
        
        return registration
    }
    
    public func unregisterDevice(deviceId: String) async throws {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        var userDevices = deviceRegistrations[user.id] ?? []
        userDevices.removeAll { $0.deviceInfo.deviceId == deviceId }
        deviceRegistrations[user.id] = userDevices
        
        await recordSecurityEvent(userId: user.id, eventType: .deviceUnregistered, severity: .low, details: ["device_id": deviceId])
    }
    
    public func getRegisteredDevices() async throws -> [DeviceRegistration] {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        return deviceRegistrations[user.id] ?? []
    }
    
    public func updateDeviceInfo(_ device: DeviceInfo) async throws -> DeviceRegistration {
        guard let user = currentUser else {
            throw AuthServiceError.sessionInvalid
        }
        
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        var userDevices = deviceRegistrations[user.id] ?? []
        
        if let index = userDevices.firstIndex(where: { $0.deviceInfo.deviceId == device.deviceId }) {
            let registration = userDevices[index]
            let updatedRegistration = DeviceRegistration(
                id: registration.id,
                userId: registration.userId,
                deviceInfo: device,
                pushToken: registration.pushToken,
                isActive: registration.isActive,
                registeredAt: registration.registeredAt,
                lastSeenAt: Date()
            )
            userDevices[index] = updatedRegistration
            deviceRegistrations[user.id] = userDevices
            return updatedRegistration
        } else {
            // Device not found, register it
            return try await registerDevice(device)
        }
    }
    
    // MARK: - Mock Helper Methods
    public func setCurrentUser(_ user: AuthUser?) {
        _currentUser = user
        if let user = user {
            authStateSubject.send(.authenticated(user))
        } else {
            authStateSubject.send(.unauthenticated)
        }
    }
    
    public func clearAllData() {
        users.removeAll()
        sessions.removeAll()
        securityEvents.removeAll()
        loginHistory.removeAll()
        deviceRegistrations.removeAll()
        _currentUser = nil
        currentSession = nil
        authStateSubject.send(.unauthenticated)
    }
    
    // MARK: - Private Helper Methods
    private func createSession(for user: AuthUser) -> SessionInfo {
        let deviceInfo = DeviceInfo(
            deviceId: "mock-device-123",
            name: "iPhone 15 Pro",
            model: "iPhone16,1",
            platform: "iOS",
            osVersion: "17.0",
            appVersion: "1.0.0",
            isPushEnabled: true
        )
        
        let session = SessionInfo(
            id: UUID().uuidString,
            userId: user.id,
            deviceInfo: deviceInfo,
            ipAddress: "192.168.1.100",
            userAgent: "SAKungFuJournal/1.0 iOS/17.0",
            location: "San Francisco, CA",
            expiresAt: Date().addingTimeInterval(86400), // 24 hours
            isCurrent: true
        )
        
        sessions[session.id] = session
        return session
    }
    
    private func recordSecurityEvent(userId: String, eventType: SecurityEventType, severity: SecuritySeverity = .low, details: [String: String] = [:]) async {
        let event = SecurityEvent(
            userId: userId,
            eventType: eventType,
            ipAddress: "192.168.1.100",
            userAgent: "SAKungFuJournal/1.0 iOS/17.0",
            location: "San Francisco, CA",
            details: details,
            severity: severity
        )
        
        var userEvents = securityEvents[userId] ?? []
        userEvents.append(event)
        
        // Keep only last 100 events per user
        if userEvents.count > 100 {
            userEvents = Array(userEvents.suffix(100))
        }
        
        securityEvents[userId] = userEvents
    }
    
    private func recordLoginEvent(userId: String, success: Bool, failureReason: String? = nil) async {
        let deviceInfo = DeviceInfo(
            deviceId: "mock-device-123",
            name: "iPhone 15 Pro",
            model: "iPhone16,1",
            platform: "iOS",
            osVersion: "17.0",
            appVersion: "1.0.0"
        )
        
        let loginEvent = LoginEvent(
            userId: userId,
            ipAddress: "192.168.1.100",
            userAgent: "SAKungFuJournal/1.0 iOS/17.0",
            location: "San Francisco, CA",
            deviceInfo: deviceInfo,
            success: success,
            failureReason: failureReason
        )
        
        var userHistory = loginHistory[userId] ?? []
        userHistory.append(loginEvent)
        
        // Keep only last 50 login events per user
        if userHistory.count > 50 {
            userHistory = Array(userHistory.suffix(50))
        }
        
        loginHistory[userId] = userHistory
    }
    
    // MARK: - Sample Data
    private func seedSampleData() {
        let sampleUsers = [
            AuthUser(
                id: "user1",
                email: "instructor@sakungfu.com",
                isEmailVerified: true,
                displayName: "Instructor John",
                accessLevel: .instructor,
                isActive: true,
                isMFAEnabled: true,
                isBiometricEnabled: true
            ),
            AuthUser(
                id: "user2",
                email: "student@example.com",
                isEmailVerified: true,
                displayName: "Jane Doe",
                accessLevel: .subscriber,
                isActive: true,
                isMFAEnabled: false,
                isBiometricEnabled: true
            ),
            AuthUser(
                id: "user3",
                email: "beginner@example.com",
                isEmailVerified: false,
                displayName: "Mike Johnson",
                accessLevel: .free,
                isActive: true,
                isMFAEnabled: false,
                isBiometricEnabled: false
            )
        ]
        
        for user in sampleUsers {
            users[user.id] = user
            
            // Add sample security events
            securityEvents[user.id] = [
                SecurityEvent(userId: user.id, eventType: .login, severity: .low),
                SecurityEvent(userId: user.id, eventType: .logout, severity: .low)
            ]
            
            // Add sample login history
            let deviceInfo = DeviceInfo(
                deviceId: "device-\(user.id)",
                name: "iPhone",
                model: "iPhone15,1",
                platform: "iOS",
                osVersion: "17.0",
                appVersion: "1.0.0"
            )
            
            loginHistory[user.id] = [
                LoginEvent(userId: user.id, ipAddress: "192.168.1.100", userAgent: "App/1.0", deviceInfo: deviceInfo, success: true)
            ]
        }
        
        // Set first user as current for testing
        _currentUser = sampleUsers.first
        if let user = currentUser {
            currentSession = createSession(for: user)
            authStateSubject.send(.authenticated(user))
        }
    }
}