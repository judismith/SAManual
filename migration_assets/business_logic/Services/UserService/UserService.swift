import Foundation
import Combine

// MARK: - User Service Protocol
public protocol UserService {
    
    // MARK: - User Profile Management
    func createUser(_ userProfile: UserProfile) async throws -> UserProfile
    func getUserProfile(id: String) async throws -> UserProfile?
    func updateUserProfile(_ userProfile: UserProfile) async throws -> UserProfile
    func deleteUser(id: String) async throws
    
    // MARK: - Current User Management
    func getCurrentUser() async throws -> UserProfile?
    func updateCurrentUser(_ userProfile: UserProfile) async throws -> UserProfile
    func signOut() async throws
    
    // MARK: - User Search and Discovery
    func searchUsers(query: String, limit: Int) async throws -> [UserProfile]
    func getUsersByAccessLevel(_ accessLevel: AccessLevel) async throws -> [UserProfile]
    func getUsersByProgram(programId: String) async throws -> [UserProfile]
    
    // MARK: - User Enrollment Management
    func enrollUserInProgram(userId: String, programId: String, startingRank: String) async throws -> UserProfile
    func unenrollUserFromProgram(userId: String, programId: String) async throws -> UserProfile
    func updateUserRank(userId: String, programId: String, newRank: String) async throws -> UserProfile
    
    // MARK: - User Preferences
    func getUserPreferences(userId: String) async throws -> UserPreferences?
    func updateUserPreferences(userId: String, preferences: UserPreferences) async throws -> UserPreferences
    
    // MARK: - User Activity Tracking
    func recordUserActivity(userId: String, activity: UserActivity) async throws
    func getUserActivityHistory(userId: String, limit: Int) async throws -> [UserActivity]
    
    // MARK: - Publisher for Real-time Updates
    var currentUserPublisher: AnyPublisher<UserProfile?, Never> { get }
    var userUpdatesPublisher: AnyPublisher<UserProfile, Never> { get }
}

// MARK: - User Activity Types
public struct UserActivity: Identifiable, Codable {
    public let id = UUID()
    public let userId: String
    public let activityType: ActivityType
    public let timestamp: Date
    public let details: [String: Any]
    
    public init(userId: String, activityType: ActivityType, details: [String: Any] = [:]) {
        self.userId = userId
        self.activityType = activityType
        self.timestamp = Date()
        self.details = details
    }
    
    public enum ActivityType: String, Codable, CaseIterable {
        case login = "login"
        case logout = "logout"
        case profileUpdate = "profile_update"
        case programEnrollment = "program_enrollment"
        case rankPromotion = "rank_promotion"
        case practiceSession = "practice_session"
        case mediaView = "media_view"
        case achievementUnlocked = "achievement_unlocked"
        case subscriptionChange = "subscription_change"
    }
    
    // MARK: - Codable Implementation
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        activityType = try container.decode(ActivityType.self, forKey: .activityType)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        // Handle details dictionary
        if let detailsData = try container.decodeIfPresent(Data.self, forKey: .details) {
            details = try JSONSerialization.jsonObject(with: detailsData) as? [String: Any] ?? [:]
        } else {
            details = [:]
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(activityType, forKey: .activityType)
        try container.encode(timestamp, forKey: .timestamp)
        
        // Handle details dictionary
        let detailsData = try JSONSerialization.data(withJSONObject: details)
        try container.encode(detailsData, forKey: .details)
    }
    
    private enum CodingKeys: String, CodingKey {
        case userId, activityType, timestamp, details
    }
}

// MARK: - User Preferences
public struct UserPreferences: Codable {
    public let userId: String
    public var notificationSettings: NotificationSettings
    public var privacySettings: PrivacySettings
    public var practiceSettings: PracticeSettings
    public var displaySettings: DisplaySettings
    public let createdAt: Date
    public var updatedAt: Date
    
