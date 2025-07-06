import Foundation

// MARK: - Authentication Repository Implementation
public class AuthenticationRepository: AuthenticationRepositoryProtocol {
    
    // MARK: - Dependencies
    private let authService: AuthService
    private let userRepository: UserRepositoryProtocol
    
    // MARK: - Initialization
    public init(authService: AuthService, userRepository: UserRepositoryProtocol) {
        self.authService = authService
        self.userRepository = userRepository
    }
    
    // MARK: - AuthenticationRepositoryProtocol Implementation
    
    public func signIn(email: String, password: String) async throws -> AuthResult {
        do {
            let authUser = try await authService.signIn(email: email, password: password)
            return AuthResult(
                userId: authUser.id,
                email: authUser.email,
                displayName: authUser.displayName,
                provider: .email
            )
        } catch {
            throw mapAuthServiceError(error)
        }
    }
    
    public func signInWithApple(identityToken: String) async throws -> AuthResult {
        do {
            let authUser = try await authService.signInWithApple()
            return AuthResult(
                userId: authUser.id,
                email: authUser.email,
                displayName: authUser.displayName,
                provider: .apple
            )
        } catch {
            throw mapAuthServiceError(error)
        }
    }
    
    public func signInWithGoogle(idToken: String) async throws -> AuthResult {
        do {
            let authUser = try await authService.signInWithGoogle()
            return AuthResult(
                userId: authUser.id,
                email: authUser.email,
                displayName: authUser.displayName,
                provider: .google
            )
        } catch {
            throw mapAuthServiceError(error)
        }
    }
    
    public func signOut() async throws {
        do {
            try await authService.signOut()
        } catch {
            throw mapAuthServiceError(error)
        }
    }
    
    public func getCurrentAuthState() -> AuthState {
        if authService.isAuthenticated {
            return .authenticated
        } else {
            return .unauthenticated
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func mapAuthServiceError(_ error: Error) -> AppError {
        // Map AuthService errors to domain AppError
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
        } else if errorMessage.contains("user not found") {
            return AppError.userNotFound(id: "unknown")
        } else if errorMessage.contains("email already in use") {
            return AppError.userAlreadyExists(email: "unknown")
        } else {
            return AppError.authenticationFailed(reason: error.localizedDescription)
        }
    }
}

// MARK: - Mock Authentication Repository (for testing)
// Moved to separate file: MockAuthenticationRepository.swift 