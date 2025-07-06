import Foundation

// MARK: - User Repository Protocol
public protocol UserRepositoryProtocol {
    /// Get current authenticated user
    /// - Returns: Current user if authenticated, nil otherwise
    /// - Throws: AppError if retrieval fails
    func getCurrentUser() async throws -> User?
    
    /// Get user by ID
    /// - Parameter id: User ID
    /// - Returns: User profile
    /// - Throws: AppError if user not found
    func getUser(id: String) async throws -> User
    
    /// Get user by email
    /// - Parameter email: User's email address
    /// - Returns: User profile if found, nil otherwise
    /// - Throws: AppError if retrieval fails
    func getUserByEmail(email: String) async throws -> User?
    
    /// Create new user
    /// - Parameter user: User profile to create
    /// - Returns: Created user profile
    /// - Throws: AppError if creation fails
    func createUser(_ user: User) async throws -> User
    
    /// Update existing user
    /// - Parameter user: Updated user profile
    /// - Returns: Updated user profile
    /// - Throws: AppError if update fails
    func updateUser(_ user: User) async throws -> User
    
    /// Delete user
    /// - Parameter id: User ID to delete
    /// - Throws: AppError if deletion fails
    func deleteUser(id: String) async throws
    
    /// Search users by criteria
    /// - Parameter criteria: Search criteria
    /// - Returns: Array of matching users
    /// - Throws: AppError if search fails
    func searchUsers(criteria: UserSearchCriteria) async throws -> [User]
    
    /// Get users by program enrollment
    /// - Parameter programId: Program ID
    /// - Returns: Array of enrolled users
    /// - Throws: AppError if retrieval fails
    func getUsersByProgram(programId: String) async throws -> [User]
    
    /// Check if user exists
    /// - Parameter id: User ID to check
    /// - Returns: True if user exists, false otherwise
    func userExists(id: String) async throws -> Bool
    
    /// Check if email is already registered
    /// - Parameter email: Email to check
    /// - Returns: True if email is registered, false otherwise
    func emailExists(email: String) async throws -> Bool
}

// MARK: - User Search Criteria
public struct UserSearchCriteria {
    public let name: String?
    public let email: String?
    public let userType: UserType?
    public let programId: String?
    public let isActive: Bool?
    public let limit: Int?
    public let offset: Int?
    
    public init(
        name: String? = nil,
        email: String? = nil,
        userType: UserType? = nil,
        programId: String? = nil,
        isActive: Bool? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) {
        self.name = name
        self.email = email
        self.userType = userType
        self.programId = programId
        self.isActive = isActive
        self.limit = limit
        self.offset = offset
    }
}

// MARK: - User Repository Implementation (Abstract Base)
public class BaseUserRepository: UserRepositoryProtocol {
    
    public init() {}
    
    // MARK: - UserRepositoryProtocol Implementation
    
    public func getCurrentUser() async throws -> User? {
        fatalError("getCurrentUser() must be implemented by subclass")
    }
    
    public func getUser(id: String) async throws -> User {
        fatalError("getUser(id:) must be implemented by subclass")
    }
    
    public func getUserByEmail(email: String) async throws -> User? {
        fatalError("getUserByEmail(email:) must be implemented by subclass")
    }
    
    public func createUser(_ user: User) async throws -> User {
        fatalError("createUser(_:) must be implemented by subclass")
    }
    
    public func updateUser(_ user: User) async throws -> User {
        fatalError("updateUser(_:) must be implemented by subclass")
    }
    
    public func deleteUser(id: String) async throws {
        fatalError("deleteUser(id:) must be implemented by subclass")
    }
    
    public func searchUsers(criteria: UserSearchCriteria) async throws -> [User] {
        fatalError("searchUsers(criteria:) must be implemented by subclass")
    }
    
    public func getUsersByProgram(programId: String) async throws -> [User] {
        fatalError("getUsersByProgram(programId:) must be implemented by subclass")
    }
    
    public func userExists(id: String) async throws -> Bool {
        do {
            _ = try await getUser(id: id)
            return true
        } catch {
            return false
        }
    }
    
    public func emailExists(email: String) async throws -> Bool {
        return try await getUserByEmail(email: email) != nil
    }
}

// MARK: - User Repository Factory
public protocol UserRepositoryFactoryProtocol {
    func createUserRepository() -> UserRepositoryProtocol
}

public class UserRepositoryFactory: UserRepositoryFactoryProtocol {
    private let container: DIContainer
    
    public init(container: DIContainer) {
        self.container = container
    }
    
    public func createUserRepository() -> UserRepositoryProtocol {
        // This will be implemented to return the appropriate repository
        // based on configuration (CloudKit, Firestore, etc.)
        fatalError("createUserRepository() must be implemented")
    }
} 