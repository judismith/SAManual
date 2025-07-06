import Foundation
import Combine

// MARK: - Curriculum State
struct CurriculumState: LoadingState, ErrorState {
    var programs: [Program] = []
    var accessiblePrograms: [Program] = []
    var userEnrollments: [Enrollment] = []
    var programProgress: [String: RankProgress] = [:]
    var isLoading = false
    var errorMessage: String?
    
    // Computed properties
    var hasPrograms: Bool {
        return !programs.isEmpty
    }
    
    var enrolledPrograms: [Program] {
        let enrolledProgramIds = userEnrollments
            .filter { $0.enrolled }
            .map { $0.programId }
        
        return programs.filter { enrolledProgramIds.contains($0.id) }
    }
    
    var availablePrograms: [Program] {
        let enrolledProgramIds = Set(userEnrollments.map { $0.programId })
        return accessiblePrograms.filter { !enrolledProgramIds.contains($0.id) }
    }
}

// MARK: - Curriculum ViewModel (New Architecture)
@MainActor
class CurriculumViewModel: BaseViewModel<CurriculumState> {
    
    // MARK: - Dependencies (Injected)
    private let programService: ProgramService
    private let userService: UserService
    private let authService: AuthService
    
    
    // MARK: - Initialization
    init(
        programService: ProgramService,
        userService: UserService,
        authService: AuthService,
        errorHandler: ErrorHandler
    ) {
        self.programService = programService
        self.userService = userService
        self.authService = authService
        
        let initialState = CurriculumState()
        super.init(initialState: initialState, errorHandler: errorHandler)
        
        setupPublishers()
    }
    
    // MARK: - Public Methods
    
    /// Load all programs and user enrollments
    func loadCurriculumData() async {
        await withErrorHandling("Loading curriculum data", block: { [self] in
            state.isLoading = true
            
            // Load all programs
            let allPrograms = try await self.programService.getAllPrograms()
            
            // Get current user for enrollment data
            guard let currentUser = try await userService.getCurrentUser() else {
                throw UserServiceError.userNotFound(id: "current")
            }
            
            // Load user enrollments - get enrollments for each program
            var enrollments: [Enrollment] = []
            for program in allPrograms {
                if let enrollment = try await programService.getEnrollmentForUser(userId: currentUser.id, programId: program.id) {
                    enrollments.append(enrollment)
                }
            }
            
            // Filter accessible programs based on user's access level
            let accessiblePrograms = filterAccessiblePrograms(
                programs: allPrograms,
                userAccessLevel: currentUser.accessLevel
            )
            
            // Load progress for enrolled programs
            var progressData: [String: RankProgress] = [:]
            for enrollment in enrollments.filter({ $0.enrolled }) {
                if let rank = enrollment.currentRank {
                    if let progress = try await programService.getProgressForRank(
                        userId: currentUser.id,
                        programId: enrollment.programId,
                        rankId: rank
                    ) {
                        progressData[enrollment.programId] = progress
                    }
                }
            }
            
            // Update state
            state.programs = allPrograms
            state.accessiblePrograms = accessiblePrograms
            state.userEnrollments = enrollments
            state.programProgress = progressData
            state.isLoading = false
        })
    }
    
    /// Enroll user in a program
    func enrollInProgram(programId: String, startingRank: String = "white") async -> Bool {
        guard let currentUser = try? await userService.getCurrentUser() else {
            state.errorMessage = "User not authenticated"
            return false
        }
        
        return await withErrorHandling("Enrolling in program", block: { [self] in
            let enrollment = Enrollment(
                userId: currentUser.id,
                programId: programId,
                currentRank: startingRank
            )
            let createdEnrollment = try await self.programService.createEnrollment(enrollment)
            
            // Update local state
            if let index = self.state.userEnrollments.firstIndex(where: { $0.programId == programId }) {
                self.state.userEnrollments[index] = createdEnrollment
            } else {
                self.state.userEnrollments.append(createdEnrollment)
            }
            
            // Load initial progress for the new enrollment
            if let progress = try await self.programService.getProgressForRank(
                userId: currentUser.id,
                programId: programId,
                rankId: startingRank
            ) {
                self.state.programProgress[programId] = progress
            }
            
            return true
        }) != nil
    }
    
