import Foundation

// MARK: - Practice Session Domain Entity
public struct PracticeSession: Identifiable, Equatable {
    public let id: String
    public let userId: String
    public let programId: String
    public let sessionType: SessionType
    public let duration: TimeInterval
    public let techniques: [String]
    public let notes: String?
    public let metrics: PracticeMetrics
    public let startDate: Date
    public let endDate: Date?
    public let status: SessionStatus
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        programId: String,
        sessionType: SessionType,
        duration: TimeInterval = 0,
        techniques: [String] = [],
        notes: String? = nil,
        metrics: PracticeMetrics = PracticeMetrics(),
        startDate: Date = Date(),
        endDate: Date? = nil,
        status: SessionStatus = .active,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.programId = programId
        self.sessionType = sessionType
        self.duration = duration
        self.techniques = techniques
        self.notes = notes
        self.metrics = metrics
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Session Type Value Object
public enum SessionType: String, Codable, CaseIterable {
    case solo = "solo"
    case guided = "guided"
    case group = "group"
    case assessment = "assessment"
    case review = "review"
    case warmup = "warmup"
    case cooldown = "cooldown"
    
    public var displayName: String {
        switch self {
        case .solo: return "Solo Practice"
        case .guided: return "Guided Practice"
        case .group: return "Group Practice"
        case .assessment: return "Assessment"
        case .review: return "Review"
        case .warmup: return "Warm-up"
        case .cooldown: return "Cool-down"
        }
    }
}

// MARK: - Session Status Value Object
public enum SessionStatus: String, Codable, CaseIterable {
    case active = "active"
    case paused = "paused"
    case completed = "completed"
    case cancelled = "cancelled"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Practice Metrics Value Object
public struct PracticeMetrics: Codable, Equatable {
    public let totalTechniques: Int
    public let techniquesCompleted: Int
    public let averageAccuracy: Double
    public let totalRepetitions: Int
    public let focusScore: Double
    public let energyLevel: EnergyLevel
    public let difficultyRating: Int
    public let satisfactionRating: Int
    
    public init(
        totalTechniques: Int = 0,
        techniquesCompleted: Int = 0,
        averageAccuracy: Double = 0.0,
        totalRepetitions: Int = 0,
        focusScore: Double = 0.0,
        energyLevel: EnergyLevel = .medium,
        difficultyRating: Int = 3,
        satisfactionRating: Int = 3
    ) {
        self.totalTechniques = totalTechniques
        self.techniquesCompleted = techniquesCompleted
        self.averageAccuracy = averageAccuracy
        self.totalRepetitions = totalRepetitions
        self.focusScore = focusScore
        self.energyLevel = energyLevel
        self.difficultyRating = difficultyRating
        self.satisfactionRating = satisfactionRating
    }
    
    public var completionRate: Double {
        guard totalTechniques > 0 else { return 0.0 }
        return Double(techniquesCompleted) / Double(totalTechniques)
    }
}

// MARK: - Energy Level Value Object
public enum EnergyLevel: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var value: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }
}

// MARK: - Practice Item Domain Entity
public struct PracticeItem: Identifiable, Equatable {
    public let id: String
    public let sessionId: String
    public let techniqueId: String
    public let order: Int
    public let duration: TimeInterval
    public let repetitions: Int
    public let accuracy: Double
    public let notes: String?
    public let completed: Bool
    public let completedAt: Date?
    
    public init(
        id: String = UUID().uuidString,
        sessionId: String,
        techniqueId: String,
        order: Int,
        duration: TimeInterval = 0,
        repetitions: Int = 0,
        accuracy: Double = 0.0,
        notes: String? = nil,
        completed: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.techniqueId = techniqueId
        self.order = order
        self.duration = duration
        self.repetitions = repetitions
        self.accuracy = accuracy
        self.notes = notes
        self.completed = completed
        self.completedAt = completedAt
    }
}

// MARK: - Session Rating Value Object
public struct SessionRating: Identifiable, Codable, Equatable {
    public let id: String
    public let sessionId: String
    public let userId: String
    public let overallRating: Int
    public let difficultyRating: Int
    public let enjoymentRating: Int
    public let learningValueRating: Int
    public let comments: String?
    public let createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        sessionId: String,
        userId: String,
        overallRating: Int,
        difficultyRating: Int,
        enjoymentRating: Int,
        learningValueRating: Int,
        comments: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.userId = userId
        self.overallRating = overallRating
        self.difficultyRating = difficultyRating
        self.enjoymentRating = enjoymentRating
        self.learningValueRating = learningValueRating
        self.comments = comments
        self.createdAt = createdAt
    }
    
    public var averageRating: Double {
        return Double(overallRating + difficultyRating + enjoymentRating + learningValueRating) / 4.0
    }
} 