import Foundation
import Combine

// MARK: - Mock User Service Implementation
public final class MockUserService: UserService {
    
    // MARK: - In-Memory Storage
    private var users: [String: UserProfile] = [:]
    private var userPreferences: [String: UserPreferences] = [:]
    private var userActivities: [String: [UserActivity]] = [:]
    private var currentUser: UserProfile?
    
    // MARK: - Publishers
    private let currentUserSubject = CurrentValueSubject<UserProfile?, Never>(nil)
    private let userUpdatesSubject = PassthroughSubject<UserProfile, Never>()
    
    public var currentUserPublisher: AnyPublisher<UserProfile?, Never> {
        currentUserSubject.eraseToAnyPublisher()
    }
    
    public var userUpdatesPublisher: AnyPublisher<UserProfile, Never> {
        userUpdatesSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    public init() {
        // Seed with sample data for development/testing
        seedSampleData()
    }
    
    // MARK: - User Profile Management
    public func createUser(_ userProfile: UserProfile) async throws -> UserProfile {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Check for duplicate email
        if users.values.contains(where: { $0.email == userProfile.email }) {
            throw UserServiceError.duplicateUser(email: userProfile.email)
        }
        
        var newUser = userProfile
        newUser.updatedAt = Date()
        
        users[newUser.id] = newUser
        userUpdatesSubject.send(newUser)
        
        return newUser
    }
    
    public func getUserProfile(id: String) async throws -> UserProfile? {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        return users[id]
    }
    
    public func updateUserProfile(_ userProfile: UserProfile) async throws -> UserProfile {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard users[userProfile.id] != nil else {
            throw UserServiceError.userNotFound(id: userProfile.id)
        }
        
        var updatedUser = userProfile
        updatedUser.updatedAt = Date()
        
        users[userProfile.id] = updatedUser
        userUpdatesSubject.send(updatedUser)
        
        // Update current user if it's the same
        if currentUser?.id == userProfile.id {
            currentUser = updatedUser
            currentUserSubject.send(updatedUser)
        }
        
        return updatedUser
    }
    
    public func deleteUser(id: String) async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard users[id] != nil else {
            throw UserServiceError.userNotFound(id: id)
        }
        
        users.removeValue(forKey: id)
        userPreferences.removeValue(forKey: id)
        userActivities.removeValue(forKey: id)
        
        // Clear current user if it was deleted
        if currentUser?.id == id {
            currentUser = nil
            currentUserSubject.send(nil)
        }
    }
    
    // MARK: - Current User Management
    public func getCurrentUser() async throws -> UserProfile? {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        return currentUser
    }
    
    public func updateCurrentUser(_ userProfile: UserProfile) async throws -> UserProfile {
        let updatedUser = try await updateUserProfile(userProfile)
        currentUser = updatedUser
        currentUserSubject.send(updatedUser)
        return updatedUser
    }
    