    /// Unenroll user from a program
    func unenrollFromProgram(programId: String) async -> Bool {
        guard let currentUser = try? await userService.getCurrentUser() else {
            state.errorMessage = "User not authenticated"
            return false
        }
        
        return await withErrorHandling("Unenrolling from program", block: { [self] in
            guard let enrollment = try await self.programService.getEnrollmentForUser(userId: currentUser.id, programId: programId) else {
                throw ProgramServiceError.enrollmentNotFound(id: "\(currentUser.id)-\(programId)")
            }
            try await self.programService.deleteEnrollment(id: enrollment.id)
            
            // Update local state - remove the enrollment
            self.state.userEnrollments.removeAll { $0.programId == programId }
            
            // Remove progress data
            self.state.programProgress.removeValue(forKey: programId)
            
            return true
        }) != nil
    }
    
    /// Get program by ID
    func getProgram(id: String) -> Program? {
        return state.programs.first { $0.id == id }
    }
    
    /// Get enrollment for a program
    func getEnrollment(programId: String) -> Enrollment? {
        return state.userEnrollments.first { $0.programId == programId }
    }
    
    /// Get progress for a program
    func getProgress(programId: String) -> RankProgress? {
        return state.programProgress[programId]
    }
    
    /// Check if user can access a program
    func canAccessProgram(_ program: Program) -> Bool {
        return state.accessiblePrograms.contains { $0.id == program.id }
    }
    
    /// Get access level description
    func getAccessLevelDescription(for program: Program) -> String {
        // This would be determined by program metadata or access level
        return "Available" // Simplified for now
    }
    
    /// Get rank progression for a program
    func getRankProgression(programId: String) -> [Rank] {
        guard let program = getProgram(id: programId) else { return [] }
        return program.ranks.sorted { $0.name < $1.name } // Simplified sorting
    }
    
    /// Get next rank for current user in a program
    func getNextRank(programId: String) -> Rank? {
        guard let enrollment = getEnrollment(programId: programId),
              let currentRankName = enrollment.currentRank,
              let program = getProgram(id: programId) else {
            return nil
        }
        
        // Find current rank
        guard let currentRank = program.ranks.first(where: { $0.name == currentRankName }) else {
            return nil
        }
        
        // Find next rank (simplified logic - would need proper rank ordering)
        return program.ranks.first { $0.name > currentRankName }
    }
    
    /// Get next rank for a specific rank name in a program
    func getNextRank(for programId: String, currentRankName: String) -> Rank? {
        guard let program = getProgram(id: programId) else {
            return nil
        }
        
        // Find current rank
        guard let currentRank = program.ranks.first(where: { $0.name == currentRankName }) else {
            return nil
        }
        
        // Find next rank by order
        let sortedRanks = program.ranks.sorted { $0.order < $1.order }
        guard let currentIndex = sortedRanks.firstIndex(where: { $0.id == currentRank.id }),
              currentIndex + 1 < sortedRanks.count else {
            return nil
        }
        
        return sortedRanks[currentIndex + 1]
    }
    
    /// Search programs by name or description
    func searchPrograms(query: String) async -> [Program] {
        guard !query.isEmpty else {
            return state.accessiblePrograms
        }
        
        do {
            return try await programService.searchPrograms(query: query, limit: 50)
        } catch {
            await handleError(error, context: ErrorContext(operation: "Searching programs"))
        }
        
        // Fallback to local search
        return state.accessiblePrograms.filter { program in
            program.name.localizedCaseInsensitiveContains(query) ||
            program.description.localizedCaseInsensitiveContains(query)
        }
    }
    
