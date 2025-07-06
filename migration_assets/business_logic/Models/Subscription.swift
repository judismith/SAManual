import Foundation

struct LegacySubscription: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let includesPrograms: [String]
    let includesRanks: [String]?
    let includesTags: [String]
    let priceMonthly: Double
    let priceAnnually: Double
    let isPublic: Bool
} 