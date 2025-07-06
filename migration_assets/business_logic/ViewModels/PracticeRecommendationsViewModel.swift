import Foundation
import Combine

@MainActor
class PracticeRecommendationsViewModel: ObservableObject {
    @Published var currentRecommendation: PracticeRecommendation?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let dataService = DataService.shared
    
    func generateRecommendation(
        program: Program,
        enrollment: ProgramEnrollment,
        practiceHistory: [PracticeSession]
    ) async {
        guard !practiceHistory.isEmpty else {
            currentRecommendation = nil
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Analyze practice history to generate recommendations
            let recommendation = await analyzePracticeHistoryAndGenerateRecommendation(
                program: program,
                enrollment: enrollment,
                practiceHistory: practiceHistory
            )
            
            currentRecommendation = recommendation
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func analyzePracticeHistoryAndGenerateRecommendation(
        program: Program,
        enrollment: ProgramEnrollment,
        practiceHistory: [PracticeSession]
    ) async -> PracticeRecommendation {
        
        // Analyze recent practice sessions
        let recentSessions = practiceHistory.prefix(10) // Last 10 sessions
        
        // Find items that need more practice
        let itemsNeedingPractice = findItemsNeedingPractice(from: recentSessions)
        
        // Find difficult items
        let difficultItems = findDifficultItems(from: recentSessions)
        
        // Find low confidence items
        let lowConfidenceItems = findLowConfidenceItems(from: recentSessions)
        
        // Determine focus areas
        let focusAreas = determineFocusAreas(
            itemsNeedingPractice: itemsNeedingPractice,
            difficultItems: difficultItems,
            lowConfidenceItems: lowConfidenceItems
        )
        
        // Generate recommended items
        let recommendedItems = generateRecommendedItems(
            program: program,
            itemsNeedingPractice: itemsNeedingPractice,
            difficultItems: difficultItems,
            lowConfidenceItems: lowConfidenceItems
        )
        
        // Determine session type and duration
        let sessionType = determineSessionType(itemsNeedingPractice: itemsNeedingPractice)
        let sessionDuration = calculateSessionDuration(recommendedItems: recommendedItems)
        
        // Generate reasoning
        let reasoning = generateReasoning(
            itemsNeedingPractice: itemsNeedingPractice,
            difficultItems: difficultItems,
            lowConfidenceItems: lowConfidenceItems
        )
        
        // Generate instructions
        let instructions = generateInstructions(
            sessionType: sessionType,
            recommendedItems: recommendedItems
        )
        
        // Generate tips
        let tips = generateTips(
            focusAreas: focusAreas,
            recommendedItems: recommendedItems
        )
        
        // Generate expected outcomes
        let expectedOutcomes = generateExpectedOutcomes(
            focusAreas: focusAreas,
            recommendedItems: recommendedItems
        )
        
        // Generate success criteria
        let successCriteria = generateSuccessCriteria(
            recommendedItems: recommendedItems,
            focusAreas: focusAreas
        )
        
        return PracticeRecommendation(
            id: UUID().uuidString,
            userId: dataService.currentUser?.uid ?? "",
            programId: program.id,
            rankId: enrollment.currentRank ?? "",
            timestamp: Date(),
            validUntil: Date().addingTimeInterval(7 * 24 * 60 * 60), // 1 week
            focusAreas: focusAreas,
            suggestedSessionDuration: sessionDuration,
            sessionType: sessionType,
            priority: determinePriority(itemsNeedingPractice: itemsNeedingPractice),
            reasoning: reasoning,
            instructions: instructions,
            tips: tips,
            recommendedItems: recommendedItems,
            expectedOutcomes: expectedOutcomes,
            successCriteria: successCriteria
        )
    }
    
    // MARK: - Analysis Methods
    
    private func findItemsNeedingPractice(from sessions: ArraySlice<PracticeSession>) -> [String] {
        var itemsNeedingPractice: Set<String> = []
        
        for session in sessions {
            itemsNeedingPractice.formUnion(session.needsMorePractice)
        }
        
        return Array(itemsNeedingPractice)
    }
    
    private func findDifficultItems(from sessions: ArraySlice<PracticeSession>) -> [String] {
        var difficultItems: Set<String> = []
        
        for session in sessions {
            difficultItems.formUnion(session.difficultyItems)
        }
        
        return Array(difficultItems)
    }
    
    private func findLowConfidenceItems(from sessions: ArraySlice<PracticeSession>) -> [String] {
        var lowConfidenceItems: Set<String> = []
        
        for session in sessions {
            lowConfidenceItems.formUnion(session.lowConfidenceItems)
        }
        
        return Array(lowConfidenceItems)
    }
    
    private func determineFocusAreas(
        itemsNeedingPractice: [String],
        difficultItems: [String],
        lowConfidenceItems: [String]
    ) -> [PracticeFocusArea] {
        var focusAreas: [PracticeFocusArea] = []
        
        // Add technique focus if there are difficult techniques
        if !difficultItems.isEmpty {
            focusAreas.append(PracticeFocusArea(
                id: UUID().uuidString,
                name: "Technique Refinement",
                description: "Focus on improving difficult techniques",
                priority: 4,
                category: .technique
            ))
        }
        
        // Add form focus if there are forms needing practice
        if !itemsNeedingPractice.isEmpty {
            focusAreas.append(PracticeFocusArea(
                id: UUID().uuidString,
                name: "Form Practice",
                description: "Practice forms that need more work",
                priority: 3,
                category: .form
            ))
        }
        
        // Add confidence building if there are low confidence items
        if !lowConfidenceItems.isEmpty {
            focusAreas.append(PracticeFocusArea(
                id: UUID().uuidString,
                name: "Confidence Building",
                description: "Build confidence in techniques",
                priority: 3,
                category: .technique
            ))
        }
        
        return focusAreas
    }
    
    private func generateRecommendedItems(
        program: Program,
        itemsNeedingPractice: [String],
        difficultItems: [String],
        lowConfidenceItems: [String]
    ) -> [RecommendedItem] {
        var recommendedItems: [RecommendedItem] = []
        
        // Add items that need practice
        for itemId in itemsNeedingPractice.prefix(3) {
            if let form = program.forms[itemId] {
                recommendedItems.append(RecommendedItem(
                    id: UUID().uuidString,
                    type: .form,
                    itemId: itemId,
                    name: form.name,
                    reason: "This form needs more practice based on your recent sessions",
                    suggestedTime: 600, // 10 minutes
                    suggestedRepetitions: 5,
                    focusPoints: ["Flow", "Precision", "Memory"],
                    difficulty: 3
                ))
            } else if let technique = program.techniques[itemId] {
                recommendedItems.append(RecommendedItem(
                    id: UUID().uuidString,
                    type: .technique,
                    itemId: itemId,
                    name: technique.name,
                    reason: "This technique needs more practice based on your recent sessions",
                    suggestedTime: 480, // 8 minutes
                    suggestedRepetitions: 10,
                    focusPoints: ["Form", "Power", "Speed"],
                    difficulty: 3
                ))
            }
        }
        
        // Add difficult items
        for itemId in difficultItems.prefix(2) {
            if let form = program.forms[itemId] {
                recommendedItems.append(RecommendedItem(
                    id: UUID().uuidString,
                    type: .form,
                    itemId: itemId,
                    name: form.name,
                    reason: "This form has been challenging for you - focus on breaking it down",
                    suggestedTime: 900, // 15 minutes
                    suggestedRepetitions: 3,
                    focusPoints: ["Break down into sections", "Slow practice", "Precision"],
                    difficulty: 4
                ))
            } else if let technique = program.techniques[itemId] {
                recommendedItems.append(RecommendedItem(
                    id: UUID().uuidString,
                    type: .technique,
                    itemId: itemId,
                    name: technique.name,
                    reason: "This technique has been challenging - focus on fundamentals",
                    suggestedTime: 720, // 12 minutes
                    suggestedRepetitions: 8,
                    focusPoints: ["Fundamentals", "Slow practice", "Form"],
                    difficulty: 4
                ))
            }
        }
        
        return recommendedItems
    }
    
    private func determineSessionType(itemsNeedingPractice: [String]) -> PracticeSessionType {
        if itemsNeedingPractice.count > 3 {
            return .review
        } else if itemsNeedingPractice.count > 1 {
            return .guided
        } else {
            return .solo
        }
    }
    
    private func calculateSessionDuration(recommendedItems: [RecommendedItem]) -> TimeInterval {
        let totalTime = recommendedItems.reduce(0) { $0 + $1.suggestedTime }
        return min(max(totalTime, 900), 3600) // Between 15 minutes and 1 hour
    }
    
    private func determinePriority(itemsNeedingPractice: [String]) -> RecommendationPriority {
        if itemsNeedingPractice.count > 5 {
            return .critical
        } else if itemsNeedingPractice.count > 3 {
            return .high
        } else if itemsNeedingPractice.count > 1 {
            return .medium
        } else {
            return .low
        }
    }
    
    // MARK: - Content Generation Methods
    
    private func generateReasoning(
        itemsNeedingPractice: [String],
        difficultItems: [String],
        lowConfidenceItems: [String]
    ) -> String {
        var reasons: [String] = []
        
        if !itemsNeedingPractice.isEmpty {
            reasons.append("You've marked \(itemsNeedingPractice.count) items as needing more practice")
        }
        
        if !difficultItems.isEmpty {
            reasons.append("Several techniques have been consistently challenging")
        }
        
        if !lowConfidenceItems.isEmpty {
            reasons.append("You've shown low confidence in some areas")
        }
        
        if reasons.isEmpty {
            return "Based on your recent practice patterns, this session will help maintain your progress and build on your strengths."
        }
        
        return "This recommendation is based on: " + reasons.joined(separator: ", ") + "."
    }
    
    private func generateInstructions(
        sessionType: PracticeSessionType,
        recommendedItems: [RecommendedItem]
    ) -> String {
        switch sessionType {
        case .solo:
            return "1. Warm up with basic movements for 5 minutes\n2. Practice each recommended item in order\n3. Focus on quality over quantity\n4. Take breaks between items if needed\n5. Cool down with stretching"
        case .guided:
            return "1. Review the recommended items before starting\n2. Practice with a partner or instructor if possible\n3. Focus on form and technique\n4. Ask for feedback on challenging movements\n5. Record your practice for later review"
        case .review:
            return "1. Start with a comprehensive warm-up\n2. Review all items that need practice\n3. Focus on areas of weakness\n4. Practice transitions between items\n5. End with a thorough cool-down"
        case .testing:
            return "1. Prepare mentally for evaluation\n2. Practice each item to the best of your ability\n3. Focus on demonstrating your skills\n4. Accept feedback constructively\n5. Use this as a learning experience"
        case .warmup:
            return "1. Start with gentle stretching\n2. Gradually increase intensity\n3. Focus on mobility and flexibility\n4. Prepare your body for more intense practice\n5. Listen to your body's signals"
        }
    }
    
    private func generateTips(
        focusAreas: [PracticeFocusArea],
        recommendedItems: [RecommendedItem]
    ) -> [String] {
        var tips: [String] = []
        
        tips.append("Start with the most challenging items when you're fresh")
        tips.append("Take short breaks between items to maintain focus")
        tips.append("Record your practice to track progress over time")
        
        if focusAreas.contains(where: { $0.category == .technique }) {
            tips.append("Focus on proper form rather than speed")
        }
        
        if focusAreas.contains(where: { $0.category == .form }) {
            tips.append("Break down complex forms into smaller sections")
        }
        
        if recommendedItems.count > 3 {
            tips.append("Don't rush - quality practice is more valuable than quantity")
        }
        
        return tips
    }
    
    private func generateExpectedOutcomes(
        focusAreas: [PracticeFocusArea],
        recommendedItems: [RecommendedItem]
    ) -> [String] {
        var outcomes: [String] = []
        
        outcomes.append("Improved confidence in practiced techniques")
        outcomes.append("Better understanding of challenging movements")
        
        if focusAreas.contains(where: { $0.category == .technique }) {
            outcomes.append("Enhanced technical precision")
        }
        
        if focusAreas.contains(where: { $0.category == .form }) {
            outcomes.append("Smoother form execution")
        }
        
        if recommendedItems.count > 2 {
            outcomes.append("Increased endurance and stamina")
        }
        
        return outcomes
    }
    
    private func generateSuccessCriteria(
        recommendedItems: [RecommendedItem],
        focusAreas: [PracticeFocusArea]
    ) -> [String] {
        var criteria: [String] = []
        
        criteria.append("Complete all recommended items with focus")
        criteria.append("Maintain proper form throughout practice")
        criteria.append("Feel more confident in practiced techniques")
        
        if focusAreas.contains(where: { $0.category == .technique }) {
            criteria.append("Demonstrate improved technical precision")
        }
        
        if focusAreas.contains(where: { $0.category == .form }) {
            criteria.append("Execute forms with better flow")
        }
        
        return criteria
    }
} 