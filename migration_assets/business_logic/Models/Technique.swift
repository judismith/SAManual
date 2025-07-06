import Foundation

struct Technique: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let mediaUrl: String
    let number: String
    let requiredRankId: String
    let prerequisites: [String]
    let tags: [String]
}

struct TechniqueAnalytics: Codable, Equatable {
    let journalReferenceCount: Int
    let viewCount: Int
    let lastReferencedAt: Date?
    let practiceCount: Int
    
    init(journalReferenceCount: Int = 0, viewCount: Int = 0, lastReferencedAt: Date? = nil, practiceCount: Int = 0) {
        self.journalReferenceCount = journalReferenceCount
        self.viewCount = viewCount
        self.lastReferencedAt = lastReferencedAt
        self.practiceCount = practiceCount
    }
} 