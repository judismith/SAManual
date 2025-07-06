import Foundation
import Combine

// MARK: - Practice Tracking State
struct PracticeTrackingState {
    var program: Program?
    var enrollment: Enrollment?
    var rankProgress: RankProgress?
    var programProgress: [ProgramProgress] = []
    var recentSessions: [PracticeSession] = []
    var isLoading = false
    var errorMessage: String?
    
    // Computed properties for UI
    var currentRankName: String {
        return enrollment?.currentRank ?? "Not Enrolled"
    }
    
    var progressPercentage: Double {
        return rankProgress?.overallProgress ?? 0.0
    }
    
    var hasProgram: Bool {
        return program != nil
    }
    
    var canPractice: Bool {
        return hasProgram && enrollment?.enrolled == true
    }
}

// MARK: - Practice Tracking ViewModel (New Architecture)
@MainActor
class PracticeTrackingViewModel: BaseViewModel<PracticeTrackingState> {
    
    // MARK: - Dependencies (Injected)
    private let programService: ProgramService
    private let userService: UserService
    private let mediaService: MediaService
    
    // MARK: - Publishers for reactive updates
    // Note: Using inherited cancellables from BaseViewModel
    
    // MARK: - Initialization
    init(
        programService: ProgramService,
        userService: UserService,
        mediaService: MediaService,
        errorHandler: ErrorHandler
    ) {
        self.programService = programService
        self.userService = userService
        self.mediaService = mediaService
        
        let initialState = PracticeTrackingState()
        super.init(initialState: initialState, errorHandler: errorHandler)
        
        setupPublishers()
    }
    
    // MARK: - Public Methods
    
    /// Load practice data for a specific program
    func loadPracticeData(programId: String, userId: String) async {
        await withErrorHandling("Loading practice data") {
            state.isLoading = true
            
            // Load program details
            guard let program = try await programService.getProgram(id: programId) else {
                throw ProgramServiceError.programNotFound(id: programId)
            }
            
            // Load user enrollment
            let enrollments = try await programService.getUserEnrollments(userId: userId)
            guard let enrollment = enrollments.first(where: { $0.programId == programId }) else {
                throw ProgramServiceError.enrollmentNotFound(userId: userId, programId: programId)
            }
            
            // Load rank progress
            let rankProgress = try await loadRankProgress(
                userId: userId,
                programId: programId,
                rank: enrollment.currentRank ?? "white"
            )
            
            // Load recent progress records
            let progressRecords = try await programService.getUserProgress(
                userId: userId,
                programId: programId,
                limit: 20
            )
            
            // Update state
            state.program = program
            state.enrollment = enrollment
            state.rankProgress = rankProgress
            state.programProgress = progressRecords
            state.isLoading = false
        }
    }
    
    /// Record a practice session
    func recordPracticeSession(
        userId: String,
        programId: String,
        sessionType: ProgressType,
        duration: Double?,
        rank: String? = nil,
        form: String? = nil,
        technique: String? = nil,
        score: Double? = nil,
        notes: String? = nil
    ) async {
        await withErrorHandling("Recording practice session") {
            guard let enrollment = state.enrollment else {
                throw ProgramServiceError.enrollmentNotFound(userId: userId, programId: programId)
            }
            
            let progress = ProgramProgress(
                userId: userId,
                programId: programId,
                sessionId: UUID().uuidString,
                rank: rank ?? enrollment.currentRank,
                form: form,
                technique: technique,
                progressType: sessionType,
                duration: duration,
                score: score,
                notes: notes,
                metadata: ["session_date": ISO8601DateFormatter().string(from: Date())],
                timestamp: Date()
            )
            
            let savedProgress = try await programService.recordProgress(
                userId: userId,
                programId: programId,
                progress: progress
            )
            
            // Update local state
            state.programProgress.insert(savedProgress, at: 0)
            
            // Update rank progress if needed
            if let currentRank = enrollment.currentRank {
                state.rankProgress = try await loadRankProgress(
                    userId: userId,
                    programId: programId,
                    rank: currentRank
                )
            }
        }
    }
    
    /// Update user rank advancement
    func advanceUserRank(userId: String, programId: String, newRank: String) async {
        await withErrorHandling("Advancing user rank") {
            let updatedEnrollment = try await programService.updateUserRank(
                userId: userId,
                programId: programId,
                newRank: newRank
            )
            
            // Update local state
            state.enrollment = updatedEnrollment
            
            // Reload rank progress for new rank
            state.rankProgress = try await loadRankProgress(
                userId: userId,
                programId: programId,
                rank: newRank
            )
        }
    }
    
