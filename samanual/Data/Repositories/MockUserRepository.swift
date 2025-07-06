import Foundation

// MARK: - Mock User Repository Implementation
public class MockUserRepository: BaseUserRepository {
    
    // MARK: - In-Memory Storage
    private var users: [String: User] = [:]
    private var currentUserId: String?
    
    // MARK: - Initialization
    public override init() {
        super.init()
        seedSampleData()
    }
    
    // MARK: - UserRepositoryProtocol Implementation
    
    public override func getCurrentUser() async throws -> User? {
        guard let currentUserId = currentUserId else {
            return nil
        }
        return users[currentUserId]
    }
    
    public override func getUser(id: String) async throws -> User {
        guard let user = users[id] else {
            throw AppError.userNotFound(id: id)
        }
        return user
    }
    
    public override func getUserByEmail(email: String) async throws -> User? {
        return users.values.first { $0.email == email }
    }
    
    public override func createUser(_ user: User) async throws -> User {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Check if user already exists
        if users[user.id] != nil {
            throw AppError.userAlreadyExists(email: user.email)
        }
        
        // Create new user with updated timestamps
        let newUser = User(
            id: user.id,
            email: user.email,
            name: user.name,
            userType: user.userType,
            membershipType: user.membershipType,
            enrolledPrograms: user.enrolledPrograms,
            accessLevel: user.accessLevel,
            dataStore: user.dataStore,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        users[user.id] = newUser
        return newUser
    }
    
    public override func updateUser(_ user: User) async throws -> User {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard users[user.id] != nil else {
            throw AppError.userNotFound(id: user.id)
        }
        
        // Update user with new timestamp
        let updatedUser = User(
            id: user.id,
            email: user.email,
            name: user.name,
            userType: user.userType,
            membershipType: user.membershipType,
            enrolledPrograms: user.enrolledPrograms,
            accessLevel: user.accessLevel,
            dataStore: user.dataStore,
            createdAt: user.createdAt,
            updatedAt: Date()
        )
        
        users[user.id] = updatedUser
        return updatedUser
    }
    
    public override func deleteUser(id: String) async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        guard users[id] != nil else {
            throw AppError.userNotFound(id: id)
        }
        
        users.removeValue(forKey: id)
        
        // If this was the current user, clear current user
        if currentUserId == id {
            currentUserId = nil
        }
    }
    
    public override func searchUsers(criteria: UserSearchCriteria) async throws -> [User] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        var filteredUsers = Array(users.values)
        
        // Apply filters
        if let name = criteria.name {
            filteredUsers = filteredUsers.filter { $0.name.localizedCaseInsensitiveContains(name) }
        }
        
        if let email = criteria.email {
            filteredUsers = filteredUsers.filter { $0.email.localizedCaseInsensitiveContains(email) }
        }
        
        if let userType = criteria.userType {
            filteredUsers = filteredUsers.filter { $0.userType == userType }
        }
        
        // Note: User entity doesn't have isActive property, so we skip this filter
        // if let isActive = criteria.isActive {
        //     filteredUsers = filteredUsers.filter { $0.isActive == isActive }
        // }
        
        // Apply limit and offset
        var result = filteredUsers
        
        if let offset = criteria.offset, offset < result.count {
            result = Array(result.dropFirst(offset))
        }
        
        if let limit = criteria.limit, limit < result.count {
            result = Array(result.prefix(limit))
        }
        
        return result
    }
    
    public override func getUsersByProgram(programId: String) async throws -> [User] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        return users.values.filter { user in
            user.enrolledPrograms.contains { enrollment in
                enrollment.programId == programId && enrollment.enrolled
            }
        }
    }
    
    // MARK: - Mock-Specific Methods
    
    /// Set the current authenticated user for testing
    public func setCurrentUser(_ userId: String?) {
        currentUserId = userId
    }
    
    /// Get all users in the mock repository
    public func getAllUsers() -> [User] {
        return Array(users.values)
    }
    
    /// Clear all users from the mock repository
    public func clearAllUsers() {
        users.removeAll()
        currentUserId = nil
    }
    
    /// Add a user directly to the mock repository
    public func addUser(_ user: User) {
        users[user.id] = user
    }
    
    // MARK: - Private Helper Methods
    
    private func seedSampleData() {
        let sampleUsers = [
            User(
                id: "user1",
                email: "john.doe@example.com",
                name: "John Doe",
                userType: .student,
                membershipType: .student,
                enrolledPrograms: [
                    ProgramEnrollment(
                        programId: "kungfu_basic",
                        programName: "Kung Fu Basic",
                        enrolled: true,
                        enrollmentDate: Date().addingTimeInterval(-86400 * 30), // 30 days ago
                        currentRank: "White Belt"
                    )
                ],
                accessLevel: .userPrivate,
                dataStore: .iCloud,
                createdAt: Date().addingTimeInterval(-86400 * 60), // 60 days ago
                updatedAt: Date().addingTimeInterval(-86400 * 7) // 7 days ago
            ),
            User(
                id: "user2",
                email: "jane.smith@example.com",
                name: "Jane Smith",
                userType: .instructor,
                membershipType: .instructor,
                enrolledPrograms: [
                    ProgramEnrollment(
                        programId: "kungfu_advanced",
                        programName: "Kung Fu Advanced",
                        enrolled: true,
                        enrollmentDate: Date().addingTimeInterval(-86400 * 365), // 1 year ago
                        currentRank: "Black Belt"
                    )
                ],
                accessLevel: .instructorPrivate,
                dataStore: .iCloud,
                createdAt: Date().addingTimeInterval(-86400 * 730), // 2 years ago
                updatedAt: Date().addingTimeInterval(-86400 * 1) // 1 day ago
            ),
            User(
                id: "user3",
                email: "admin@shaolinarts.com",
                name: "Admin User",
                userType: .admin,
                membershipType: .assistant,
                enrolledPrograms: [],
                accessLevel: .adminPrivate,
                dataStore: .iCloud,
                createdAt: Date().addingTimeInterval(-86400 * 1095), // 3 years ago
                updatedAt: Date()
            )
        ]
        
        for user in sampleUsers {
            users[user.id] = user
        }
        
        // Set the first user as current user for testing
        currentUserId = "user1"
    }
} 