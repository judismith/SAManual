import Foundation

// Import types from ServiceModels.swift
// Note: DataAccessLevel and DataStore are now defined in ServiceModels.swift

enum MediaContentType: String, Codable, CaseIterable {
    case announcement = "announcement"
    case tutorial = "tutorial"
    case demo = "demo"
    // Add more as needed
    
    var displayName: String {
        switch self {
        case .announcement: return "Announcement"
        case .tutorial: return "Tutorial"
        case .demo: return "Demo"
        }
    }
}

struct MediaContent: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let type: MediaContentType // migrated from String
    let mediaUrl: String
    let thumbnailUrl: String?
    let publishedDate: Date
    let author: String
    let tags: [String]
    let accessLevel: DataAccessLevel
    let dataStore: DataStore
    let subscriptionRequired: SubscriptionType?
    let mediaStorageLocation: MediaStorageLocation
    let isUserGenerated: Bool
    
    // Enhanced targeting fields
    let targeting: ContentTargeting
    
    // Custom initializer for easier creation
    init(
        id: String,
        title: String,
        description: String,
        type: MediaContentType,
        mediaUrl: String,
        thumbnailUrl: String?,
        publishedDate: Date,
        author: String,
        tags: [String],
        accessLevel: DataAccessLevel,
        dataStore: DataStore,
        subscriptionRequired: SubscriptionType?,
        mediaStorageLocation: MediaStorageLocation,
        isUserGenerated: Bool,
        targeting: ContentTargeting
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.mediaUrl = mediaUrl
        self.thumbnailUrl = thumbnailUrl
        self.publishedDate = publishedDate
        self.author = author
        self.tags = tags
        self.accessLevel = accessLevel
        self.dataStore = dataStore
        self.subscriptionRequired = subscriptionRequired
        self.mediaStorageLocation = mediaStorageLocation
        self.isUserGenerated = isUserGenerated
        self.targeting = targeting
    }
    
    // Computed properties for backward compatibility
    var targetAudience: TargetAudience {
        return targeting.audience
    }
    
    var targetPrograms: [String]? {
        return targeting.programs
    }
    
    var targetRoles: [String]? {
        return targeting.roles
    }
    
    // Computed property to check if announcement targets everyone
    var targetsEveryone: Bool {
        return targeting.audience == .everyone
    }
    
    // Computed property to check if announcement targets specific programs
    var targetsSpecificPrograms: Bool {
        return targeting.audience == .programs && !(targeting.programs?.isEmpty ?? true)
    }
    
    // Computed property to check if announcement targets specific roles
    var targetsSpecificRoles: Bool {
        return targeting.audience == .roles && !(targeting.roles?.isEmpty ?? true)
    }
}

// Enhanced targeting structure
struct ContentTargeting: Codable {
    // Primary audience targeting
    let audience: TargetAudience
    
    // Specific targeting criteria
    let programs: [String]? // Program IDs to target
    let roles: [String]? // User roles to target
    let studios: [String]? // Studio IDs to target
    let regions: [String]? // Geographic regions to target
    
    // Subscription-based targeting
    let subscriptionTypes: [SubscriptionType]? // Free, Premium, etc.
    
    // Temporal targeting
    let userAgeRange: UserAgeRange? // New users, inactive users, etc.
    let trialStatus: TrialStatus?
    
    // Behavioral targeting
    let userBehaviors: [UserBehavior]?
    
    // Content-based targeting
    let targetRanks: [String]? // Specific belt levels
    let targetTechniques: [String]? // Specific techniques
    
    // Advanced targeting
    let customFilters: [String: String]? // Key-value pairs for custom targeting
    
    init(
        audience: TargetAudience = .everyone,
        programs: [String]? = nil,
        roles: [String]? = nil,
        studios: [String]? = nil,
        regions: [String]? = nil,
        subscriptionTypes: [SubscriptionType]? = nil,
        userAgeRange: UserAgeRange? = nil,
        trialStatus: TrialStatus? = nil,
        userBehaviors: [UserBehavior]? = nil,
        targetRanks: [String]? = nil,
        targetTechniques: [String]? = nil,
        customFilters: [String: String]? = nil
    ) {
        self.audience = audience
        self.programs = programs
        self.roles = roles
        self.studios = studios
        self.regions = regions
        self.subscriptionTypes = subscriptionTypes
        self.userAgeRange = userAgeRange
        self.trialStatus = trialStatus
        self.userBehaviors = userBehaviors
        self.targetRanks = targetRanks
        self.targetTechniques = targetTechniques
        self.customFilters = customFilters
    }
}

enum TargetAudience: String, Codable, CaseIterable {
    case everyone = "everyone"
    case freeUsers = "free_users"
    case premiumUsers = "premium_users"
    case programs = "programs"
    case roles = "roles"
    case studios = "studios"
    case regions = "regions"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .everyone: return "Everyone"
        case .freeUsers: return "Free Users Only"
        case .premiumUsers: return "Premium Users Only"
        case .programs: return "Specific Programs"
        case .roles: return "Specific Roles"
        case .studios: return "Specific Studios"
        case .regions: return "Specific Regions"
        case .custom: return "Custom Targeting"
        }
    }
}

enum UserAgeRange: String, Codable, CaseIterable {
    case newUsers = "new_users" // Joined within 30 days
    case activeUsers = "active_users" // Logged in within 7 days
    case inactiveUsers = "inactive_users" // Not logged in for 30+ days
    case longTermUsers = "long_term_users" // Joined 6+ months ago
    
    var displayName: String {
        switch self {
        case .newUsers: return "New Users (30 days)"
        case .activeUsers: return "Active Users (7 days)"
        case .inactiveUsers: return "Inactive Users (30+ days)"
        case .longTermUsers: return "Long-term Users (6+ months)"
        }
    }
}

enum TrialStatus: String, Codable, CaseIterable {
    case trialUsers = "trial_users"
    case nonTrialUsers = "non_trial_users"
    case expiredTrialUsers = "expired_trial_users"
    
    var displayName: String {
        switch self {
        case .trialUsers: return "Trial Users"
        case .nonTrialUsers: return "Non-Trial Users"
        case .expiredTrialUsers: return "Expired Trial Users"
        }
    }
}

enum UserBehavior: String, Codable, CaseIterable {
    case journalWriters = "journal_writers"
    case contentCreators = "content_creators"
    case frequentLearners = "frequent_learners"
    case socialUsers = "social_users"
    
    var displayName: String {
        switch self {
        case .journalWriters: return "Journal Writers"
        case .contentCreators: return "Content Creators"
        case .frequentLearners: return "Frequent Learners"
        case .socialUsers: return "Social Users"
        }
    }
}

enum MediaStorageLocation: String, Codable, CaseIterable {
    case userPrivate = "user_private"           // User's iCloud private storage
    case appPublic = "app_public"               // App's public iCloud bucket
    
    var displayName: String {
        switch self {
        case .userPrivate: return "User Private"
        case .appPublic: return "App Public"
        }
    }
} 
