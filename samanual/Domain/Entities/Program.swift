import Foundation

// MARK: - Program Domain Entity
public struct Program: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let description: String
    public let type: ProgramType
    public let isActive: Bool
    public let instructorIds: [String]
    public let ranks: [Rank]
    public let curriculum: [CurriculumItem]
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String,
        name: String,
        description: String,
        type: ProgramType,
        isActive: Bool = true,
        instructorIds: [String] = [],
        ranks: [Rank] = [],
        curriculum: [CurriculumItem] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.isActive = isActive
        self.instructorIds = instructorIds
        self.ranks = ranks
        self.curriculum = curriculum
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Program Type Value Object
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

// MARK: - Rank Value Object
public struct Rank: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let level: Int
    public let color: String?
    public let requirements: [String]
    public let estimatedTimeToAchieve: TimeInterval?
    public let isActive: Bool
    
    public init(
        id: String,
        name: String,
        level: Int,
        color: String? = nil,
        requirements: [String] = [],
        estimatedTimeToAchieve: TimeInterval? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.level = level
        self.color = color
        self.requirements = requirements
        self.estimatedTimeToAchieve = estimatedTimeToAchieve
        self.isActive = isActive
    }
}

// MARK: - Curriculum Item Domain Entity
public struct CurriculumItem: Identifiable, Equatable {
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
    public let updatedAt: Date
    
    public init(
        id: String,
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
        difficulty: DifficultyLevel = .beginner,
        prerequisites: [String] = [],
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Curriculum Item Type Value Object
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

// MARK: - Difficulty Level Value Object
public enum DifficultyLevel: String, Codable, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var level: Int {
        switch self {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        case .expert: return 4
        }
    }
} 