    /// Get programs by category
    func getProgramsByCategory(_ category: ProgramType) async -> [Program] {
        if let categoryResults = await withErrorHandling("Loading programs by category", block: {
            return try await programService.getProgramsByType(category)
        }) {
            return categoryResults
        }
        
        // Fallback to local filtering
        return state.accessiblePrograms.filter { $0.type == category }
    }
    
    /// Refresh all data
    func refresh() async {
        await loadCurriculumData()
    }
    
    // MARK: - Private Methods
    
    private func setupPublishers() {
        // Listen to program updates
        programService.programUpdatesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedProgram in
                self?.handleProgramUpdate(updatedProgram)
            }
            .store(in: &cancellables)
        
        // Listen to enrollment updates
        programService.enrollmentUpdatesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedEnrollment in
                self?.handleEnrollmentUpdate(updatedEnrollment)
            }
            .store(in: &cancellables)
        
        // Listen to user updates (for access level changes)
        userService.userUpdatesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedUser in
                self?.handleUserUpdate(updatedUser)
            }
            .store(in: &cancellables)
        
        // Listen to auth state changes
        authService.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authState in
                self?.handleAuthStateChange(authState)
            }
            .store(in: &cancellables)
    }
    
    private func handleProgramUpdate(_ program: Program) {
        // Update program in list
        if let index = state.programs.firstIndex(where: { $0.id == program.id }) {
            state.programs[index] = program
        }
        
        // Update accessible programs
        state.accessiblePrograms = filterAccessiblePrograms(
            programs: state.programs,
            userAccessLevel: getCurrentUserAccessLevel()
        )
    }
    
    private func handleEnrollmentUpdate(_ enrollment: Enrollment) {
        // Update enrollment in list
        if let index = state.userEnrollments.firstIndex(where: { $0.id == enrollment.id }) {
            state.userEnrollments[index] = enrollment
        } else {
            state.userEnrollments.append(enrollment)
        }
    }
    
    private func handleUserUpdate(_ user: UserProfile) {
        // Update accessible programs based on new access level
        state.accessiblePrograms = filterAccessiblePrograms(
            programs: state.programs,
            userAccessLevel: user.accessLevel
        )
    }
    
    private func handleAuthStateChange(_ authState: AuthState) {
        switch authState {
        case .loading:
            // Show loading state, don't clear data yet
            state.isLoading = true
            
        case .unauthenticated:
            // Clear user-specific data
            state.userEnrollments = []
            state.programProgress = [:]
            // Keep programs but filter for public access only
            state.accessiblePrograms = state.programs.filter { isPubliclyAccessible($0) }
            state.isLoading = false
            
        case .authenticated:
            // Reload data for authenticated user
            Task {
                await loadCurriculumData()
            }
        }
    }
    
    private func filterAccessiblePrograms(programs: [Program], userAccessLevel: AccessLevel) -> [Program] {
        return programs.filter { program in
            canUserAccessProgram(program, userAccessLevel: userAccessLevel)
        }
    }
    
    private func canUserAccessProgram(_ program: Program, userAccessLevel: AccessLevel) -> Bool {
        // This logic would be more sophisticated in a real app
        switch userAccessLevel {
        case .admin:
            return true
        case .instructor:
            return true
        case .subscriber:
            return true // Subscribers can access most content
        case .free:
            return isPubliclyAccessible(program)
        }
    }
    
    private func isPubliclyAccessible(_ program: Program) -> Bool {
        // This would check program metadata for public accessibility
        // For now, assume all programs are publicly accessible
        return true
    }
    
    private func getCurrentUserAccessLevel() -> AccessLevel {
        // This would get from current user or auth service
        return .free // Default
    }
    
    private func handleError(_ error: Error, context: ErrorContext) async {
        errorHandler.handle(error, context: context)
        state.errorMessage = error.localizedDescription
        state.isLoading = false
    }
}