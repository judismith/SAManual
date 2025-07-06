import Foundation
import UIKit

// MARK: - Core Service Data Models
// These models are used by our new service protocols and are separate from existing models

// MARK: - Access Level
public enum AccessLevel: String, Codable, CaseIterable {
    case free = "free"
    case subscriber = "subscriber" 
    case instructor = "instructor"
    case admin = "admin"
    
    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .subscriber: return "Subscriber"
        case .instructor: return "Instructor"
        case .admin: return "Admin"
        }
    }
}

// MARK: - User Profile (New Architecture)
public struct UserProfile: Identifiable, Codable, Equatable {
    public let id: String
    public let email: String
    public let firstName: String
    public let lastName: String
    public let displayName: String
    public let profileImageURL: String?
    public let accessLevel: AccessLevel
    public let isActive: Bool
    public let createdAt: Date
    public var updatedAt: Date
    public let programs: [String: Enrollment] // programId -> enrollment
    
    // MARK: - Legacy Compatibility Properties
    public var name: String { displayName }
    public var profilePhotoUrl: String { profileImageURL ?? "" }
    public var userType: UserType { determineUserType() }
    public var roles: [String] { determineRoles() }
    public var uid: String { id }
    public var firebaseUid: String? { nil } // Will be set by legacy code if needed
    public var subscription: UserSubscription? { nil } // Will be set by legacy code if needed
    public var studioMembership: StudioMembership? { nil } // Will be set by legacy code if needed
    public var dataStore: DataStore { .iCloud }
    public var practiceSessions: [PracticeSession] { [] } // Will be set by legacy code if needed
    
    public init(id: String = UUID().uuidString,
                email: String,
                firstName: String,
                lastName: String,
                displayName: String? = nil,
                profileImageURL: String? = nil,
                accessLevel: AccessLevel = .free,
                isActive: Bool = true,
                programs: [String: Enrollment] = [:]) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.displayName = displayName ?? "\(firstName) \(lastName)"
        self.profileImageURL = profileImageURL
        self.accessLevel = accessLevel
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
        self.programs = programs
    }
    
    // MARK: - Legacy Compatibility Initializers
    public init(uid: String,
                firebaseUid: String? = nil,
                name: String,
                email: String,
                roles: [String] = [],
                profilePhotoUrl: String = "",
                programs: [String: ProgramEnrollment] = [:],
                subscription: UserSubscription? = nil,
                studioMembership: StudioMembership? = nil,
                dataStore: DataStore = .iCloud,
                accessLevel: DataAccessLevel = .userPrivate,
                userType: UserType? = nil) {
        self.id = uid
        self.email = email
        self.firstName = name.components(separatedBy: " ").first ?? name
        self.lastName = name.components(separatedBy: " ").dropFirst().joined(separator: " ")
        self.displayName = name
        self.profileImageURL = profilePhotoUrl.isEmpty ? nil : profilePhotoUrl
        self.accessLevel = AccessLevel.from(accessLevel)
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
        
        // Convert ProgramEnrollment to Enrollment
        var convertedPrograms: [String: Enrollment] = [:]
        for (programId, programEnrollment) in programs {
            convertedPrograms[programId] = Enrollment.from(programEnrollment)
        }
        self.programs = convertedPrograms
    }
    
    // MARK: - Legacy Compatibility Methods
    public func hasEnrolledPrograms() -> Bool {
        return programs.values.contains { $0.enrolled }
    }
    
    // MARK: - Private Helper Methods
    private func determineUserType() -> UserType {
        // Determine user type based on access level and programs
        switch accessLevel {
        case .admin:
            return .admin
        case .instructor:
            return .instructor
        case .subscriber:
            return hasEnrolledPrograms() ? .student : .paidUser
        case .free:
            return hasEnrolledPrograms() ? .student : .freeUser
        }
    }
    
    private func determineRoles() -> [String] {
        var roles: [String] = []
        
        switch accessLevel {
        case .admin:
            roles.append("admin")
        case .instructor:
            roles.append("instructor")
        case .subscriber:
            roles.append("subscriber")
            if hasEnrolledPrograms() {
                roles.append("student")
            }
        case .free:
            if hasEnrolledPrograms() {
                roles.append("student")
            } else {
                roles.append("public")
            }
        }
        
        return roles
    }
}

