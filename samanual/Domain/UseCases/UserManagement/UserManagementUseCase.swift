import Foundation

// MARK: - User Management Use Case Protocol
public protocol UserManagementUseCaseProtocol {
    /// Get user profile by ID
    /// - Parameter id: User ID
    /// - Returns: User profile
    /// - Throws: AppError if user not found or access denied
    func getUser(id: String) async throws -> User
    
    /// Update user profile
    /// - Parameter user: Updated user profile
    /// - Returns: Updated user profile
    /// - Throws: AppError if update fails
    func updateUser(_ user: User) async throws -> User
    
    /// Delete user account
    /// - Parameter id: User ID to delete
    /// - Throws: AppError if deletion fails
    func deleteUser(id: String) async throws
    
    /// Get user's enrolled programs
    /// - Parameter userId: User ID
    /// - Returns: Array of enrolled programs
    /// - Throws: AppError if retrieval fails
    func getUserPrograms(userId: String) async throws -> [Program]
    
    /// Enroll user in a program
    /// - Parameters:
    ///   - userId: User ID
    ///   - programId: Program ID to enroll in
    /// - Returns: Updated user profile
    /// - Throws: AppError if enrollment fails
    func enrollUserInProgram(userId: String, programId: String) async throws -> User
    
    /// Unenroll user from a program
    /// - Parameters:
    ///   - userId: User ID
    ///   - programId: Program ID to unenroll from
    /// - Returns: Updated user profile
    /// - Throws: AppError if unenrollment fails
    func unenrollUserFromProgram(userId: String, programId: String) async throws -> User
    
    /// Update user's current rank in a program
    /// - Parameters:
    ///   - userId: User ID
    ///   - programId: Program ID
    ///   - newRank: New rank to assign
    /// - Returns: Updated user profile
    /// - Throws: AppError if rank update fails
    func updateUserRank(userId: String, programId: String, newRank: String) async throws -> User
    
    /// Check if user has access to a specific feature
    /// - Parameters:
    ///   - userId: User ID
    ///   - feature: Feature to check access for
    /// - Returns: True if user has access, false otherwise
    func hasAccess(userId: String, feature: UserFeature) -> Bool
    
    /// Get user's access level
    /// - Parameter userId: User ID
    /// - Returns: User's access level
    /// - Throws: AppError if user not found
    func getUserAccessLevel(userId: String) async throws -> DataAccessLevel
}

// MARK: - User Management Use Case Implementation
public final class UserManagementUseCase: UserManagementUseCaseProtocol {
    
    // MARK: - Dependencies
    private let userRepository: UserRepositoryProtocol
    private let programRepository: ProgramRepositoryProtocol
    private let enrollmentRepository: EnrollmentRepositoryProtocol
    
    // MARK: - Initialization
    public init(
        userRepository: UserRepositoryProtocol,
        programRepository: ProgramRepositoryProtocol,
        enrollmentRepository: EnrollmentRepositoryProtocol
    ) {
        self.userRepository = userRepository
        self.programRepository = programRepository
        self.enrollmentRepository = enrollmentRepository
    }
    
    // MARK: - UserManagementUseCaseProtocol Implementation
    
    public func getUser(id: String) async throws -> User {
        guard !id.isEmpty else {
            throw AppError.invalidUserData(field: "id", message: "User ID cannot be empty")
        }
        
        do {
            return try await userRepository.getUser(id: id)
        } catch {
            throw AppError.userNotFound(id: id)
        }
    }
    
    public func updateUser(_ user: User) async throws -> User {
        // Validate user data
        try validateUserData(user)
        
        do {
            return try await userRepository.updateUser(user)
        } catch {
            throw AppError.invalidUserData(field: "update", message: "Failed to update user: \(error.localizedDescription)")
        }
    }
    
    public func deleteUser(id: String) async throws {
        guard !id.isEmpty else {
            throw AppError.invalidUserData(field: "id", message: "User ID cannot be empty")
        }
        
        do {
            try await userRepository.deleteUser(id: id)
        } catch {
            throw AppError.invalidUserData(field: "delete", message: "Failed to delete user: \(error.localizedDescription)")
        }
    }
    
    public func getUserPrograms(userId: String) async throws -> [Program] {
        guard !userId.isEmpty else {
            throw AppError.invalidUserData(field: "userId", message: "User ID cannot be empty")
        }
        
        let user = try await getUser(id: userId)
        let programIds = user.enrolledPrograms.map { $0.programId }
        
        var programs: [Program] = []
        for programId in programIds {
            if let program = try? await programRepository.getProgram(id: programId) {
                programs.append(program)
            }
        }
        
        return programs
    }
    
    public func enrollUserInProgram(userId: String, programId: String) async throws -> User {
        // Validate inputs
        guard !userId.isEmpty else {
            throw AppError.invalidUserData(field: "userId", message: "User ID cannot be empty")
        }
        guard !programId.isEmpty else {
            throw AppError.invalidUserData(field: "programId", message: "Program ID cannot be empty")
        }
        
        // Get user and program
        let user = try await getUser(id: userId)
        guard let program = try? await programRepository.getProgram(id: programId) else {
            throw AppError.programNotFound(id: programId)
        }
        
        // Check if user is already enrolled
        if user.enrolledPrograms.contains(where: { $0.programId == programId }) {
            throw AppError.enrollmentFailed(userId: userId, programId: programId, reason: "User already enrolled")
        }
        
        // Create enrollment
        let enrollment = ProgramEnrollment(
            programId: programId,
            programName: program.name,
            enrolled: true,
            enrollmentDate: Date(),
            membershipType: .student,
            isActive: true
        )
        
        // Update user with new enrollment
        var updatedUser = user
        updatedUser = User(
            id: user.id,
            email: user.email,
            name: user.name,
            userType: user.userType,
            membershipType: user.membershipType,
            enrolledPrograms: user.enrolledPrograms + [enrollment],
            accessLevel: user.accessLevel,
            dataStore: user.dataStore,
            createdAt: user.createdAt,
            updatedAt: Date()
        )
        
        return try await updateUser(updatedUser)
    }
    