    /// Get practice recommendations based on current progress
    func getPracticeRecommendations() -> [PracticeRecommendation] {
        guard let program = state.program,
              let enrollment = state.enrollment,
              let currentRank = enrollment.currentRank else {
            return []
        }
        
        // Find current rank in program
        guard let rank = program.ranks.first(where: { $0.name == currentRank }) else {
            return []
        }
        
        var recommendations: [PracticeRecommendation] = []
        
        // Recommend forms that need practice
        for form in rank.forms {
            let formProgress = state.rankProgress?.formProgresses[form.name] ?? 0.0
            
            if formProgress < 0.8 { // Less than 80% mastery
                let recommendation = PracticeRecommendation(
                    id: UUID().uuidString,
                    type: .form,
                    title: "Practice \(form.name)",
                    description: form.description,
                    priority: formProgress < 0.5 ? .high : .medium,
                    estimatedDuration: Int(form.estimatedDuration / 60), // Convert to minutes
                    targetItems: [form.name],
                    reason: "Current progress: \(Int(formProgress * 100))%"
                )
                recommendations.append(recommendation)
            }
        }
        
        // Recommend techniques that need work
        for form in rank.forms {
            for technique in form.techniques {
                let techniqueProgress = state.rankProgress?.techniqueProgresses[technique.name] ?? 0.0
                
                if techniqueProgress < 0.7 { // Less than 70% mastery
                    let recommendation = PracticeRecommendation(
                        id: UUID().uuidString,
                        type: .technique,
                        title: "Work on \(technique.name)",
                        description: technique.description,
                        priority: techniqueProgress < 0.4 ? .high : .medium,
                        estimatedDuration: 15, // Default 15 minutes for technique practice
                        targetItems: [technique.name],
                        reason: "Needs improvement: \(Int(techniqueProgress * 100))% mastery"
                    )
                    recommendations.append(recommendation)
                }
            }
        }
        
        // Sort by priority and progress
        return recommendations.sorted { first, second in
            if first.priority != second.priority {
                return first.priority.rawValue > second.priority.rawValue
            }
            return first.title < second.title
        }
    }
    
    /// Get available forms for current rank
    func getAvailableForms() -> [Form] {
        guard let program = state.program,
              let enrollment = state.enrollment,
              let currentRank = enrollment.currentRank else {
            return []
        }
        
        return program.ranks
            .first(where: { $0.name == currentRank })?
            .forms ?? []
    }
    
    /// Get available techniques for current rank
    func getAvailableTechniques() -> [Technique] {
        return getAvailableForms().flatMap { $0.techniques }
    }
    
    // MARK: - Private Methods
    
    private func setupPublishers() {
        // Listen to program updates
        programService.programUpdatesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedProgram in
                if self?.state.program?.id == updatedProgram.id {
                    self?.state.program = updatedProgram
                }
            }
            .store(in: &cancellables)
        
        // Listen to enrollment updates
        programService.enrollmentUpdatesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedEnrollment in
                if self?.state.enrollment?.id == updatedEnrollment.id {
                    self?.state.enrollment = updatedEnrollment
                }
            }
            .store(in: &cancellables)
        
        // Listen to progress updates
        programService.progressUpdatesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newProgress in
                guard let self = self,
                      newProgress.programId == self.state.program?.id else { return }
                
                // Add to beginning of progress list
                if !self.state.programProgress.contains(where: { $0.id == newProgress.id }) {
                    self.state.programProgress.insert(newProgress, at: 0)
                    
                    // Keep only recent 20 items
                    if self.state.programProgress.count > 20 {
                        self.state.programProgress = Array(self.state.programProgress.prefix(20))
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadRankProgress(userId: String, programId: String, rank: String) async throws -> RankProgress? {
        return try await programService.getRankProgress(
            userId: userId,
            programId: programId,
            rank: rank
        )
    }
    
    private func withErrorHandling<T>(_ operation: String, _ block: () async throws -> T) async -> T? {
        do {
            return try await block()
        } catch {
            await handleError(error, context: operation)
            return nil
        }
    }
    
    private func handleError(_ error: Error, context: String) async {
        let handledError = errorHandler.handle(error, context: context)
        state.errorMessage = handledError.userMessage
        state.isLoading = false
    }
}

// MARK: - Supporting Models for Practice

struct PracticeRecommendation {
    let id: String
    let type: PracticeType
    let title: String
    let description: String
    let priority: Priority
    let estimatedDuration: Int // in minutes
    let targetItems: [String]
    let reason: String
    
    enum PracticeType {
        case form
        case technique
        case conditioning
        case review
    }
    
    enum Priority: Int, CaseIterable {
        case low = 1
        case medium = 2
        case high = 3
        
        var displayName: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
        
        var color: String {
            switch self {
            case .low: return "blue"
            case .medium: return "orange"
            case .high: return "red"
            }
        }
    }
}

// MARK: - Legacy Practice Session Support
// Using the PracticeSession from ServiceModels.swift for consistency