import Foundation
import Combine
import CoreData
import CloudKit
import SwiftUI

@MainActor
class AchievementService: ObservableObject {
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var userAchievements: [UserAchievement] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        setupObservers()
        loadUserAchievements()
    }
    
    // MARK: - Setup and Observers
    
    private func setupObservers() {
        // Observe Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                self?.loadUserAchievements()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Achievement Loading
    
    func loadUserAchievements() {
        guard let userId = getCurrentUserId() else {
            print("⚠️ [AchievementService] No current user ID")
            return
        }
        
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<UserAchievement> = UserAchievement.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \UserAchievement.unlockedDate, ascending: false)]
        
        do {
            let achievements = try context.fetch(request)
            self.userAchievements = achievements
            print("✅ [AchievementService] Loaded \(achievements.count) achievements from Core Data")
        } catch {
            print("❌ [AchievementService] Error loading achievements: \(error)")
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Achievement Management
    
    /// Unlock an achievement for the current user
    func unlockAchievement(achievementId: String) {
        guard let userId = getCurrentUserId() else {
            print("❌ [AchievementService] No current user ID")
            return
        }
        
        // Check if achievement already exists
        if let existingAchievement = userAchievements.first(where: { $0.achievementId == achievementId }) {
            if existingAchievement.isUnlocked {
                print("ℹ️ [AchievementService] Achievement already unlocked: \(achievementId)")
                return
            }
        }
        
        // Get achievement definition
        guard let definition = getAchievementDefinition(achievementId) else {
            print("❌ [AchievementService] Achievement definition not found: \(achievementId)")
            return
        }
        
        let context = persistenceController.container.viewContext
        
        // Create or update achievement
        let achievement: UserAchievement
        if let existingAchievement = userAchievements.first(where: { $0.achievementId == achievementId }) {
            achievement = existingAchievement
        } else {
            achievement = UserAchievement(context: context)
            achievement.achievementId = achievementId
            achievement.userId = userId
            achievement.createdAt = Date()
        }
        
        // Update achievement data
        achievement.title = definition.title
        achievement.achievementDescription = definition.description
        achievement.icon = definition.icon
        achievement.colorHex = definition.colorHex
        achievement.category = definition.category.rawValue
        achievement.isUnlocked = true
        achievement.unlockedDate = Date()
        
        // Save to Core Data
        do {
            try context.save()
            print("✅ [AchievementService] Achievement unlocked: \(definition.title)")
            
            // Trigger UI update
            loadUserAchievements()
            
            // TODO: Show notification/animation
        } catch {
            print("❌ [AchievementService] Error saving achievement: \(error)")
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Achievement Checking Logic
    
    /// Check for practice-based achievements
    func checkPracticeAchievements(practiceSession: PracticeSession) {
        // Check first practice
        checkFirstPracticeAchievement()
        
        // TODO: Implement other practice-based checks
        // checkDailyStreakAchievement()
        // checkWeeklyStreakAchievement()
        // checkTotalPracticeTimeAchievement()
    }
    
    /// Check for progress-based achievements
    func checkProgressAchievements(progress: RankProgressData) {
        // Check items completion (forms and techniques combined)
        checkFormsCompletionAchievement(completedForms: progress.completedItems.count)
        
        // Check techniques completion (using completed items as proxy)
        checkTechniquesCompletionAchievement(completedTechniques: progress.completedItems.count)
        
        // Check rank progression (using rank name as string for now)
        checkRankProgressionAchievement(currentRankName: progress.rankName)
    }
    
    // MARK: - Specific Achievement Checks
    
    private func checkFirstPracticeAchievement() {
        let achievementId = "first_practice"
        let existingAchievement = userAchievements.first { $0.achievementId == achievementId }
        
        if existingAchievement == nil {
            unlockAchievement(achievementId: achievementId)
        }
    }
    
    private func checkFormsCompletionAchievement(completedForms: Int) {
        // Check for first form achievement
        if completedForms >= 1 {
            let firstFormAchievement = userAchievements.first { $0.achievementId == "first_form" }
            if firstFormAchievement == nil {
                unlockAchievement(achievementId: "first_form")
            }
        }
        
        // Check for different form completion milestones
        let milestones = [3, 6, 10, 13, 20]
        
        for milestone in milestones {
            if completedForms >= milestone {
                let achievementId = "forms_\(milestone)"
                let existingAchievement = userAchievements.first { $0.achievementId == achievementId }
                
                if existingAchievement == nil {
                    unlockAchievement(achievementId: achievementId)
                }
            }
        }
    }
    
    private func checkTechniquesCompletionAchievement(completedTechniques: Int) {
        // Check for first technique achievement
        if completedTechniques >= 1 {
            let firstTechniqueAchievement = userAchievements.first { $0.achievementId == "first_technique" }
            if firstTechniqueAchievement == nil {
                unlockAchievement(achievementId: "first_technique")
            }
        }
        
        // Check for different technique completion milestones
        let milestones = [10, 20, 35, 50, 72]
        
        for milestone in milestones {
            if completedTechniques >= milestone {
                let achievementId = "techniques_\(milestone)"
                let existingAchievement = userAchievements.first { $0.achievementId == achievementId }
                
                if existingAchievement == nil {
                    unlockAchievement(achievementId: achievementId)
                }
            }
        }
    }
    
    private func checkRankProgressionAchievement(currentRankName: String?) {
        guard let currentRankName = currentRankName else { return }
        
        let achievementId = "rank_\(currentRankName.lowercased().replacingOccurrences(of: " ", with: "_"))"
        let existingAchievement = userAchievements.first { $0.achievementId == achievementId }
        
        if existingAchievement == nil {
            unlockAchievement(achievementId: achievementId)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserId() -> String? {
        // TODO: Get from AuthViewModel or UserDefaults
        // For now, return a default user ID
        return "current_user"
    }
    
    /// Get achievement definition by ID
    private func getAchievementDefinition(_ achievementId: String) -> AchievementDefinition? {
        return AchievementDefinitions.all.first { $0.achievementId == achievementId }
    }
    
    // MARK: - Public Methods
    
    /// Get recent achievements (last 5 unlocked)
    func getRecentAchievements() -> [UserAchievement] {
        return userAchievements
            .filter { $0.isUnlocked }
            .prefix(5)
            .map { $0 }
    }
    
    /// Get all unlocked achievements
    func getUnlockedAchievements() -> [UserAchievement] {
        return userAchievements.filter { $0.isUnlocked }
    }
    
    /// Get locked achievements
    func getLockedAchievements() -> [UserAchievement] {
        return userAchievements.filter { !$0.isUnlocked }
    }
    
    /// Get achievements by category
    func getAchievementsByCategory(_ category: AchievementCategory) -> [UserAchievement] {
        return userAchievements.filter { $0.category == category.rawValue }
    }
}

// MARK: - Achievement Definitions

struct AchievementDefinition {
    let achievementId: String
    let title: String
    let description: String
    let icon: String
    let colorHex: String
    let category: AchievementCategory
}

public enum AchievementCategory: String, CaseIterable {
    case all = "All"
    case practice = "Practice"
    case progress = "Progress"
    case rank = "Rank"
    case social = "Social"
    case special = "Special"
}

struct AchievementDefinitions {
    static let all: [AchievementDefinition] = [
        // Practice-based achievements
        AchievementDefinition(
            achievementId: "first_practice",
            title: "First Steps",
            description: "Complete your first practice session",
            icon: "figure.martial.arts",
            colorHex: "#FF6B6B",
            category: .practice
        ),
        AchievementDefinition(
            achievementId: "practice_streak_7",
            title: "Week Warrior",
            description: "Practice for 7 consecutive days",
            icon: "flame.fill",
            colorHex: "#FF8E53",
            category: .practice
        ),
        AchievementDefinition(
            achievementId: "practice_streak_30",
            title: "Monthly Master",
            description: "Practice for 30 consecutive days",
            icon: "calendar.badge.clock",
            colorHex: "#FF6B6B",
            category: .practice
        ),
        AchievementDefinition(
            achievementId: "practice_streak_100",
            title: "Century Club",
            description: "Practice for 100 consecutive days",
            icon: "100.circle.fill",
            colorHex: "#4ECDC4",
            category: .practice
        ),
        
        // Progress-based achievements
        AchievementDefinition(
            achievementId: "first_form",
            title: "Form Master",
            description: "Complete your first form",
            icon: "figure.martial.arts",
            colorHex: "#45B7D1",
            category: .progress
        ),
        AchievementDefinition(
            achievementId: "forms_5",
            title: "Form Collector",
            description: "Complete 5 forms",
            icon: "list.bullet.rectangle.fill",
            colorHex: "#96CEB4",
            category: .progress
        ),
        AchievementDefinition(
            achievementId: "forms_10",
            title: "Form Expert",
            description: "Complete 10 forms",
            icon: "star.circle.fill",
            colorHex: "#FFEAA7",
            category: .progress
        ),
        AchievementDefinition(
            achievementId: "forms_15",
            title: "Form Grandmaster",
            description: "Complete 15 forms",
            icon: "crown.fill",
            colorHex: "#DDA0DD",
            category: .progress
        ),
        AchievementDefinition(
            achievementId: "forms_20",
            title: "Form Legend",
            description: "Complete all 20 forms",
            icon: "infinity.circle.fill",
            colorHex: "#FF6B6B",
            category: .progress
        ),
        AchievementDefinition(
            achievementId: "first_technique",
            title: "Technique Trainee",
            description: "Complete your first technique",
            icon: "hand.raised.fill",
            colorHex: "#45B7D1",
            category: .progress
        ),
        AchievementDefinition(
            achievementId: "techniques_10",
            title: "Technique Apprentice",
            description: "Complete 10 techniques",
            icon: "hand.raised.fill",
            colorHex: "#96CEB4",
            category: .progress
        ),
        AchievementDefinition(
            achievementId: "techniques_25",
            title: "Technique Practitioner",
            description: "Complete 25 techniques",
            icon: "hand.raised.fill",
            colorHex: "#FFEAA7",
            category: .progress
        ),
        AchievementDefinition(
            achievementId: "techniques_50",
            title: "Technique Expert",
            description: "Complete 50 techniques",
            icon: "hand.raised.fill",
            colorHex: "#DDA0DD",
            category: .progress
        ),
        AchievementDefinition(
            achievementId: "techniques_72",
            title: "Technique Master",
            description: "Complete all 72 techniques to black belt",
            icon: "hand.raised.fill",
            colorHex: "#FF6B6B",
            category: .progress
        ),
        
        // Rank-based achievements
        AchievementDefinition(
            achievementId: "first_rank",
            title: "Rank Riser",
            description: "Earn your first rank",
            icon: "arrow.up.circle.fill",
            colorHex: "#45B7D1",
            category: .rank
        ),
        AchievementDefinition(
            achievementId: "rank_5",
            title: "Rank Climber",
            description: "Earn 5 ranks",
            icon: "arrow.up.circle.fill",
            colorHex: "#96CEB4",
            category: .rank
        ),
        AchievementDefinition(
            achievementId: "rank_10",
            title: "Rank Achiever",
            description: "Earn 10 ranks",
            icon: "arrow.up.circle.fill",
            colorHex: "#FFEAA7",
            category: .rank
        ),
        AchievementDefinition(
            achievementId: "rank_15",
            title: "Rank Champion",
            description: "Earn 15 ranks",
            icon: "arrow.up.circle.fill",
            colorHex: "#DDA0DD",
            category: .rank
        ),
        AchievementDefinition(
            achievementId: "black_belt",
            title: "Black Belt",
            description: "Achieve black belt rank",
            icon: "crown.fill",
            colorHex: "#FF6B6B",
            category: .rank
        )
    ]
} 