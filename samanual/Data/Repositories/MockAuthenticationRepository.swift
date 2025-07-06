import Foundation

// MARK: - Mock Authentication Repository Implementation
public class MockAuthenticationRepository: AuthenticationRepositoryProtocol {
    
    // MARK: - In-Memory Storage
    private var currentAuthState: AuthState = .unauthenticated
    private var mockUsers: [String: AuthUser] = [:]
    
    // MARK: - Initialization
    public init() {
        seedSampleData()
    }
    
    // MARK: - AuthenticationRepositoryProtocol Implementation
    
    public func signIn(email: String, password: String) async throws -> AuthResult {
        // Simulate authentication delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Check if user exists in mock data
        if let user = mockUsers[email] {
            currentAuthState = .authenticated
            return AuthResult(
                userId: user.id,
                email: user.email,
                displayName: user.displayName,
                provider: .email
            )
        } else {
            throw AppError.invalidCredentials
        }
    }
    
    public func signInWithApple(identityToken: String) async throws -> AuthResult {
        // Simulate Apple Sign In
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        let mockUser = AuthUser(
            id: "apple_user_\(UUID().uuidString)",
            email: "user@icloud.com",
            displayName: "Apple User"
        )
        
        currentAuthState = .authenticated
        return AuthResult(
            userId: mockUser.id,
            email: mockUser.email,
            displayName: mockUser.displayName,
            provider: .apple
        )
    }
    
    public func signInWithGoogle(idToken: String) async throws -> AuthResult {
        // Simulate Google Sign In
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        let mockUser = AuthUser(
            id: "google_user_\(UUID().uuidString)",
            email: "user@gmail.com",
            displayName: "Google User"
        )
        
        currentAuthState = .authenticated
        return AuthResult(
            userId: mockUser.id,
            email: mockUser.email,
            displayName: mockUser.displayName,
            provider: .google
        )
    }
    
    public func signOut() async throws {
        // Simulate sign out delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        currentAuthState = .unauthenticated
    }
    
    public func getCurrentAuthState() -> AuthState {
        return currentAuthState
    }
    
    // MARK: - Private Helper Methods
    
    private func seedSampleData() {
        // Create sample users for testing
        mockUsers["john.doe@example.com"] = AuthUser(
            id: "user1",
            email: "john.doe@example.com",
            displayName: "John Doe"
        )
        
        mockUsers["jane.smith@example.com"] = AuthUser(
            id: "user2",
            email: "jane.smith@example.com",
            displayName: "Jane Smith"
        )
        
        mockUsers["admin@shaolinarts.com"] = AuthUser(
            id: "user3",
            email: "admin@shaolinarts.com",
            displayName: "Admin User"
        )
    }
} 