import Foundation
import Combine

// MARK: - Practice Session Types
enum PracticeSessionType: String, CaseIterable {
    case solo = "solo"
    case group = "group"
    case formalClass = "class"
    case competition = "competition"
    
    var displayName: String {
        switch self {
        case .solo: return "Solo Practice"
        case .group: return "Group Practice"
        case .formalClass: return "Class"
        case .competition: return "Competition"
        }
    }
}

// MARK: - Practice Session State
struct PracticeSessionState: LoadingState, ErrorState {
    var sessionType: PracticeSessionType = .solo
    var selectedProgram: Program?
    var selectedRank: String?
    var selectedForms: [CurriculumItem] = []
    var selectedTechniques: [CurriculumItem] = []
    var formRatings: [String: SessionRating] = [:]
    var techniqueRatings: [String: SessionRating] = [:]
    var sessionNotes: String = ""
    var sessionName: String = ""
    var duration: TimeInterval = 0
    var startTime: Date?
    var endTime: Date?
    var isActive: Bool = false
    var isSaving = false
    var isLoading = false
    var errorMessage: String?
    
    // Computed properties
    var hasSelectedItems: Bool {
        return !selectedForms.isEmpty || !selectedTechniques.isEmpty
    }
    
    var sessionInProgress: Bool {
        return isActive && startTime != nil
    }
    
    var estimatedDuration: TimeInterval {
        let formDuration = selectedForms.reduce(into: 0.0) { $0 += ($1.estimatedPracticeTime) }
        let techniqueDuration = Double(selectedTechniques.count) * 120 // 2 minutes per technique
        return formDuration + techniqueDuration
    }
}

// MARK: - Session Rating Model
struct SessionRating {
    let difficulty: Int      // 1-5 scale
    let confidence: Int      // 1-5 scale
    let quality: Int         // 1-5 scale
    let repetitions: Int     // Number of repetitions
    let timeSpent: TimeInterval // Time spent on this item
    let needsMorePractice: Bool
    let notes: String?
    
    var averageScore: Double {
        return Double(difficulty + confidence + quality) / 3.0
    }
}

// MARK: - Practice Session ViewModel (New Architecture)
@MainActor
class PracticeSessionViewModel: BaseViewModel<PracticeSessionState> {
    
    // MARK: - Dependencies (Injected)
    private let programService: ProgramService
    private let userService: UserService
    private let mediaService: MediaService
    
    // MARK: - Publishers and Timers
    // Note: Using inherited cancellables from BaseViewModel
    private var sessionTimer: Timer?
    
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
        
        let initialState = PracticeSessionState()
        super.init(initialState: initialState, errorHandler: errorHandler)
        