// MARK: - Legacy Type Compatibility Extensions
extension AccessLevel {
    static func from(_ legacyAccessLevel: DataAccessLevel) -> AccessLevel {
        switch legacyAccessLevel {
        case .freePublic, .freePrivate:
            return .free
        case .userPrivate, .userPublic:
            return .subscriber
        case .instructorPrivate, .instructorPublic:
            return .instructor
        case .adminPrivate, .adminPublic:
            return .admin
        }
    }
}

extension Enrollment {
    static func from(_ programEnrollment: ProgramEnrollment) -> Enrollment {
        return Enrollment(
            id: programEnrollment.id,
            userId: "", // Will be set by the service
            programId: programEnrollment.programId,
            enrolled: programEnrollment.enrolled,
            enrollmentDate: programEnrollment.enrollmentDate,
            currentRank: programEnrollment.currentRank,
            rankDate: programEnrollment.rankDate,
            isActive: programEnrollment.isActive
        )
    }
}

// MARK: - Legacy Types (for compatibility)
public enum UserType: String, Codable, CaseIterable {
    case freeUser = "free_user"
    case paidUser = "paid_user"
    case student = "student"
    case parent = "parent"
    case instructor = "instructor"
    case admin = "admin"
    
    public var displayName: String {
        switch self {
        case .freeUser: return "Free User"
        case .paidUser: return "Paid User"
        case .student: return "Student"
        case .parent: return "Parent"
        case .instructor: return "Instructor"
        case .admin: return "Admin"
        }
    }
}

public enum DataStore: String, Codable, CaseIterable {
    case iCloud = "icloud"
    case firestore = "firestore"
    case local = "local"
}

public enum DataAccessLevel: String, Codable, CaseIterable {
    case freePublic = "free_public"
    case freePrivate = "free_private"
    case userPublic = "user_public"
    case userPrivate = "user_private"
    case instructorPublic = "instructor_public"
    case instructorPrivate = "instructor_private"
    case adminPublic = "admin_public"
    case adminPrivate = "admin_private"
}

public struct UserSubscription: Identifiable, Codable, Equatable {
    public let id: String
    public let userId: String
    public let type: String
    public let isActive: Bool
    public let startDate: Date
    public let endDate: Date?
    
    public init(id: String = UUID().uuidString,
                userId: String,
                type: String,
                isActive: Bool = true,
                startDate: Date = Date(),
                endDate: Date? = nil) {
        self.id = id
        self.userId = userId
        self.type = type
        self.isActive = isActive
        self.startDate = startDate
        self.endDate = endDate
    }
}

public struct StudioMembership: Identifiable, Codable, Equatable {
    public let id: String
    public let userId: String
    public let studioName: String
    public let isActive: Bool
    public let startDate: Date
    public let endDate: Date?
    
    public init(id: String = UUID().uuidString,
                userId: String,
                studioName: String,
                isActive: Bool = true,
                startDate: Date = Date(),
                endDate: Date? = nil) {
        self.id = id
        self.userId = userId
        self.studioName = studioName
        self.isActive = isActive
        self.startDate = startDate
        self.endDate = endDate
    }
}

public struct PracticeSession: Identifiable, Codable, Equatable {
    public let id: String
    public let userId: String
    public let programId: String
    public let startTime: Date
    public let endTime: Date?
    public let duration: TimeInterval
    public let notes: String?
    
    public init(id: String = UUID().uuidString,
                userId: String,
                programId: String,
                startTime: Date = Date(),
                endTime: Date? = nil,
                duration: TimeInterval = 0,
                notes: String? = nil) {
        self.id = id
        self.userId = userId
        self.programId = programId
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.notes = notes
    }
}

