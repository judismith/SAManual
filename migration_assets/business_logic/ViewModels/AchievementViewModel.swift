import Foundation
import Combine
import SwiftUI

@MainActor
class AchievementViewModel: ObservableObject {
    private let achievementService = AchievementService()
    private var cancellables = Set<AnyCancellable>()
    
    @Published var achievements: [UserAchievement] = []
    @Published var filteredAchievements: [UserAchievement] = []
    @Published var searchText = ""
    @Published var selectedCategory: AchievementCategory? = nil
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        setupBindings()
        loadAchievements()
    }
    
    private func setupBindings() {
        // Bind to achievement service
        achievementService.$userAchievements
            .assign(to: \.achievements, on: self)
            .store(in: &cancellables)
        
        achievementService.$isLoading
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        achievementService.$errorMessage
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        // Filter achievements when search text or category changes
        Publishers.CombineLatest3($achievements, $searchText, $selectedCategory)
            .map { [weak self] achievements, searchText, category in
                self?.filterAchievements(achievements: achievements, searchText: searchText, category: category) ?? []
            }
            .assign(to: \.filteredAchievements, on: self)
            .store(in: &cancellables)
    }
    
    private func filterAchievements(achievements: [UserAchievement], searchText: String, category: AchievementCategory?) -> [UserAchievement] {
        var filtered = achievements
        
        // Filter by category
        if let category = category {
            filtered = filtered.filter { $0.category == category.rawValue }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { achievement in
                let searchText = searchText.lowercased()
                return achievement.title?.localizedCaseInsensitiveContains(searchText) == true ||
                       achievement.achievementDescription?.localizedCaseInsensitiveContains(searchText) == true ||
                       achievement.category?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        return filtered
    }
    
    func loadAchievements() {
        achievementService.loadUserAchievements()
    }
    
    func unlockAchievement(achievementId: String) {
        achievementService.unlockAchievement(achievementId: achievementId)
    }
    
    func getRecentAchievements() -> [UserAchievement] {
        return achievementService.getRecentAchievements()
    }
    
    func getUnlockedAchievements() -> [UserAchievement] {
        return achievementService.getUnlockedAchievements()
    }
    
    func getLockedAchievements() -> [UserAchievement] {
        return achievementService.getLockedAchievements()
    }
    
    func getAchievementsByCategory(_ category: AchievementCategory) -> [UserAchievement] {
        return achievementService.getAchievementsByCategory(category)
    }
    
    func checkPracticeAchievements(practiceSession: PracticeSession) {
        achievementService.checkPracticeAchievements(practiceSession: practiceSession)
    }
    
    func checkProgressAchievements(progress: RankProgressData) {
        achievementService.checkProgressAchievements(progress: progress)
    }
    
    func showAchievementDetail(_ achievement: UserAchievement) {
        // TODO: Implement achievement detail view navigation
        print("Showing achievement detail for: \(achievement.title ?? "")")
    }
}

// MARK: - Supporting Types

enum AchievementSortOption: String, CaseIterable {
    case dateUnlocked = "Date Unlocked"
    case alphabetical = "Alphabetical"
    case category = "Category"
}

enum SortOrder: String, CaseIterable {
    case dateUnlocked = "dateUnlocked"
    case alphabetical = "alphabetical"
    case category = "category"
    
    var displayName: String {
        switch self {
        case .dateUnlocked:
            return "Date Unlocked"
        case .alphabetical:
            return "Alphabetical"
        case .category:
            return "Category"
        }
    }
}

// MARK: - Achievement Progress

struct AchievementProgress {
    let currentRank: Rank?
    let completedForms: [Form]
    let completedTechniques: [Technique]
    let totalForms: Int
    let totalTechniques: Int
    
    init(currentRank: Rank?, completedForms: [Form], completedTechniques: [Technique], totalForms: Int, totalTechniques: Int) {
        self.currentRank = currentRank
        self.completedForms = completedForms
        self.completedTechniques = completedTechniques
        self.totalForms = totalForms
        self.totalTechniques = totalTechniques
    }
    
    // MARK: - Computed Properties
    
    var formsCompletionPercentage: Double {
        guard totalForms > 0 else { return 0 }
        return Double(completedForms.count) / Double(totalForms) * 100
    }
    
    var techniquesCompletionPercentage: Double {
        guard totalTechniques > 0 else { return 0 }
        return Double(completedTechniques.count) / Double(totalTechniques) * 100
    }
    
    var overallProgressPercentage: Double {
        let formsWeight = 0.4 // Forms are weighted more heavily
        let techniquesWeight = 0.6
        
        return (formsCompletionPercentage * formsWeight) + (techniquesCompletionPercentage * techniquesWeight)
    }
} 