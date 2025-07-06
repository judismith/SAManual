import Foundation

// MARK: - Authentication Use Case Protocol
public protocol AuthenticationUseCaseProtocol {
    /// Sign in a user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: Authenticated user profile
    /// - Throws: AppError if authentication fails
    func signIn(email: String, password: String) async throws -> User
    
    /// Sign in a user with Apple ID
    /// - Parameter identityToken: Apple's identity token
    /// - Returns: Authenticated user profile
    /// - Throws: AppError if authentication fails
    func signInWithApple(identityToken: String) async throws -> User
    
    /// Sign in a user with Google
    /// - Parameter idToken: Google's ID token
    /// - Returns: Authenticated user profile
    /// - Throws: AppError if authentication fails
    func signInWithGoogle(idToken: String) async throws -> User
    
    /// Sign out the current user
    /// - Throws: AppError if sign out fails
    func signOut() async throws
    
    /// Get the current authentication state
    /// - Returns: Current authentication state
    func getCurrentAuthState() -> AuthState
    
    /// Check if user is currently authenticated
    /// - Returns: True if user is authenticated, false otherwise
    func isAuthenticated() -> Bool
    
    /// Get the current authenticated user
    /// - Returns: Current user if authenticated, nil otherwise
    /// - Throws: AppError if user retrieval fails
    func getCurrentUser() async throws -> User?
}

// MARK: - Authentication Use Case Implementation
public final class AuthenticationUseCase: AuthenticationUseCaseProtocol {
    
    // MARK: - Dependencies
    private let authRepository: AuthenticationRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    
    // MARK: - Initialization
    public init(
        authRepository: AuthenticationRepositoryProtocol,
        userRepository: UserRepositoryProtocol
    ) {
        self.authRepository = authRepository
        self.userRepository = userRepository
    }
    
    // MARK: - AuthenticationUseCaseProtocol Implementation
    
    public func signIn(email: String, password: String) async throws -> User {
        // Validate input
        guard !email.isEmpty else {
            throw AppError.invalidUserData(field: "email", message: "Email cannot be empty")
        }
        guard !password.isEmpty else {
            throw AppError.invalidUserData(field: "password", message: "Password cannot be empty")
        }
        
        // Validate email format
        guard isValidEmail(email) else {
            throw AppError.invalidUserData(field: "email", message: "Invalid email format")
        }
        
        do {
            // Authenticate with repository
            let authResult = try await authRepository.signIn(email: email, password: password)
            
            // Fetch or create user profile
            let user = try await getUserOrCreate(from: authResult)
            
            return user
        } catch {
            // Map repository errors to domain errors
            throw mapAuthenticationError(error)
        }
    }
    
    public func signInWithApple(identityToken: String) async throws -> User {
        guard !identityToken.isEmpty else {
            throw AppError.authenticationFailed(reason: "Invalid Apple identity token")
        }
        
        do {
            let authResult = try await authRepository.signInWithApple(identityToken: identityToken)
            let user = try await getUserOrCreate(from: authResult)
            return user
        } catch {
            throw mapAuthenticationError(error)
        }
    }
    
    public func signInWithGoogle(idToken: String) async throws -> User {
        guard !idToken.isEmpty else {
            throw AppError.authenticationFailed(reason: "Invalid Google ID token")
        }
        
        do {
            let authResult = try await authRepository.signInWithGoogle(idToken: idToken)
            let user = try await getUserOrCreate(from: authResult)
            return user
        } catch {
            throw mapAuthenticationError(error)
        }
    }
    
    public func signOut() async throws {
        do {
            try await authRepository.signOut()
        } catch {
            throw AppError.authenticationFailed(reason: "Failed to sign out: \(error.localizedDescription)")
        }
    }
    
    public func getCurrentAuthState() -> AuthState {
        return authRepository.getCurrentAuthState()
    }
    
    public func isAuthenticated() -> Bool {
        switch authRepository.getCurrentAuthState() {
        case .authenticated:
            return true
        case .unauthenticated, .authenticating, .error:
            return false
        }
    }
    
    public func getCurrentUser() async throws -> User? {
        guard isAuthenticated() else {
            return nil
        }
        
        do {
            return try await userRepository.getCurrentUser()
        } catch {
            throw AppError.userNotFound(id: "current")
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func getUserOrCreate(from authResult: AuthResult) async throws -> User {
        // Try to fetch existing user
        if let existingUser = try? await userRepository.getUser(id: authResult.userId) {
            return existingUser
        }
        
        // Create new user if doesn't exist
        let newUser = User(
            id: authResult.userId,
            email: authResult.email,
            name: authResult.displayName ?? "User",
            userType: .free,
            accessLevel: .freePublic,
            dataStore: .iCloud
        )
        
        return try await userRepository.createUser(newUser)
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func mapAuthenticationError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        // Map common authentication errors
        let errorMessage = error.localizedDescription.lowercased()
        
        if errorMessage.contains("invalid") && errorMessage.contains("credential") {
            return AppError.invalidCredentials
        } else if errorMessage.contains("network") || errorMessage.contains("connection") {
            return AppError.networkError(underlying: error)
        } else if errorMessage.contains("timeout") {
            return AppError.timeoutError(operation: "authentication")
        } else {
            return AppError.authenticationFailed(reason: error.localizedDescription)
        }
    }
}

// MARK: - Supporting Types

public enum AuthState {
    case authenticated
    case unauthenticated
    case authenticating
    case error(AppError)
}

public struct AuthResult {
    public let userId: String
    public let email: String
    public let displayName: String?
    public let provider: AuthProvider
    
    public init(userId: String, email: String, displayName: String? = nil, provider: AuthProvider) {
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.provider = provider
    }
}

public enum AuthProvider: String, CaseIterable {
    case email = "email"
    case apple = "apple"
    case google = "google"
    case anonymous = "anonymous"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Repository Protocols (to be implemented in Data layer)

public protocol AuthenticationRepositoryProtocol {
    func signIn(email: String, password: String) async throws -> AuthResult
    func signInWithApple(identityToken: String) async throws -> AuthResult
    func signInWithGoogle(idToken: String) async throws -> AuthResult
    func signOut() async throws
    func getCurrentAuthState() -> AuthState
}

 