    public func signOut() async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        currentUser = nil
        currentUserSubject.send(nil)
    }
    
    // MARK: - User Search and Discovery
    public func searchUsers(query: String, limit: Int) async throws -> [UserProfile] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        let lowercaseQuery = query.lowercased()
        let filteredUsers = users.values.filter { user in
            user.displayName.lowercased().contains(lowercaseQuery) ||
            user.email.lowercased().contains(lowercaseQuery) ||
            user.firstName.lowercased().contains(lowercaseQuery) ||
            user.lastName.lowercased().contains(lowercaseQuery)
        }
        
        return Array(filteredUsers.prefix(limit))
    }
    
    public func getUsersByAccessLevel(_ accessLevel: AccessLevel) async throws -> [UserProfile] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        return users.values.filter { $0.accessLevel == accessLevel }
    }
    
    public func getUsersByProgram(programId: String) async throws -> [UserProfile] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        return users.values.filter { $0.programs[programId]?.enrolled == true }
    }
    
    // MARK: - User Enrollment Management
    public func enrollUserInProgram(userId: String, programId: String, startingRank: String) async throws -> UserProfile {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        guard var user = users[userId] else {
            throw UserServiceError.userNotFound(id: userId)
        }
        
        // Check if already enrolled
        if user.programs[programId]?.enrolled == true {
            throw UserServiceError.enrollmentFailed(userId: userId, programId: programId)
        }
        
        let enrollment = Enrollment(
            userId: userId,
            programId: programId,
            enrolled: true,
            enrollmentDate: Date(),
            currentRank: startingRank,
            rankDate: Date(),
            isActive: true
        )
        
        var updatedPrograms = user.programs
        updatedPrograms[programId] = enrollment
        
        user = UserProfile(
            id: user.id,
            email: user.email,
            firstName: user.firstName,
            lastName: user.lastName,
            displayName: user.displayName,
            profileImageURL: user.profileImageURL,
            accessLevel: user.accessLevel,
            isActive: user.isActive,
            programs: updatedPrograms
        )
        
        users[userId] = user
        userUpdatesSubject.send(user)
        
        // Update current user if it's the same
        if currentUser?.id == userId {
            currentUser = user
            currentUserSubject.send(user)
        }
        
        return user
    }
    
    public func unenrollUserFromProgram(userId: String, programId: String) async throws -> UserProfile {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        guard var user = users[userId] else {
            throw UserServiceError.userNotFound(id: userId)
        }
        
        guard user.programs[programId] != nil else {
            throw UserServiceError.unenrollmentFailed(userId: userId, programId: programId)
        }
        
        var updatedPrograms = user.programs
        updatedPrograms.removeValue(forKey: programId)
        
        user = UserProfile(
            id: user.id,
            email: user.email,
            firstName: user.firstName,
            lastName: user.lastName,
            displayName: user.displayName,
            profileImageURL: user.profileImageURL,
            accessLevel: user.accessLevel,
            isActive: user.isActive,
            programs: updatedPrograms
        )
        
        users[userId] = user
        userUpdatesSubject.send(user)
        
        // Update current user if it's the same
        if currentUser?.id == userId {
            currentUser = user
            currentUserSubject.send(user)
        }
        
        return user
    }
    
    public func updateUserRank(userId: String, programId: String, newRank: String) async throws -> UserProfile {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        guard var user = users[userId] else {
            throw UserServiceError.userNotFound(id: userId)
        }
        
        guard var enrollment = user.programs[programId] else {
            throw UserServiceError.enrollmentFailed(userId: userId, programId: programId)
        }
        
        enrollment = Enrollment(
            id: enrollment.id,
            userId: enrollment.userId,
            programId: enrollment.programId,
            enrolled: enrollment.enrolled,
            enrollmentDate: enrollment.enrollmentDate,
            currentRank: newRank,
            rankDate: Date(),
            isActive: enrollment.isActive
        )
        
        var updatedPrograms = user.programs
        updatedPrograms[programId] = enrollment
        
        user = UserProfile(
            id: user.id,
            email: user.email,
            firstName: user.firstName,
            lastName: user.lastName,
            displayName: user.displayName,
            profileImageURL: user.profileImageURL,
            accessLevel: user.accessLevel,
            isActive: user.isActive,
            programs: updatedPrograms
        )
        
        users[userId] = user
        userUpdatesSubject.send(user)
        
        // Update current user if it's the same
        if currentUser?.id == userId {
            currentUser = user
            currentUserSubject.send(user)
        }
        
        return user
    }
    
    // MARK: - User Preferences
    public func getUserPreferences(userId: String) async throws -> UserPreferences? {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        return userPreferences[userId]
    }
    
    public func updateUserPreferences(userId: String, preferences: UserPreferences) async throws -> UserPreferences {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard users[userId] != nil else {
            throw UserServiceError.userNotFound(id: userId)
        }
        
        var updatedPreferences = preferences
        updatedPreferences.updatedAt = Date()
        
        userPreferences[userId] = updatedPreferences
        return updatedPreferences
    }
    
    // MARK: - User Activity Tracking
    public func recordUserActivity(userId: String, activity: UserActivity) async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        guard users[userId] != nil else {
            throw UserServiceError.userNotFound(id: userId)
        }
        
        var activities = userActivities[userId] ?? []
        activities.append(activity)
        
        // Keep only last 100 activities per user
        if activities.count > 100 {
            activities = Array(activities.suffix(100))
        }
        
        userActivities[userId] = activities
    }
    
    public func getUserActivityHistory(userId: String, limit: Int) async throws -> [UserActivity] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        guard users[userId] != nil else {
            throw UserServiceError.userNotFound(id: userId)
        }
        
        let activities = userActivities[userId] ?? []
        return Array(activities.suffix(limit).reversed()) // Most recent first
    }
    
    // MARK: - Mock Helper Methods
    public func setCurrentUser(_ user: UserProfile?) {
        currentUser = user
        currentUserSubject.send(user)
    }
    
    public func clearAllData() {
        users.removeAll()
        userPreferences.removeAll()
        userActivities.removeAll()
        currentUser = nil
        currentUserSubject.send(nil)
    }
    
    // MARK: - Sample Data
    private func seedSampleData() {
        let sampleUsers = [
            UserProfile(
                id: "user1",
                email: "instructor@sakungfu.com",
                firstName: "John",
                lastName: "Smith",
                displayName: "Instructor John",
                accessLevel: .instructor,
                programs: [
                    "kungfu-program": Enrollment(
                        userId: "user1",
                        programId: "kungfu-program",
                        currentRank: "black1",
                        rankDate: Date()
                    )
                ]
            ),
            UserProfile(
                id: "user2",
                email: "student@example.com",
                firstName: "Jane",
                lastName: "Doe",
                displayName: "Jane Doe",
                accessLevel: .subscriber,
                programs: [
                    "kungfu-program": Enrollment(
                        userId: "user2",
                        programId: "kungfu-program",
                        currentRank: "blue2",
                        rankDate: Date()
                    )
                ]
            ),
            UserProfile(
                id: "user3",
                email: "beginner@example.com",
                firstName: "Mike",
                lastName: "Johnson",
                displayName: "Mike Johnson",
                accessLevel: .free,
                programs: [
                    "kungfu-program": Enrollment(
                        userId: "user3",
                        programId: "kungfu-program",
                        currentRank: "white",
                        rankDate: Date()
                    )
                ]
            )
        ]
        
        for user in sampleUsers {
            users[user.id] = user
            
            // Add sample preferences
            userPreferences[user.id] = UserPreferences(userId: user.id)
            
            // Add sample activities
            userActivities[user.id] = [
                UserActivity(userId: user.id, activityType: .login),
                UserActivity(userId: user.id, activityType: .practiceSession, details: ["duration": "30"])
            ]
        }
        
        // Set first user as current user for testing
        currentUser = sampleUsers.first
        currentUserSubject.send(currentUser)
    }
}