    public func unenrollUserFromProgram(userId: String, programId: String) async throws -> User {
        // Validate inputs
        guard !userId.isEmpty else {
            throw AppError.invalidUserData(field: "userId", message: "User ID cannot be empty")
        }
        guard !programId.isEmpty else {
            throw AppError.invalidUserData(field: "programId", message: "Program ID cannot be empty")
        }
        
        let user = try await getUser(id: userId)
        
        // Check if user is enrolled
        guard user.enrolledPrograms.contains(where: { $0.programId == programId }) else {
            throw AppError.enrollmentFailed(userId: userId, programId: programId, reason: "User not enrolled in program")
        }
        
        // Remove enrollment
        let updatedEnrollments = user.enrolledPrograms.filter { $0.programId != programId }
        
        var updatedUser = user
        updatedUser = User(
            id: user.id,
            email: user.email,
            name: user.name,
            userType: user.userType,
            membershipType: user.membershipType,
            enrolledPrograms: updatedEnrollments,
            accessLevel: user.accessLevel,
            dataStore: user.dataStore,
            createdAt: user.createdAt,
            updatedAt: Date()
        )
        
        return try await updateUser(updatedUser)
    }
    
    public func updateUserRank(userId: String, programId: String, newRank: String) async throws -> User {
        // Validate inputs
        guard !userId.isEmpty else {
            throw AppError.invalidUserData(field: "userId", message: "User ID cannot be empty")
        }
        guard !programId.isEmpty else {
            throw AppError.invalidUserData(field: "programId", message: "Program ID cannot be empty")
        }
        guard !newRank.isEmpty else {
            throw AppError.invalidUserData(field: "rank", message: "Rank cannot be empty")
        }
        
        let user = try await getUser(id: userId)
        
        // Find and update the specific enrollment
        var updatedEnrollments = user.enrolledPrograms
        if let index = updatedEnrollments.firstIndex(where: { $0.programId == programId }) {
            updatedEnrollments[index] = ProgramEnrollment(
                programId: updatedEnrollments[index].programId,
                programName: updatedEnrollments[index].programName,
                enrolled: updatedEnrollments[index].enrolled,
                enrollmentDate: updatedEnrollments[index].enrollmentDate,
                currentRank: newRank,
                rankDate: Date(),
                membershipType: updatedEnrollments[index].membershipType,
                isActive: updatedEnrollments[index].isActive
            )
        } else {
            throw AppError.enrollmentFailed(userId: userId, programId: programId, reason: "User not enrolled in program")
        }
        
        var updatedUser = user
        updatedUser = User(
            id: user.id,
            email: user.email,
            name: user.name,
            userType: user.userType,
            membershipType: user.membershipType,
            enrolledPrograms: updatedEnrollments,
            accessLevel: user.accessLevel,
            dataStore: user.dataStore,
            createdAt: user.createdAt,
            updatedAt: Date()
        )
        
        return try await updateUser(updatedUser)
    }
    
    public func hasAccess(userId: String, feature: UserFeature) -> Bool {
        // This would typically check user permissions and subscription status
        // For now, return true for basic features
        switch feature {
        case .basicContent:
            return true
        case .premiumContent:
            // Would check subscription status
            return false
        case .instructorTools:
            // Would check if user is instructor
            return false
        case .adminTools:
            // Would check if user is admin
            return false
        }
    }
    
    public func getUserAccessLevel(userId: String) async throws -> DataAccessLevel {
        let user = try await getUser(id: userId)
        return user.accessLevel
    }
    
    // MARK: - Private Helper Methods
    
    private func validateUserData(_ user: User) throws {
        guard !user.email.isEmpty else {
            throw AppError.invalidUserData(field: "email", message: "Email cannot be empty")
        }
        guard !user.name.isEmpty else {
            throw AppError.invalidUserData(field: "name", message: "Name cannot be empty")
        }
        guard isValidEmail(user.email) else {
            throw AppError.invalidUserData(field: "email", message: "Invalid email format")
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// MARK: - Supporting Types

public enum UserFeature: String, CaseIterable {
    case basicContent = "basic_content"
    case premiumContent = "premium_content"
    case instructorTools = "instructor_tools"
    case adminTools = "admin_tools"
    
    public var displayName: String {
        switch self {
        case .basicContent: return "Basic Content"
        case .premiumContent: return "Premium Content"
        case .instructorTools: return "Instructor Tools"
        case .adminTools: return "Admin Tools"
        }
    }
}

// MARK: - Repository Protocols (to be implemented in Data layer)

public protocol ProgramRepositoryProtocol {
    func getProgram(id: String) async throws -> Program?
    func getPrograms() async throws -> [Program]
    func createProgram(_ program: Program) async throws -> Program
    func updateProgram(_ program: Program) async throws -> Program
    func deleteProgram(id: String) async throws
}

public protocol EnrollmentRepositoryProtocol {
    func getEnrollments(userId: String) async throws -> [ProgramEnrollment]
    func createEnrollment(_ enrollment: ProgramEnrollment) async throws -> ProgramEnrollment
    func updateEnrollment(_ enrollment: ProgramEnrollment) async throws -> ProgramEnrollment
    func deleteEnrollment(id: String) async throws
} 