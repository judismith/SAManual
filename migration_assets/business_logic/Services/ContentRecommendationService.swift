import Foundation

class ContentRecommendationService: ObservableObject {
    private let firestoreService: FirestoreService
    private let dataService: DataService
    
    @Published var currentRecommendations: [ContentRecommendation] = []
    @Published var isLoading: Bool = false
    
    init(firestoreService: FirestoreService, dataService: DataService) {
        self.firestoreService = firestoreService
        self.dataService = dataService
    }
    
    // MARK: - Public Methods
    
    func generateRecommendations(for profile: UserProfile) async {
        await MainActor.run {
            self.isLoading = true
        }
        
        var allRecommendations: [ContentRecommendation] = []
        
        // Generate recommendations for each enrolled program
        for (programId, enrollment) in profile.programs {
            if enrollment.enrolled {
                let programRecommendations = await generateRecommendations(for: profile.id, programId: programId)
                allRecommendations.append(contentsOf: programRecommendations)
            }
        }
        
        // Update the published property on the main thread
        await MainActor.run {
            self.currentRecommendations = allRecommendations
            self.isLoading = false
        }
    }
    
    func generateRecommendations(for userId: String, programId: String) async -> [ContentRecommendation] {
        do {
            // Fetch user's current progress and practice history
            let userProgress = try await fetchUserProgress(userId: userId, programId: programId)
            let practiceHistory = try await fetchPracticeHistory(userId: userId, programId: programId)
            let program = await fetchProgram(withId: programId)
            
            guard let program = program else {
                print("Program not found for ID: \(programId)")
                return []
            }
            
            // Generate recommendations based on progress and history
            var recommendations: [ContentRecommendation] = []
            
            // 1. Next Steps - What should be learned next
            if let nextStepsRecommendation = generateNextStepsRecommendation(
                userProgress: userProgress,
                program: program
            ) {
                recommendations.append(nextStepsRecommendation)
            }
            
            // 2. Practice - Items that need more practice
            let practiceRecommendations = generatePracticeRecommendations(
                userProgress: userProgress,
                practiceHistory: practiceHistory,
                program: program
            )
            recommendations.append(contentsOf: practiceRecommendations)
            
            // 3. Review - Items to review for retention
            let reviewRecommendations = generateReviewRecommendations(
                userProgress: userProgress,
                practiceHistory: practiceHistory,
                program: program
            )
            recommendations.append(contentsOf: reviewRecommendations)
            
            // 4. Challenge - Advanced items for growth
            let challengeRecommendations = generateChallengeRecommendations(
                userProgress: userProgress,
                program: program
            )
            recommendations.append(contentsOf: challengeRecommendations)
            
            // Sort by priority and return
            return sortRecommendations(recommendations)
            
        } catch {
            print("Error generating recommendations: \(error)")
            return []
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchUserProgress(userId: String, programId: String) async throws -> RankProgress? {
        // This would typically fetch from your data service
        // For now, return nil to avoid compilation issues
        return nil
    }
    
    private func fetchPracticeHistory(userId: String, programId: String) async throws -> [PracticeSession] {
        // This would typically fetch from your data service
        // For now, return empty array
        return []
    }
    
    private func fetchProgram(withId programId: String) async -> Program? {
        do {
            return try await dataService.fetchProgram(withId: programId)
        } catch {
            print("Error fetching program: \(error)")
            return nil
        }
    }
    
    // MARK: - Recommendation Generation
    
    private func generateNextStepsRecommendation(
        userProgress: RankProgress?,
        program: Program
    ) -> ContentRecommendation? {
        guard !program.ranks.isEmpty else { return nil }
        
        // Find the first rank to work towards (ranks are already ordered by order property)
        let sortedRanks = program.ranks.sorted { $0.order < $1.order }
        guard let firstRank = sortedRanks.first else { return nil }
        
        let rank = firstRank
        let rankId = firstRank.id
        
        // Find the first form or technique in the rank from curriculum
        let rankCurriculum = program.curriculum.filter { $0.rankId == rankId }
        let sortedCurriculum = rankCurriculum.sorted { $0.order < $1.order }
        
        // Look for first form
        if let firstForm = sortedCurriculum.first(where: { $0.type == .form }) {
            return ContentRecommendation(
                id: "next_form_\(firstForm.id)",
                title: "Learn \(firstForm.name)",
                description: "Start learning the next form in your progression",
                reason: "You're ready to advance to the next rank. This form will help you build on your current skills.",
                type: .nextSteps,
                priority: .high,
                estimatedTime: 15 * 60, // 15 minutes
                focusAreas: ["form", "technique", "balance"],
                tips: [
                    "Take your time with each movement",
                    "Focus on proper breathing",
                    "Practice in front of a mirror"
                ],
                itemId: firstForm.id,
                itemType: .form,
                programId: program.id,
                rankId: rankId
            )
        } else if let firstTechnique = sortedCurriculum.first(where: { $0.type == .technique }) {
            return ContentRecommendation(
                id: "next_technique_\(firstTechnique.id)",
                title: "Learn \(firstTechnique.name)",
                description: "Master the next technique in your progression",
                reason: "This technique builds upon your current foundation and prepares you for advanced movements.",
                type: .nextSteps,
                priority: .high,
                estimatedTime: 10 * 60, // 10 minutes
                focusAreas: ["technique", "power", "precision"],
                tips: [
                    "Start slowly and build speed",
                    "Focus on proper stance",
                    "Practice both sides equally"
                ],
                itemId: firstTechnique.id,
                itemType: .technique,
                programId: program.id,
                rankId: rankId
            )
        }
        
        return nil
    }
    
    private func generatePracticeRecommendations(
        userProgress: RankProgress?,
        practiceHistory: [PracticeSession],
        program: Program
    ) -> [ContentRecommendation] {
        var recommendations: [ContentRecommendation] = []
        
        guard !program.ranks.isEmpty else { return recommendations }
        
        // Find items that need more practice based on practice history
        let itemsNeedingPractice = getItemsNeedingPractice(from: practiceHistory)
        let difficultItems = getDifficultItems(from: practiceHistory)
        
        // Generate practice recommendations for forms
        for rank in program.ranks {
            let formsInRank = program.curriculum.filter { $0.rankId == rank.id && $0.type == .form }
            for form in formsInRank {
                if itemsNeedingPractice.contains(form.id) || difficultItems.contains(form.id) {
                    let recommendation = ContentRecommendation(
                        id: "practice_form_\(form.id)",
                        title: "Practice \(form.name)",
                        description: "Focus on improving your form and technique",
                        reason: "This form needs more practice to master the movements and build muscle memory.",
                        type: .practice,
                        priority: .medium,
                        estimatedTime: 20 * 60, // 20 minutes
                        focusAreas: ["form", "technique", "flow"],
                        tips: [
                            "Break down complex movements",
                            "Practice transitions between moves",
                            "Record yourself to check form"
                        ],
                        itemId: form.id,
                        itemType: .form,
                        programId: program.id,
                        rankId: rank.id
                    )
                    recommendations.append(recommendation)
                }
            }
            
            // Generate practice recommendations for techniques
            let techniquesInRank = program.curriculum.filter { $0.rankId == rank.id && $0.type == .technique }
            for technique in techniquesInRank {
                if itemsNeedingPractice.contains(technique.id) || difficultItems.contains(technique.id) {
                    let recommendation = ContentRecommendation(
                        id: "practice_technique_\(technique.id)",
                        title: "Practice \(technique.name)",
                        description: "Refine your technique and build strength",
                        reason: "This technique requires more practice to develop proper form and power.",
                        type: .practice,
                        priority: .medium,
                        estimatedTime: 15 * 60, // 15 minutes
                        focusAreas: ["technique", "power", "speed"],
                        tips: [
                            "Focus on proper breathing",
                            "Build up repetitions gradually",
                            "Maintain good posture throughout"
                        ],
                        itemId: technique.id,
                        itemType: .technique,
                        programId: program.id,
                        rankId: rank.id
                    )
                    recommendations.append(recommendation)
                }
            }
        }
        
        return recommendations
    }
    
    private func generateReviewRecommendations(
        userProgress: RankProgress?,
        practiceHistory: [PracticeSession],
        program: Program
    ) -> [ContentRecommendation] {
        var recommendations: [ContentRecommendation] = []
        
        guard !program.ranks.isEmpty else { return recommendations }
        
        // Find items that haven't been practiced recently
        let recentlyPracticedItems = getRecentlyPracticedItems(from: practiceHistory, days: 7)
        
        // Generate review recommendations for forms
        for rank in program.ranks {
            let formsInRank = program.curriculum.filter { $0.rankId == rank.id && $0.type == .form }
            for form in formsInRank {
                if !recentlyPracticedItems.contains(form.id) {
                    let recommendation = ContentRecommendation(
                        id: "review_form_\(form.id)",
                        title: "Review \(form.name)",
                        description: "Refresh your memory and maintain skills",
                        reason: "It's been a while since you practiced this form. Regular review helps maintain your skills.",
                        type: .review,
                        priority: .low,
                        estimatedTime: 10 * 60, // 10 minutes
                        focusAreas: ["form", "memory", "flow"],
                        tips: [
                            "Go through the form slowly first",
                            "Focus on smooth transitions",
                            "Remember the key principles"
                        ],
                        itemId: form.id,
                        itemType: .form,
                        programId: program.id,
                        rankId: rank.id
                    )
                    recommendations.append(recommendation)
                }
            }
        }
        
        return recommendations
    }
    
    private func generateChallengeRecommendations(
        userProgress: RankProgress?,
        program: Program
    ) -> [ContentRecommendation] {
        var recommendations: [ContentRecommendation] = []
        
        guard !program.ranks.isEmpty else { return recommendations }
        
        // Find advanced items in the first rank that can provide a challenge
        let sortedRanks = program.ranks.sorted { $0.order < $1.order }
        guard let firstRank = sortedRanks.first else { return recommendations }
        
        let rank = firstRank
        let rankId = firstRank.id
        
        // Look for complex forms or techniques that provide a challenge
        let complexForms = program.curriculum.filter { $0.rankId == rankId && $0.type == .form }.prefix(2)
        let complexTechniques = program.curriculum.filter { $0.rankId == rankId && $0.type == .technique }.prefix(2)
        
        for form in complexForms {
                let recommendation = ContentRecommendation(
                    id: "challenge_form_\(form.id)",
                    title: "Challenge: \(form.name)",
                    description: "Push your limits with this advanced form",
                    reason: "This complex form will challenge your skills and help you grow beyond your current level.",
                    type: .challenge,
                    priority: .medium,
                    estimatedTime: 25 * 60, // 25 minutes
                    focusAreas: ["form", "endurance", "precision"],
                    tips: [
                        "Take breaks if needed",
                        "Focus on quality over speed",
                        "Don't get discouraged by mistakes"
                    ],
                    itemId: form.id,
                    itemType: .form,
                    programId: program.id,
                    rankId: rankId
                )
                recommendations.append(recommendation)
        }
        
        for technique in complexTechniques {
            let recommendation = ContentRecommendation(
                    id: "challenge_technique_\(technique.id)",
                    title: "Challenge: \(technique.name)",
                    description: "Master this advanced technique",
                    reason: "This challenging technique will test your skills and help you advance to the next level.",
                    type: .challenge,
                    priority: .medium,
                    estimatedTime: 20 * 60, // 20 minutes
                    focusAreas: ["technique", "power", "control"],
                    tips: [
                        "Start with basic variations",
                        "Build up to full complexity",
                        "Focus on proper form throughout"
                    ],
                    itemId: technique.id,
                    itemType: .technique,
                    programId: program.id,
                    rankId: rankId
                )
                recommendations.append(recommendation)
        }
        
        return recommendations
    }
    
    // MARK: - Helper Methods
    
    private func getItemsNeedingPractice(from practiceHistory: [PracticeSession]) -> [String] {
        var itemsNeedingPractice: Set<String> = []
        
        for session in practiceHistory {
            // Simplified: check session data for items that need more practice
            itemsNeedingPractice.insert(session.id)
        }
        
        return Array(itemsNeedingPractice)
    }
    
    private func getDifficultItems(from practiceHistory: [PracticeSession]) -> [String] {
        var difficultItems: Set<String> = []
        
        for session in practiceHistory {
            // Simplified: check session data for difficult items
            difficultItems.insert(session.id)
        }
        
        return Array(difficultItems)
    }
    
    private func getRecentlyPracticedItems(from practiceHistory: [PracticeSession], days: Int) -> [String] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        var recentlyPracticed: Set<String> = []
        
        for session in practiceHistory {
            if session.startTime >= cutoffDate {
                recentlyPracticed.insert(session.id)
            }
        }
        
        return Array(recentlyPracticed)
    }
    
    private func sortRecommendations(_ recommendations: [ContentRecommendation]) -> [ContentRecommendation] {
        return recommendations.sorted { first, second in
            // Sort by priority first (high to low)
            let priorityOrder: [RecommendationPriority] = [.high, .medium, .low]
            let firstPriorityIndex = priorityOrder.firstIndex(of: first.priority) ?? 0
            let secondPriorityIndex = priorityOrder.firstIndex(of: second.priority) ?? 0
            
            if firstPriorityIndex != secondPriorityIndex {
                return firstPriorityIndex < secondPriorityIndex
            }
            
            // Then sort by type (next steps first, then practice, review, challenge)
            let typeOrder: [RecommendationType] = [.nextSteps, .practice, .review, .challenge]
            let firstTypeIndex = typeOrder.firstIndex(of: first.type) ?? 0
            let secondTypeIndex = typeOrder.firstIndex(of: second.type) ?? 0
            
            return firstTypeIndex < secondTypeIndex
        }
    }
    
    func getNextStepsRecommendations() -> [ContentRecommendation] {
        return currentRecommendations.filter { $0.type == .nextSteps }
    }
}

// MARK: - Models

struct ContentRecommendation: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let reason: String
    let type: RecommendationType
    let priority: RecommendationPriority
    let estimatedTime: TimeInterval
    let focusAreas: [String]
    let tips: [String]
    let itemId: String
    let itemType: ContentType
    let programId: String
    let rankId: String
}

enum RecommendationType: String, Codable, CaseIterable {
    case nextSteps = "next_steps"
    case practice = "practice"
    case review = "review"
    case challenge = "challenge"
    
    var displayName: String {
        switch self {
        case .nextSteps: return "Next Steps"
        case .practice: return "Practice"
        case .review: return "Review"
        case .challenge: return "Challenge"
        }
    }
    
    var icon: String {
        switch self {
        case .nextSteps: return "arrow.up.circle.fill"
        case .practice: return "figure.martial.arts"
        case .review: return "book.fill"
        case .challenge: return "flame.fill"
        }
    }
    
    var color: String {
        switch self {
        case .nextSteps: return "AppPrimaryColor"
        case .practice: return "AppSecondaryColor"
        case .review: return "TextSecondary"
        case .challenge: return "BrandAccent"
        }
    }
}