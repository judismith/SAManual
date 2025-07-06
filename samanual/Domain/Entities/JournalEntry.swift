import Foundation

// MARK: - Journal Entry Domain Entity
public struct JournalEntry: Identifiable, Equatable {
    public let id: String
    public let userId: String
    public let title: String
    public let content: String
    public let mediaUrls: [String]
    public let techniqueTags: [String]
    public let practiceDate: Date
    public let entryType: JournalEntryType
    public let mood: Mood?
    public let energyLevel: EnergyLevel?
    public let isPrivate: Bool
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        title: String,
        content: String,
        mediaUrls: [String] = [],
        techniqueTags: [String] = [],
        practiceDate: Date = Date(),
        entryType: JournalEntryType = .practice,
        mood: Mood? = nil,
        energyLevel: EnergyLevel? = nil,
        isPrivate: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.content = content
        self.mediaUrls = mediaUrls
        self.techniqueTags = techniqueTags
        self.practiceDate = practiceDate
        self.entryType = entryType
        self.mood = mood
        self.energyLevel = energyLevel
        self.isPrivate = isPrivate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Journal Entry Type Value Object
public enum JournalEntryType: String, Codable, CaseIterable {
    case practice = "practice"
    case reflection = "reflection"
    case goal = "goal"
    case achievement = "achievement"
    case note = "note"
    case question = "question"
    case insight = "insight"
    
    public var displayName: String {
        switch self {
        case .practice: return "Practice"
        case .reflection: return "Reflection"
        case .goal: return "Goal"
        case .achievement: return "Achievement"
        case .note: return "Note"
        case .question: return "Question"
        case .insight: return "Insight"
        }
    }
}

// MARK: - Mood Value Object
public enum Mood: String, Codable, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case neutral = "neutral"
    case tired = "tired"
    case frustrated = "frustrated"
    case stressed = "stressed"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var emoji: String {
        switch self {
        case .excellent: return "😄"
        case .good: return "🙂"
        case .neutral: return "😐"
        case .tired: return "😴"
        case .frustrated: return "😤"
        case .stressed: return "😰"
        }
    }
}

// MARK: - Journal Media Domain Entity
public struct JournalMedia: Identifiable, Equatable {
    public let id: String
    public let entryId: String
    public let url: String
    public let type: MediaType
    public let thumbnailUrl: String?
    public let duration: TimeInterval?
    public let size: Int64?
    public let createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        entryId: String,
        url: String,
        type: MediaType,
        thumbnailUrl: String? = nil,
        duration: TimeInterval? = nil,
        size: Int64? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.entryId = entryId
        self.url = url
        self.type = type
        self.thumbnailUrl = thumbnailUrl
        self.duration = duration
        self.size = size
        self.createdAt = createdAt
    }
}

// MARK: - Media Type Value Object
public enum MediaType: String, Codable, CaseIterable {
    case image = "image"
    case video = "video"
    case audio = "audio"
    case document = "document"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var fileExtensions: [String] {
        switch self {
        case .image:
            return ["jpg", "jpeg", "png", "heic", "gif"]
        case .video:
            return ["mp4", "mov", "avi", "m4v"]
        case .audio:
            return ["mp3", "m4a", "wav", "aac"]
        case .document:
            return ["pdf", "doc", "docx", "txt"]
        }
    }
}

// MARK: - Journal Tag Domain Entity
public struct JournalTag: Identifiable, Equatable {
    public let id: String
    public let userId: String
    public let name: String
    public let color: String?
    public let category: TagCategory
    public let usageCount: Int
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        color: String? = nil,
        category: TagCategory = .technique,
        usageCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.color = color
        self.category = category
        self.usageCount = usageCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Tag Category Value Object
public enum TagCategory: String, Codable, CaseIterable {
    case technique = "technique"
    case form = "form"
    case concept = "concept"
    case goal = "goal"
    case achievement = "achievement"
    case personal = "personal"
    
    public var displayName: String {
        return rawValue.capitalized
    }
} 