    public init(userId: String) {
        self.userId = userId
        self.notificationSettings = NotificationSettings()
        self.privacySettings = PrivacySettings()
        self.practiceSettings = PracticeSettings()
        self.displaySettings = DisplaySettings()
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    public struct NotificationSettings: Codable {
        public var enablePushNotifications: Bool = true
        public var enableEmailNotifications: Bool = true
        public var enablePracticeReminders: Bool = true
        public var enableRankingUpdates: Bool = true
        public var enableAnnouncementNotifications: Bool = true
        public var practiceReminderTime: DateComponents?
        
        public init() {}
    }
    
    public struct PrivacySettings: Codable {
        public var shareProgressWithInstructors: Bool = true
        public var shareProgressWithParents: Bool = true
        public var allowPublicProfile: Bool = false
        public var allowDataCollection: Bool = true
        
        public init() {}
    }
    
    public struct PracticeSettings: Codable {
        public var defaultPracticeMinutes: Int = 30
        public var preferredPracticeTime: DateComponents?
        public var enableAIGuidance: Bool = true
        public var preferredDifficulty: DifficultyLevel = .intermediate
        public var autoTrackPractice: Bool = true
        
        public init() {}
        
        public enum DifficultyLevel: String, Codable, CaseIterable {
            case beginner = "beginner"
            case intermediate = "intermediate"
            case advanced = "advanced"
            case expert = "expert"
        }
    }
    
    public struct DisplaySettings: Codable {
        public var preferredLanguage: String = "en"
        public var preferredUnit: UnitSystem = .metric
        public var showProgressAnimations: Bool = true
        public var useHighContrast: Bool = false
        public var fontSize: FontSize = .medium
        
        public init() {}
        
        public enum UnitSystem: String, Codable, CaseIterable {
            case metric = "metric"
            case imperial = "imperial"
        }
        
        public enum FontSize: String, Codable, CaseIterable {
            case small = "small"
            case medium = "medium"
            case large = "large"
            case extraLarge = "extra_large"
        }
    }
}

// MARK: - User Service Errors
public enum UserServiceError: LocalizedError, Equatable {
    case userNotFound(id: String)
    case duplicateUser(email: String)
    case invalidUserData(field: String)
    case enrollmentFailed(userId: String, programId: String)
    case unenrollmentFailed(userId: String, programId: String)
    case invalidRank(rank: String, programId: String)
    case insufficientPermissions(userId: String, operation: String)
    case userAccountDisabled(userId: String)
    case preferencesNotFound(userId: String)
    case activityRecordingFailed(userId: String)
    case networkError(underlying: Error)
    case unknown(underlying: Error)
    
    public var errorDescription: String? {
        switch self {
        case .userNotFound(let id):
            return "User not found: \(id)"
        case .duplicateUser(let email):
            return "User with email \(email) already exists"
        case .invalidUserData(let field):
            return "Invalid user data for field: \(field)"
        case .enrollmentFailed(let userId, let programId):
            return "Failed to enroll user \(userId) in program \(programId)"
        case .unenrollmentFailed(let userId, let programId):
            return "Failed to unenroll user \(userId) from program \(programId)"
        case .invalidRank(let rank, let programId):
            return "Invalid rank \(rank) for program \(programId)"
        case .insufficientPermissions(let userId, let operation):
            return "User \(userId) has insufficient permissions for operation: \(operation)"
        case .userAccountDisabled(let userId):
            return "User account disabled: \(userId)"
        case .preferencesNotFound(let userId):
            return "Preferences not found for user: \(userId)"
        case .activityRecordingFailed(let userId):
            return "Failed to record activity for user: \(userId)"
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .unknown(let underlying):
            return "Unknown error: \(underlying.localizedDescription)"
        }
    }
    
    public static func == (lhs: UserServiceError, rhs: UserServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.userNotFound(let lhsId), .userNotFound(let rhsId)):
            return lhsId == rhsId
        case (.duplicateUser(let lhsEmail), .duplicateUser(let rhsEmail)):
            return lhsEmail == rhsEmail
        case (.invalidUserData(let lhsField), .invalidUserData(let rhsField)):
            return lhsField == rhsField
        case (.enrollmentFailed(let lhsUserId, let lhsProgramId), .enrollmentFailed(let rhsUserId, let rhsProgramId)):
            return lhsUserId == rhsUserId && lhsProgramId == rhsProgramId
        case (.unenrollmentFailed(let lhsUserId, let lhsProgramId), .unenrollmentFailed(let rhsUserId, let rhsProgramId)):
            return lhsUserId == rhsUserId && lhsProgramId == rhsProgramId
        case (.invalidRank(let lhsRank, let lhsProgramId), .invalidRank(let rhsRank, let rhsProgramId)):
            return lhsRank == rhsRank && lhsProgramId == rhsProgramId
        case (.insufficientPermissions(let lhsUserId, let lhsOperation), .insufficientPermissions(let rhsUserId, let rhsOperation)):
            return lhsUserId == rhsUserId && lhsOperation == rhsOperation
        case (.userAccountDisabled(let lhsUserId), .userAccountDisabled(let rhsUserId)):
            return lhsUserId == rhsUserId
        case (.preferencesNotFound(let lhsUserId), .preferencesNotFound(let rhsUserId)):
            return lhsUserId == rhsUserId
        case (.activityRecordingFailed(let lhsUserId), .activityRecordingFailed(let rhsUserId)):
            return lhsUserId == rhsUserId
        default:
            return false
        }
    }
}