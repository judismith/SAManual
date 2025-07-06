import Foundation

// MARK: - User Domain Entity
public struct User: Identifiable, Equatable {
    public let id: String
    public let email: String
    public let name: String
    public let userType: UserType
    public let membershipType: MembershipType?
    public let enrolledPrograms: [ProgramEnrollment]
    public let accessLevel: DataAccessLevel
    public let dataStore: DataStore
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String,
        email: String,
        name: String,
        userType: UserType,
        membershipType: MembershipType? = nil,
        enrolledPrograms: [ProgramEnrollment] = [],
        accessLevel: DataAccessLevel = .freePublic,
        dataStore: DataStore = .iCloud,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.userType = userType
        self.membershipType = membershipType
        self.enrolledPrograms = enrolledPrograms
        self.accessLevel = accessLevel
        self.dataStore = dataStore
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - User Type Value Object
public enum UserType: String, Codable, CaseIterable {
    case free = "free"
    case student = "student"
    case instructor = "instructor"
    case admin = "admin"
    case parent = "parent"
    case paid = "paid"
    
    public var displayName: String {
        switch self {
        case .free: return "Free User"
        case .student: return "Student"
        case .instructor: return "Instructor"
        case .admin: return "Administrator"
        case .parent: return "Parent"
        case .paid: return "Paid User"
        }
    }
}

// MARK: - Membership Type Value Object
public enum MembershipType: String, Codable, CaseIterable {
    case student = "student"
    case instructor = "instructor"
    case assistant = "assistant"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Data Access Level Value Object
public enum DataAccessLevel: String, Codable, CaseIterable {
    case freePublic = "free_public"
    case freePrivate = "free_private"
    case userPublic = "user_public"
    case userPrivate = "user_private"
    case instructorPublic = "instructor_public"
    case instructorPrivate = "instructor_private"
    case adminPublic = "admin_public"
    case adminPrivate = "admin_private"
    
    public var displayName: String {
        switch self {
        case .freePublic: return "Free Public"
        case .freePrivate: return "Free Private"
        case .userPublic: return "User Public"
        case .userPrivate: return "User Private"
        case .instructorPublic: return "Instructor Public"
        case .instructorPrivate: return "Instructor Private"
        case .adminPublic: return "Admin Public"
        case .adminPrivate: return "Admin Private"
        }
    }
}

// MARK: - Data Store Value Object
public enum DataStore: String, Codable, CaseIterable {
    case iCloud = "icloud"
    case firestore = "firestore"
    case local = "local"
    
    public var displayName: String {
        switch self {
        case .iCloud: return "iCloud"
        case .firestore: return "Firestore"
        case .local: return "Local"
        }
    }
}

// MARK: - Program Enrollment Value Object
public struct ProgramEnrollment: Identifiable, Codable, Equatable {
    public let id: String
    public let programId: String
    public let programName: String
    public let enrolled: Bool
    public let enrollmentDate: Date
    public let currentRank: String?
    public let rankDate: Date?
    public let membershipType: MembershipType?
    public let isActive: Bool
    
    public init(
        programId: String,
        programName: String,
        enrolled: Bool = true,
        enrollmentDate: Date = Date(),
        currentRank: String? = nil,
        rankDate: Date? = nil,
        membershipType: MembershipType? = .student,
        isActive: Bool = true
    ) {
        self.id = "enrollment_\(programId)_\(UUID().uuidString.prefix(8))"
        self.programId = programId
        self.programName = programName
        self.enrolled = enrolled
        self.enrollmentDate = enrollmentDate
        self.currentRank = currentRank
        self.rankDate = rankDate
        self.membershipType = membershipType
        self.isActive = isActive
    }
} 