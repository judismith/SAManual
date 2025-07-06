import Foundation

// MARK: - User Mapper
public struct UserMapper {
    
    // MARK: - Domain to DTO
    public static func toDTO(_ user: User) -> UserDTO {
        return UserDTO(
            id: user.id,
            email: user.email,
            name: user.name,
            userType: user.userType.rawValue,
            membershipType: user.membershipType?.rawValue,
            accessLevel: user.accessLevel.rawValue,
            dataStore: user.dataStore.rawValue,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt,
            isActive: true,
            profile: nil,
            enrollments: user.enrolledPrograms.map { ProgramEnrollmentMapper.toDTO($0) }
        )
    }
    
    // MARK: - DTO to Domain
    public static func toDomain(_ dto: UserDTO) throws -> User {
        guard let userType = UserType(rawValue: dto.userType) else {
            throw AppError.invalidUserData(field: "userType", message: "Invalid user type: \(dto.userType)")
        }
        
        guard let accessLevel = DataAccessLevel(rawValue: dto.accessLevel) else {
            throw AppError.invalidUserData(field: "accessLevel", message: "Invalid access level: \(dto.accessLevel)")
        }
        
        guard let dataStore = DataStore(rawValue: dto.dataStore) else {
            throw AppError.invalidUserData(field: "dataStore", message: "Invalid data store: \(dto.dataStore)")
        }
        
        let membershipType = dto.membershipType.flatMap { MembershipType(rawValue: $0) }
        let enrollments = try dto.enrollments.map { try ProgramEnrollmentMapper.toDomain($0) }
        
        return User(
            id: dto.id,
            email: dto.email,
            name: dto.name,
            userType: userType,
            membershipType: membershipType,
            enrolledPrograms: enrollments,
            accessLevel: accessLevel,
            dataStore: dataStore,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }
    
    // MARK: - Batch Operations
    public static func toDTOArray(_ users: [User]) -> [UserDTO] {
        return users.map { toDTO($0) }
    }
    
    public static func toDomainArray(_ dtos: [UserDTO]) throws -> [User] {
        return try dtos.map { try toDomain($0) }
    }
}



// MARK: - Program Enrollment Mapper
public struct ProgramEnrollmentMapper {
    
    public static func toDTO(_ enrollment: ProgramEnrollment) -> ProgramEnrollmentDTO {
        return ProgramEnrollmentDTO(
            id: enrollment.id,
            userId: "",
            programId: enrollment.programId,
            enrolled: enrollment.enrolled,
            enrollmentDate: enrollment.enrollmentDate,
            startDate: nil,
            endDate: nil,
            currentRank: enrollment.currentRank,
            progress: 0.0
        )
    }
    
    public static func toDomain(_ dto: ProgramEnrollmentDTO) throws -> ProgramEnrollment {
        return ProgramEnrollment(
            programId: dto.programId,
            programName: "Unknown Program",
            enrolled: dto.enrolled,
            enrollmentDate: dto.enrollmentDate ?? Date(),
            currentRank: dto.currentRank,
            rankDate: nil,
            membershipType: nil,
            isActive: true
        )
    }
} 