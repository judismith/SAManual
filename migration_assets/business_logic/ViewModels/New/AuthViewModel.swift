import Foundation
import Combine
import FirebaseAuth
import Security

@MainActor
class AuthViewModel: BaseViewModel<AuthViewState> {
    
    // MARK: - Dependencies
    private let userService: UserService
    private let subscriptionService: SubscriptionService
    private let programService: ProgramService
    
    // Biometric service (will be injected in future)
    let biometricService = BiometricAuthService.shared
    
    // MARK: - Published Properties
    @Published var showBiometricPrompt: Bool = false
    @Published var pendingCredentials: (email: String, password: String)?
    
    // MARK: - Private Properties
    private var hasAttemptedAutoBiometric = false
    private var isSigningOut = false
    
    // MARK: - Initialization
    init(
        authService: AuthService,
        userService: UserService,
        subscriptionService: SubscriptionService,
        programService: ProgramService,
        errorHandler: ErrorHandler
    ) {
        self.userService = userService
        self.subscriptionService = subscriptionService
        self.programService = programService
        
        super.init(
            initialState: AuthViewState(),
            errorHandler: errorHandler
        )
        
        setupAuthObserver()
    }
    
    // MARK: - Private Methods
    private func setupAuthObserver() {
        // For now, continue using the legacy Firebase auth state during transition
        legacyAuthService.$user
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.handleAuthStateChange(user: user)
            }
            .store(in: &cancellables)
    }
    
    private func handleAuthStateChange(user: User?) {
        state.user = user
        
        // Add a small delay to ensure Firebase is properly initialized
        Task {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            if !state.isInitialized {
                state.isInitialized = true
            }
        }
    }
    
    // MARK: - Public Methods
    func signIn(email: String, password: String) {
        state.isLoading = true
        state.errorMessage = nil
        
        // For now, use legacy auth service during transition
        legacyAuthService.signIn(email: email, password: password) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.state.isLoading = false
                switch result {
                case .success(let user):
                    self.state.user = user
                    self.state.errorMessage = nil
                    
                    // Only prompt for biometric consent if credentials aren't already saved
                    if !self.biometricService.hasStoredCredentials {
                        self.promptForBiometricConsent(email: email, password: password)
                    }
                    
                    // Create profile for email user using new services
                    await self.createProfileForUser(user: user)
                    
                case .failure(let error):
                    self.state.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func signUp(email: String, password: String) {
        state.isLoading = true
        state.errorMessage = nil
        
        legacyAuthService.signUp(email: email, password: password) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.state.isLoading = false
                switch result {
                case .success(let user):
                    self.state.user = user
                    self.state.errorMessage = nil
                    
                    // Create profile for email user using new services
                    await self.createProfileForUser(user: user)
                    
                case .failure(let error):
                    self.state.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func createAccountWithProfile(email: String, password: String, name: String) {
        state.isLoading = true
        state.errorMessage = nil
        
        legacyAuthService.signUp(email: email, password: password) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.state.isLoading = false
                switch result {
                case .success(let user):
                    self.state.user = user
                    self.state.errorMessage = nil
                    
                    // Create profile during signup using new services
                    await self.createProfileDuringSignup(user: user, email: email, name: name)
                    
                case .failure(let error):
                    self.state.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func signOut() {
        isSigningOut = true
        
        do {
            try legacyAuthService.signOut()
            state.user = nil
            state.errorMessage = nil
        } catch {
            state.errorMessage = error.localizedDescription
        }
        
        // Re-enable biometric authentication after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isSigningOut = false
        }
    }
    
    func resetPassword(email: String) {
        state.isLoading = true
        
        legacyAuthService.resetPassword(email: email) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.state.isLoading = false
                switch result {
                case .success:
                    self.state.errorMessage = nil
                    self.showSuccessMessage("Password reset email sent to \(email)")
                case .failure(let error):
                    self.state.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func signInWithApple() {
        state.isLoading = true
        state.errorMessage = nil
        
        legacyAuthService.signInWithApple { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.state.isLoading = false
                switch result {
                case .success(let user):
                    self.state.user = user
                    self.state.errorMessage = nil
                    
                    // Create profile for OAuth user using new services
                    await self.createProfileForUser(user: user)
                    
                case .failure(let error):
                    self.state.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func signInWithGoogle() {
        state.isLoading = true
        state.errorMessage = nil
        
        legacyAuthService.signInWithGoogle { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.state.isLoading = false
                switch result {
                case .success(let user):
                    self.state.user = user
                    self.state.errorMessage = nil
                    
                    // Create profile for OAuth user using new services
                    await self.createProfileForUser(user: user)
                    
                case .failure(let error):
                    self.state.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func signInWithBiometrics() {
        // Prevent biometric authentication during sign-out
        if isSigningOut {
            return
        }
        
        guard biometricService.isBiometricAvailable else {
            state.errorMessage = "Biometric authentication not available"
            return
        }
        
        guard biometricService.hasStoredCredentials else {
            state.errorMessage = "No saved credentials found. Please sign in with email and password first."
            return
        }
        
        state.isLoading = true
        
        biometricService.authenticateWithBiometrics { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.state.isLoading = false
                switch result {
                case .success:
                    self.signInWithStoredCredentials()
                case .failure(let error):
                    self.state.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func saveBiometricCredentialsWithConsent() {
        guard let credentials = pendingCredentials else {
            return
        }
        
        if biometricService.saveCredentials(email: credentials.email, password: credentials.password) {
            showSuccessMessage("Face ID/Touch ID enabled for future sign-ins")
        } else {
            state.errorMessage = "Failed to save biometric credentials"
        }
        
        // Clear pending credentials and hide prompt
        pendingCredentials = nil
        showBiometricPrompt = false
    }
    
    func declineBiometricCredentials() {
        pendingCredentials = nil
        showBiometricPrompt = false
    }
    
    func clearBiometricCredentials() {
        biometricService.clearCredentials()
    }
    
    func removeBiometricAccess() {
        clearBiometricCredentials()
        showSuccessMessage("Face ID/Touch ID access removed")
    }
    
    func saveBiometricCredentialsManually(email: String, password: String) {
        if biometricService.saveCredentials(email: email, password: password) {
            showSuccessMessage("Biometric credentials saved successfully!")
        } else {
            state.errorMessage = "Failed to save biometric credentials"
        }
    }
    
    // MARK: - Private Helper Methods
    private func signInWithStoredCredentials() {
        guard let credentials = biometricService.retrieveCredentials() else {
            state.errorMessage = "Failed to retrieve stored credentials"
            return
        }
        
        // Use the stored credentials to sign in
        signIn(email: credentials.email, password: credentials.password)
    }
    
    private func promptForBiometricConsent(email: String, password: String) {
        // Store pending credentials and show consent prompt
        pendingCredentials = (email: email, password: password)
        showBiometricPrompt = true
    }
    
    private func showSuccessMessage(_ message: String) {
        // For now, we'll use the error message field to show success
        state.errorMessage = message
        // Clear the success message after 3 seconds
        Task {
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            if state.errorMessage == message {
                state.errorMessage = nil
            }
        }
    }
    
    private func createProfileForUser(user: User) async {
        let email = user.email ?? ""
        let name = user.displayName ?? "New User"
        
        // Check if there's an existing member with this email
        do {
            if let existingProfile = try await checkExistingMemberByEmail(email: email) {
                // Create a user-specific profile based on the existing member data
                await createUserProfileFromMemberData(memberProfile: existingProfile, firebaseUser: user)
            } else {
                // Create new user profile using new services
                await createNewUserProfile(email: email, name: name, firebaseUser: user)
            }
        } catch {
            // Fallback: create new user profile
            await createNewUserProfile(email: email, name: name, firebaseUser: user)
        }
    }
    
    private func createProfileDuringSignup(user: User, email: String, name: String) async {
        // Check if there's an existing member with this email
        do {
            if let existingProfile = try await checkExistingMemberByEmail(email: email) {
                // Create user profile based on existing member data
                await createUserProfileFromMemberData(memberProfile: existingProfile, firebaseUser: user)
            } else {
                // Create new public user profile using new services
                await createNewPublicUserProfile(email: email, name: name, firebaseUser: user)
            }
        } catch {
            // Fallback: create new public user profile
            await createNewPublicUserProfile(email: email, name: name, firebaseUser: user)
        }
    }
    
    private func checkExistingMemberByEmail(email: String) async throws -> UserProfile? {
        // Use legacy service for now during transition
        return try await withCheckedThrowingContinuation { continuation in
            legacyFirestoreService.checkExistingMember(email: email) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    private func createUserProfileFromMemberData(memberProfile: UserProfile, firebaseUser: User) async {
        // Determine user type based on roles and programs
        let userType = determineUserType(from: memberProfile)
        
        // Create a user-specific profile based on the member data
        let userProfile = UserProfile(
            uid: firebaseUser.uid,
            firebaseUid: firebaseUser.uid,
            name: memberProfile.name,
            email: memberProfile.email,
            roles: memberProfile.roles,
            profilePhotoUrl: memberProfile.profilePhotoUrl,
            programs: memberProfile.programs,
            subscription: memberProfile.subscription,
            studioMembership: memberProfile.studioMembership,
            dataStore: .iCloud,
            accessLevel: .userPrivate,
            userType: userType
        )
        
        // Save using new service
        do {
            let savedProfile = try await userService.updateUser(userProfile)
            // Profile is now saved via the service
        } catch {
            await handleError(error)
        }
    }
    
    private func createNewUserProfile(email: String, name: String, firebaseUser: User) async {
        // Create a new user profile
        let userProfile = UserProfile(
            uid: firebaseUser.uid,
            firebaseUid: firebaseUser.uid,
            name: name,
            email: email,
            roles: ["public"],
            profilePhotoUrl: "",
            programs: [:],
            subscription: nil,
            studioMembership: nil,
            dataStore: .iCloud,
            accessLevel: .userPrivate
        )
        
        // Save using new service
        do {
            let savedProfile = try await userService.updateUser(userProfile)
            // Profile is now saved via the service
        } catch {
            await handleError(error)
        }
    }
    
    private func createNewPublicUserProfile(email: String, name: String, firebaseUser: User) async {
        // Create a new public user profile
        let userProfile = UserProfile(
            uid: firebaseUser.uid,
            firebaseUid: firebaseUser.uid,
            name: name,
            email: email,
            roles: ["public"],
            profilePhotoUrl: "",
            programs: [:],
            subscription: nil,
            studioMembership: nil,
            dataStore: .iCloud,
            accessLevel: .userPrivate
        )
        
        // Save using new service
        do {
            let savedProfile = try await userService.updateUser(userProfile)
            // Profile is now saved via the service
        } catch {
            await handleError(error)
        }
    }
    
    private func determineUserType(from memberProfile: UserProfile) -> UserType {
        // Check roles first
        if memberProfile.roles.contains("student") {
            return .student
        } else if memberProfile.roles.contains("parent") {
            return .parent
        } else if memberProfile.roles.contains("instructor") {
            return .instructor
        } else if memberProfile.roles.contains("admin") {
            return .admin
        }
        
        // Check programs and subscription as fallback
        if memberProfile.hasEnrolledPrograms() {
            return .student
        } else if memberProfile.subscription?.isActive == true {
            return .paidUser
        }
        
        // Default to free user
        return .freeUser
    }
}

// MARK: - Auth State
struct AuthViewState {
    var user: User?  // Firebase User for compatibility during transition
    var errorMessage: String?
    var isLoading: Bool = false
    var isInitialized: Bool = false
}