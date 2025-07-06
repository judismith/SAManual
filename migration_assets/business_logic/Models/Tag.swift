import Foundation

struct Tag: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let userId: String // Owner of this tag
    let usageCount: Int
    let lastUsed: Date
    let color: String? // Optional visual customization
    
    init(id: String = UUID().uuidString, name: String, userId: String, usageCount: Int = 1, lastUsed: Date = Date(), color: String? = nil) {
        self.id = id
        self.name = name
        self.userId = userId
        self.usageCount = usageCount
        self.lastUsed = lastUsed
        self.color = color
    }
} 