        setupPublishers()
    }
    
    deinit {
        sessionTimer?.invalidate()
    }
    
    // MARK: - Session Management
    
    /// Initialize session with a program and user's current rank
    func initializeSession(programId: String, userId: String) async {
        await withErrorHandling("Initializing practice session", block: {
            // Load program
            guard let program = try await programService.getProgram(id: programId) else {
                throw ProgramServiceError.programNotFound(id: programId)
            }
            
            // Get user's enrollment to determine current rank
            guard let enrollment = try await programService.getEnrollmentForUser(userId: userId, programId: programId),
                  let currentRank = enrollment.currentRank else {
                throw ProgramServiceError.enrollmentNotFound(id: "\(userId)-\(programId)")
            }
            
            // Update state
            state.selectedProgram = program
            state.selectedRank = currentRank
            
            // Generate default session name
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            state.sessionName = "\(program.name) - \(formatter.string(from: Date()))"
        }
    }
    
    /// Start a practice session
    func startSession() {
        guard state.hasSelectedItems else {
            state.errorMessage = "Please select at least one form or technique to practice"
            return
        }
        
        state.isActive = true
        state.startTime = Date()
        state.duration = 0
        
        // Start timer to track duration
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDuration()
            }
        }
        
        print("🏁 [PracticeSession] Session started: \(state.sessionName)")
    }
    
    /// End the practice session
    func endSession() {
        state.isActive = false
        state.endTime = Date()
        
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        print("🏁 [PracticeSession] Session ended after \(formatDuration(state.duration))")
    }
    
    /// Save the practice session
    func saveSession() async -> Bool {
        guard let program = state.selectedProgram,
              let rank = state.selectedRank else {
            state.errorMessage = "Session data is incomplete"
            return false
        }
        
        guard let currentUser = try? await userService.getCurrentUser() else {
            state.errorMessage = "User not authenticated"
            return false
        }
        
        return await withErrorHandling("Saving practice session", block: {
            state.isSaving = true
            
            // Create progress records for each practiced item
            var savedProgress: [ProgramProgress] = []
            
            // Save form progress
            for form in state.selectedForms {
                if let rating = state.formRatings[form.id] {
                    let progress = ProgramProgress(
                        userId: currentUser.id,
                        programId: program.id,
                        currentRankId: rank
                    )
                    
                    let saved = try await programService.updateUserProgress(
                        userId: currentUser.id,
                        programId: program.id,
                        progress: progress
                    )
                    savedProgress.append(saved)
                }
            }
            
            // Save technique progress
            for technique in state.selectedTechniques {
                if let rating = state.techniqueRatings[technique.id] {
                    let progress = ProgramProgress(
                        userId: currentUser.id,
                        programId: program.id,
                        currentRankId: rank
                    )
                    
                    let saved = try await programService.updateUserProgress(
                        userId: currentUser.id,
                        programId: program.id,
                        progress: progress
                    )
                    savedProgress.append(saved)
                }
            }
            
            // Update rank progress if needed
            let itemsNeedingPractice = getAllRatings().filter { $0.value.needsMorePractice }
            if !itemsNeedingPractice.isEmpty {
                // This would update the rank progress to reflect items needing more work
                try await updateRankProgress(
                    userId: currentUser.id,
                    programId: program.id,
                    rank: rank,
                    itemsNeedingPractice: itemsNeedingPractice.map { $0.key }
                )
            }
            
            state.isSaving = false
            print("✅ [PracticeSession] Saved \(savedProgress.count) progress records")
            return true
        }) != nil
    }
    
    // MARK: - Item Selection
    
    /// Add a form to the practice session
    func addForm(_ form: CurriculumItem) {
        if !state.selectedForms.contains(where: { $0.id == form.id }) {
            state.selectedForms.append(form)
            
            // Initialize default rating
            state.formRatings[form.id] = SessionRating(
                difficulty: 3,
                confidence: 3,
                quality: 3,
                repetitions: 1,
                timeSpent: 0,
                needsMorePractice: false,
                notes: nil
            )
        }
    }
    
    /// Remove a form from the practice session
    func removeForm(_ form: CurriculumItem) {
        state.selectedForms.removeAll { $0.id == form.id }
        state.formRatings.removeValue(forKey: form.id)
    }
    
    /// Add a technique to the practice session
    func addTechnique(_ technique: CurriculumItem) {
        if !state.selectedTechniques.contains(where: { $0.id == technique.id }) {
            state.selectedTechniques.append(technique)
            
            // Initialize default rating
            state.techniqueRatings[technique.id] = SessionRating(
                difficulty: 3,
                confidence: 3,
                quality: 3,
                repetitions: 1,
                timeSpent: 0,
                needsMorePractice: false,
                notes: nil
            )
        }
    }
    
    /// Remove a technique from the practice session
    func removeTechnique(_ technique: CurriculumItem) {
        state.selectedTechniques.removeAll { $0.id == technique.id }
        state.techniqueRatings.removeValue(forKey: technique.id)
    }
    
    // MARK: - Rating Management
    
    /// Update rating for a form
    func updateFormRating(formId: String, rating: SessionRating) {
        state.formRatings[formId] = rating
    }
    
    /// Update rating for a technique
    func updateTechniqueRating(techniqueId: String, rating: SessionRating) {
        state.techniqueRatings[techniqueId] = rating
    }
    
    /// Get rating for a form
    func getFormRating(formId: String) -> SessionRating? {
        return state.formRatings[formId]
    }
    
    /// Get rating for a technique
    func getTechniqueRating(techniqueId: String) -> SessionRating? {
        return state.techniqueRatings[techniqueId]
    }
    
    // MARK: - Available Items
    
    /// Get available forms for current rank
    func getAvailableForms() async -> [CurriculumItem] {
        guard let program = state.selectedProgram,
              let rankId = state.selectedRank else {
            return []
        }
        
        do {
            let curriculum = try await programService.getCurriculumForRank(programId: program.id, rankId: rankId)
            return curriculum.filter { $0.type == .form }
        } catch {
            return []
        }
    }
    
    /// Get available techniques for current rank
    func getAvailableTechniques() async -> [CurriculumItem] {
        guard let program = state.selectedProgram,
              let rankId = state.selectedRank else {
            return []
        }
        
        do {
            let curriculum = try await programService.getCurriculumForRank(programId: program.id, rankId: rankId)
            return curriculum.filter { $0.type == .technique }
        } catch {
            return []
        }
    }
    
    // MARK: - Session Analytics
    
    /// Get session summary
    func getSessionSummary() -> SessionSummary {
        let allRatings = getAllRatings()
        let totalTime = allRatings.values.reduce(0) { $0 + $1.timeSpent }
        let averageQuality = allRatings.values.isEmpty ? 0 : 
            allRatings.values.map { $0.quality }.reduce(0, +) / allRatings.count
        let itemsNeedingPractice = allRatings.filter { $0.value.needsMorePractice }.count
        
        return SessionSummary(
            sessionName: state.sessionName,
            sessionType: state.sessionType,
            totalDuration: state.duration,
            practiceTime: totalTime,
            formsCount: state.selectedForms.count,
            techniquesCount: state.selectedTechniques.count,
            averageQuality: averageQuality,
            itemsNeedingPractice: itemsNeedingPractice,
            notes: state.sessionNotes
        )
    }
    
    // MARK: - Private Methods
    
    private func setupPublishers() {
        // Could listen to program updates, user updates, etc.
    }
    
    private func updateDuration() {
        if let startTime = state.startTime {
            state.duration = Date().timeIntervalSince(startTime)
        }
    }
    
    private func getAllRatings() -> [String: SessionRating] {
        var allRatings: [String: SessionRating] = [:]
        allRatings.merge(state.formRatings) { _, new in new }
        allRatings.merge(state.techniqueRatings) { _, new in new }
        return allRatings
    }
    
    private func combineNotes(sessionNotes: String, itemNotes: String?) -> String? {
        let parts = [sessionNotes, itemNotes].compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }
    
    private func createSessionMetadata(rating: SessionRating) -> [String: Any] {
        return [
            "session_type": state.sessionType.rawValue,
            "difficulty": rating.difficulty,
            "confidence": rating.confidence,
            "quality": rating.quality,
            "repetitions": rating.repetitions,
            "needs_practice": rating.needsMorePractice
        ]
    }
    
    private func updateRankProgress(
        userId: String,
        programId: String,
        rank: String,
        itemsNeedingPractice: [String]
    ) async throws {
        // This would update the user's rank progress to reflect areas needing work
        // Implementation would depend on how rank progress is structured
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else {
            return String(format: "%dm %ds", minutes, seconds)
        }
    }
    
    private func withErrorHandling<T>(_ operation: String, _ block: () async throws -> T) async -> T? {
        do {
            return try await block()
        } catch {
            await handleError(error, context: ErrorContext(operation: operation))
            return nil
        }
    }
    
    private func handleError(_ error: Error, context: String) async {
        let handledError = errorHandler.handle(error, context: context)
        state.errorMessage = handledError.userMessage
        state.isSaving = false
    }
}

// MARK: - Session Summary Model
struct SessionSummary {
    let sessionName: String
    let sessionType: PracticeSessionType
    let totalDuration: TimeInterval
    let practiceTime: TimeInterval
    let formsCount: Int
    let techniquesCount: Int
    let averageQuality: Int
    let itemsNeedingPractice: Int
    let notes: String
}