// MARK: - Enrollment
public struct Enrollment: Identifiable, Codable, Equatable {
    public let id: String
    public let userId: String
    public let programId: String
    public let enrolled: Bool
    public let enrollmentDate: Date
    public let currentRank: String?
    public let rankDate: Date?
    public let isActive: Bool
    
    public init(id: String = UUID().uuidString,
                userId: String,
                programId: String,
                enrolled: Bool = true,
                enrollmentDate: Date = Date(),
                currentRank: String? = nil,
                rankDate: Date? = nil,
                isActive: Bool = true) {
        self.id = id
        self.userId = userId
        self.programId = programId
        self.enrolled = enrolled
        self.enrollmentDate = enrollmentDate
        self.currentRank = currentRank
        self.rankDate = rankDate
        self.isActive = isActive
    }
}

// MARK: - Program Enrollment
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
    
    public init(programId: String, programName: String, enrolled: Bool = true, enrollmentDate: Date = Date(), currentRank: String? = nil, rankDate: Date? = nil, membershipType: MembershipType? = .student, isActive: Bool = true) {
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

public enum MembershipType: String, Codable, CaseIterable {
    case student = "student"
    case instructor = "instructor"
    case assistant = "assistant"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Program Type
public enum ProgramType: String, Codable, CaseIterable {
    case kungFu = "kung_fu"
    case youthKungFu = "youth_kung_fu"
    case meditation = "meditation"
    case selfDefense = "self_defense"
    case weaponsForms = "weapons_forms"
    case conditioning = "conditioning"
    case demonstration = "demonstration"
    case competition = "competition"
    
    public var displayName: String {
        switch self {
        case .kungFu: return "Kung Fu"
        case .youthKungFu: return "Youth Kung Fu"
        case .meditation: return "Meditation"
        case .selfDefense: return "Self Defense"
        case .weaponsForms: return "Weapons Forms"
        case .conditioning: return "Conditioning"
        case .demonstration: return "Demonstration"
        case .competition: return "Competition"
        }
    }
    
    public var isYouthProgram: Bool {
        return self == .youthKungFu
    }
}

// MARK: - Curriculum Item Type
public enum CurriculumItemType: String, Codable, CaseIterable {
    case form = "form"
    case technique = "technique"
    case exercise = "exercise"
    case theory = "theory"
    case sparring = "sparring"
    case meditation = "meditation"
    case breathing = "breathing"
    case warmup = "warmup"
    case cooldown = "cooldown"
    case conditioning = "conditioning"
    case weaponForm = "weapon_form"
    case selfDefense = "self_defense"
    
    public var displayName: String {
        switch self {
        case .form: return "Form"
        case .technique: return "Technique"
        case .exercise: return "Exercise"
        case .theory: return "Theory"
        case .sparring: return "Sparring"
        case .meditation: return "Meditation"
        case .breathing: return "Breathing"
        case .warmup: return "Warm-up"
        case .cooldown: return "Cool-down"
        case .conditioning: return "Conditioning"
        case .weaponForm: return "Weapon Form"
        case .selfDefense: return "Self Defense"
        }
    }
}

// MARK: - Curriculum Item
public struct CurriculumItem: Identifiable, Codable, Equatable {
    public let id: String
    public let programId: String
    public let rankId: String
    public let name: String
    public let description: String
    public let type: CurriculumItemType
    public let order: Int
    public let requiredForPromotion: Bool
    public let mediaUrls: [String]
    public let writtenInstructions: String?
    public let estimatedPracticeTime: TimeInterval
    public let difficulty: DifficultyLevel
    public let prerequisites: [String]
    public let tags: [String]
    public let createdAt: Date
    public var updatedAt: Date
    
    public init(id: String = UUID().uuidString,
                programId: String,
                rankId: String,
                name: String,
                description: String,
                type: CurriculumItemType,
                order: Int,
                requiredForPromotion: Bool = false,
                mediaUrls: [String] = [],
                writtenInstructions: String? = nil,
                estimatedPracticeTime: TimeInterval = 0,
                difficulty: DifficultyLevel = .intermediate,
                prerequisites: [String] = [],
                tags: [String] = []) {
        self.id = id
        self.programId = programId
        self.rankId = rankId
        self.name = name
        self.description = description
        self.type = type
        self.order = order
        self.requiredForPromotion = requiredForPromotion
        self.mediaUrls = mediaUrls
        self.writtenInstructions = writtenInstructions
        self.estimatedPracticeTime = estimatedPracticeTime
        self.difficulty = difficulty
        self.prerequisites = prerequisites
        self.tags = tags
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Program
public struct Program: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let description: String
    public let type: ProgramType
    public let isActive: Bool
    public let instructorIds: [String]
    public let ranks: [Rank]
    public let curriculum: [CurriculumItem]
    public let createdAt: Date
    public var updatedAt: Date
    
    public init(id: String = UUID().uuidString,
                name: String,
                description: String,
                type: ProgramType,
                isActive: Bool = true,
                instructorIds: [String] = [],
                ranks: [Rank] = [],
                curriculum: [CurriculumItem] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.isActive = isActive
        self.instructorIds = instructorIds
        self.ranks = ranks
        self.curriculum = curriculum
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Rank
public struct Rank: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let order: Int
    public let color: String
    public let description: String
    public let requirements: [String]
    public let timeRequirement: TimeInterval?
    public let stripes: Int
    
    public init(id: String = UUID().uuidString,
                name: String,
                order: Int,
                color: String,
                description: String,
                requirements: [String] = [],
                timeRequirement: TimeInterval? = nil,
                stripes: Int = 0) {
        self.id = id
        self.name = name
        self.order = order
        self.color = color
        self.description = description
        self.requirements = requirements
        self.timeRequirement = timeRequirement
        self.stripes = stripes
    }
}

// MARK: - Difficulty Level
public enum DifficultyLevel: String, Codable, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Program Progress
public struct ProgramProgress: Identifiable, Codable, Equatable {
    public let id: String
    public let userId: String
    public let programId: String
    public let currentRankId: String
    public let startDate: Date
    public var lastPracticeDate: Date?
    public var totalPracticeTime: TimeInterval
    public var completedItems: [String]
    public var masteredItems: [String]
    public var rankProgresses: [RankProgress]
    public var overallProgress: Double
    public var notes: String?
    public let createdAt: Date
    public var updatedAt: Date
    
    public init(id: String = UUID().uuidString,
                userId: String,
                programId: String,
                currentRankId: String,
                startDate: Date = Date()) {
        self.id = id
        self.userId = userId
        self.programId = programId
        self.currentRankId = currentRankId
        self.startDate = startDate
        self.lastPracticeDate = nil
        self.totalPracticeTime = 0
        self.completedItems = []
        self.masteredItems = []
        self.rankProgresses = []
        self.overallProgress = 0.0
        self.notes = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Practice Focus Area
public struct PracticeFocusArea: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let description: String
    public let priority: Int
    public let category: PracticeFocusCategory
    
    public init(id: String = UUID().uuidString,
                name: String,
                description: String,
                priority: Int,
                category: PracticeFocusCategory) {
        self.id = id
        self.name = name
        self.description = description
        self.priority = priority
        self.category = category
    }
}

// MARK: - Practice Focus Category
public enum PracticeFocusCategory: String, Codable, CaseIterable {
    case technique = "technique"
    case form = "form"
    case conditioning = "conditioning"
    case flexibility = "flexibility"
    case sparring = "sparring"
    case meditation = "meditation"
    case general = "general"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Recommended Item
public struct RecommendedItem: Identifiable, Codable, Equatable {
    public let id: String
    public let curriculumItemId: String
    public let title: String
    public let description: String
    public let priority: RecommendationPriority
    public let estimatedTime: TimeInterval
    public let reason: String
    public let focusAreas: [String]
    public let difficultyLevel: DifficultyLevel
    
    public init(id: String = UUID().uuidString,
                curriculumItemId: String,
                title: String,
                description: String,
                priority: RecommendationPriority,
                estimatedTime: TimeInterval,
                reason: String,
                focusAreas: [String] = [],
                difficultyLevel: DifficultyLevel = .intermediate) {
        self.id = id
        self.curriculumItemId = curriculumItemId
        self.title = title
        self.description = description
        self.priority = priority
        self.estimatedTime = estimatedTime
        self.reason = reason
        self.focusAreas = focusAreas
        self.difficultyLevel = difficultyLevel
    }
}

// MARK: - Recommendation Priority
public enum RecommendationPriority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var numericValue: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .urgent: return 4
        }
    }
}

// MARK: - Content Type
public enum ContentType: String, Codable, CaseIterable {
    case program = "program"
    case technique = "technique"
    case form = "form"
    case announcement = "announcement"
    case principle = "principle"
    case exercise = "exercise"
    
    public var displayName: String {
        switch self {
        case .program: return "Program"
        case .technique: return "Technique"
        case .form: return "Form"
        case .announcement: return "Announcement"
        case .principle: return "Principle"
        case .exercise: return "Exercise"
        }
    }
    
    public var icon: String {
        switch self {
        case .program: return "list.bullet.rectangle"
        case .technique: return "figure.martial.arts"
        case .form: return "figure.mixed.cardio"
        case .announcement: return "megaphone"
        case .principle: return "lightbulb"
        case .exercise: return "figure.strengthtraining.traditional"
        }
    }
}

// MARK: - Program Analytics (Overall Program Statistics)
public struct ProgramAnalytics: Codable, Equatable {
    public let programId: String
    public let totalStudents: Int
    public let activeStudents: Int
    public let averageProgress: Double
    public let completionRate: Double
    public let popularItems: [String]
    public let analyticsDate: Date
    public let totalSessions: Int
    public let averageSessionTime: TimeInterval
    
    public init(programId: String, totalStudents: Int = 0, activeStudents: Int = 0, averageProgress: Double = 0, completionRate: Double = 0, popularItems: [String] = [], analyticsDate: Date = Date(), totalSessions: Int = 0, averageSessionTime: TimeInterval = 0) {
        self.programId = programId
        self.totalStudents = totalStudents
        self.activeStudents = activeStudents
        self.averageProgress = averageProgress
        self.completionRate = completionRate
        self.popularItems = popularItems
        self.analyticsDate = analyticsDate
        self.totalSessions = totalSessions
        self.averageSessionTime = averageSessionTime
    }
}

// MARK: - User Program Analytics (Individual User Performance)
public struct UserProgramAnalytics: Codable, Equatable {
    public let userId: String
    public let programId: String
    public let totalPracticeTime: TimeInterval
    public let sessionsCount: Int
    public let averageSessionTime: TimeInterval
    public let practiceFrequency: Double // sessions per week
    public let progressRate: Double // percentage per week
    public let lastActivityDate: Date?
    public let streakDays: Int
    public let monthlyProgress: [String: Double] // month -> progress
    
    public init(userId: String, programId: String, totalPracticeTime: TimeInterval = 0, sessionsCount: Int = 0, averageSessionTime: TimeInterval = 0, practiceFrequency: Double = 0, progressRate: Double = 0, lastActivityDate: Date? = nil, streakDays: Int = 0, monthlyProgress: [String: Double] = [:]) {
        self.userId = userId
        self.programId = programId
        self.totalPracticeTime = totalPracticeTime
        self.sessionsCount = sessionsCount
        self.averageSessionTime = averageSessionTime
        self.practiceFrequency = practiceFrequency
        self.progressRate = progressRate
        self.lastActivityDate = lastActivityDate
        self.streakDays = streakDays
        self.monthlyProgress = monthlyProgress
    }
}

// MARK: - Date Range
public struct DateRange: Codable, Equatable {
    public let start: Date
    public let end: Date
    
    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
    
    public var duration: TimeInterval {
        return end.timeIntervalSince(start)
    }
}

// MARK: - Media Analytics
public struct MediaAnalytics: Codable, Equatable {
    public let mediaId: String
    public let viewCount: Int
    public let downloadCount: Int
    public let shareCount: Int
    public let averageViewDuration: TimeInterval
    public let popularityScore: Double
    public let lastAccessDate: Date?
    public let topUsers: [String] // user IDs with most access
    
    public init(mediaId: String, viewCount: Int = 0, downloadCount: Int = 0, shareCount: Int = 0, averageViewDuration: TimeInterval = 0, popularityScore: Double = 0, lastAccessDate: Date? = nil, topUsers: [String] = []) {
        self.mediaId = mediaId
        self.viewCount = viewCount
        self.downloadCount = downloadCount
        self.shareCount = shareCount
        self.averageViewDuration = averageViewDuration
        self.popularityScore = popularityScore
        self.lastAccessDate = lastAccessDate
        self.topUsers = topUsers
    }
}

// MARK: - Storage Quota
public struct StorageQuota: Codable, Equatable {
    public let userId: String
    public let totalQuota: Int64 // bytes
    public let usedStorage: Int64 // bytes
    public let mediaCount: Int
    public let lastUpdated: Date
    
    public init(userId: String, totalQuota: Int64, usedStorage: Int64 = 0, mediaCount: Int = 0, lastUpdated: Date = Date()) {
        self.userId = userId
        self.totalQuota = totalQuota
        self.usedStorage = usedStorage
        self.mediaCount = mediaCount
        self.lastUpdated = lastUpdated
    }
    
    public var availableStorage: Int64 {
        return max(0, totalQuota - usedStorage)
    }
    
    public var usagePercentage: Double {
        guard totalQuota > 0 else { return 0 }
        return Double(usedStorage) / Double(totalQuota) * 100
    }
}

// MARK: - Progress Type
public enum ProgressType: String, Codable, CaseIterable {
    case curriculum = "curriculum"
    case rank = "rank" 
    case skill = "skill"
    case form = "form"
    case technique = "technique"
    case conditioning = "conditioning"
    case overall = "overall"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Membership Status
public enum MembershipStatus: String, Codable, CaseIterable {
    case active = "active"
    case inactive = "inactive"
    case suspended = "suspended"
    case expired = "expired"
    case pendingRenewal = "pending_renewal"
    
    public var displayName: String {
        switch self {
        case .active: return "Active"
        case .inactive: return "Inactive"
        case .suspended: return "Suspended"
        case .expired: return "Expired"
        case .pendingRenewal: return "Pending Renewal"
        }
    }
}

// MARK: - Rank Progress Data
public struct RankProgressData: Codable, Equatable {
    public let rankId: String
    public let rankName: String
    public let progress: Double
    public let completedItems: [String]
    public let totalItems: Int
    public let estimatedCompletion: Date?
    public let lastUpdated: Date
    
    public init(rankId: String, rankName: String, progress: Double, completedItems: [String] = [], totalItems: Int, estimatedCompletion: Date? = nil, lastUpdated: Date = Date()) {
        self.rankId = rankId
        self.rankName = rankName
        self.progress = progress
        self.completedItems = completedItems
        self.totalItems = totalItems
        self.estimatedCompletion = estimatedCompletion
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Rank Progress
public struct RankProgress: Identifiable, Codable, Equatable {
    public let id: String
    public let userId: String
    public let programId: String
    public let rankId: String
    public let startDate: Date
    public var completionDate: Date?
    public var completedItems: [String]
    public var masteredItems: [String]
    public var progress: Double
    public var isCompleted: Bool
    public var notes: String?
    public let createdAt: Date
    public var updatedAt: Date
    
    public init(id: String = UUID().uuidString,
                userId: String,
                programId: String,
                rankId: String,
                startDate: Date = Date()) {
        self.id = id
        self.userId = userId
        self.programId = programId
        self.rankId = rankId
        self.startDate = startDate
        self.completionDate = nil
        self.completedItems = []
        self.masteredItems = []
        self.progress = 0.0
        self.isCompleted = false
        self.notes = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Computed properties for compatibility
    public var progressPercentage: Int {
        return Int(progress * 100)
    }
}