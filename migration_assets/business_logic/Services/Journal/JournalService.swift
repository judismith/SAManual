import Foundation
import Combine

// MARK: - Journal Service Protocol
public protocol JournalService: AnyObject {
    
    // MARK: - Publishers
    var journalUpdatesPublisher: AnyPublisher<JournalEntry, Never> { get }
    
    // MARK: - Entry Management
    func getEntries(for userId: String) async throws -> [JournalEntry]
    func getEntry(id: String) async throws -> JournalEntry?
    func saveEntry(_ entry: JournalEntry) async throws -> JournalEntry
    func updateEntry(_ entry: JournalEntry) async throws -> JournalEntry
    func deleteEntry(id: String) async throws
    
    // MARK: - Search and Filter
    func searchEntries(for userId: String, query: String) async throws -> [JournalEntry]
    func getEntriesForContent(userId: String, contentId: String, contentType: ContentType) async throws -> [JournalEntry]
    func getEntriesInDateRange(for userId: String, from: Date, to: Date) async throws -> [JournalEntry]
    
    // MARK: - Analytics
    func getEntryCount(for userId: String) async throws -> Int
    func getAverageDifficultyRating(for userId: String) async throws -> Double
    func getEntriesNeedingPractice(for userId: String) async throws -> [JournalEntry]
}

// MARK: - Journal Entry Models
public struct JournalEntry: Identifiable, Codable, Equatable {
    public let id: String
    public let userId: String
    public let timestamp: Date
    public let content: String
    public let difficultyRating: Int // 1-5 scale
    public let needsPractice: Bool
    public let referencedContent: [ContentReference]
    public let mood: JournalMood?
    public let tags: [String]
    public let attachments: [JournalAttachment]
    public let metadata: [String: String]
    
    // MARK: - Legacy Compatibility Properties
    public var mediaUrls: [String] {
        return attachments.compactMap { attachment in
            switch attachment {
            case .image(let url), .video(let url), .audio(let url):
                return url.absoluteString
            }
        }
    }
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        timestamp: Date = Date(),
        content: String,
        difficultyRating: Int,
        needsPractice: Bool,
        referencedContent: [ContentReference] = [],
        mood: JournalMood? = nil,
        tags: [String] = [],
        attachments: [JournalAttachment] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.userId = userId
        self.timestamp = timestamp
        self.content = content
        self.difficultyRating = difficultyRating
        self.needsPractice = needsPractice
        self.referencedContent = referencedContent
        self.mood = mood
        self.tags = tags
        self.attachments = attachments
        self.metadata = metadata
    }
}

public struct ContentReference: Identifiable, Codable, Equatable {
    public let id: String
    public let type: ContentType
    public let cachedName: String?
    public let cachedRank: String?
    public let cachedDescription: String?
    public let isSubscriptionRequired: Bool
    public let referencedAt: Date
    
    public init(
        id: String,
        type: ContentType,
        cachedName: String? = nil,
        cachedRank: String? = nil,
        cachedDescription: String? = nil,
        isSubscriptionRequired: Bool = false,
        referencedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.cachedName = cachedName
        self.cachedRank = cachedRank
        self.cachedDescription = cachedDescription
        self.isSubscriptionRequired = isSubscriptionRequired
        self.referencedAt = referencedAt
    }
}

public enum JournalMood: String, CaseIterable, Codable {
    case excited = "excited"
    case confident = "confident"
    case focused = "focused"
    case frustrated = "frustrated"
    case tired = "tired"
    case challenged = "challenged"
    case accomplished = "accomplished"
    
    public var emoji: String {
        switch self {
        case .excited: return "🤩"
        case .confident: return "😤"
        case .focused: return "🧘"
        case .frustrated: return "😤"
        case .tired: return "😴"
        case .challenged: return "🤔"
        case .accomplished: return "🎉"
        }
    }
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

public struct JournalAttachment: Identifiable, Codable, Equatable {
    public let id: String
    public let type: AttachmentType
    public let filename: String
    public let url: URL?
    public let size: Int64
    public let uploadedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        type: AttachmentType,
        filename: String,
        url: URL? = nil,
        size: Int64,
        uploadedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.filename = filename
        self.url = url
        self.size = size
        self.uploadedAt = uploadedAt
    }
}

public enum AttachmentType: String, CaseIterable, Codable {
    case image = "image"
    case video = "video"
    case audio = "audio"
    case document = "document"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var icon: String {
        switch self {
        case .image: return "photo"
        case .video: return "video"
        case .audio: return "waveform"
        case .document: return "doc"
        }
    }
}

// MARK: - Journal Service Errors
public enum JournalServiceError: Error, LocalizedError {
    case entryNotFound(id: String)
    case invalidEntry(reason: String)
    case unauthorized(userId: String)
    case storageError(underlying: Error)
    case networkError(underlying: Error)
    case validationError(field: String, reason: String)
    
    public var errorDescription: String? {
        switch self {
        case .entryNotFound(let id):
            return "Journal entry with ID '\(id)' not found"
        case .invalidEntry(let reason):
            return "Invalid journal entry: \(reason)"
        case .unauthorized(let userId):
            return "User '\(userId)' is not authorized to access this journal entry"
        case .storageError(let error):
            return "Storage error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .validationError(let field, let reason):
            return "Validation error in field '\(field)': \(reason)"
        }
    }
}

// MARK: - Analytics Models
public struct ContentAnalytics: Identifiable, Codable, Equatable {
    public let id: String
    public let contentId: String
    public let contentType: ContentType
    public let eventType: String // "reference" or "view"
    public let timestamp: Date
    
    public init(id: String = UUID().uuidString, contentId: String, contentType: ContentType, eventType: String, timestamp: Date = Date()) {
        self.id = id
        self.contentId = contentId
        self.contentType = contentType
        self.eventType = eventType
        self.timestamp = timestamp
    }
}