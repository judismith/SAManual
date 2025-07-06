import Foundation
import Combine

// MARK: - Mock Program Service Implementation
public final class MockProgramService: ProgramService {
    
    // MARK: - In-Memory Storage
    private var programs: [String: Program] = [:]
    private var enrollments: [String: Enrollment] = [:]
    private var progressRecords: [String: ProgramProgress] = [:]
    private var rankProgresses: [String: RankProgress] = [:]
    
    // MARK: - Publishers
    private let programUpdatesSubject = PassthroughSubject<Program, Never>()
    private let enrollmentUpdatesSubject = PassthroughSubject<Enrollment, Never>()
    private let progressUpdatesSubject = PassthroughSubject<ProgramProgress, Never>()
    
    public var programUpdatesPublisher: AnyPublisher<Program, Never> {
        programUpdatesSubject.eraseToAnyPublisher()
    }
    
    public var enrollmentUpdatesPublisher: AnyPublisher<Enrollment, Never> {
        enrollmentUpdatesSubject.eraseToAnyPublisher()
    }
    
    public var progressUpdatesPublisher: AnyPublisher<ProgramProgress, Never> {
        progressUpdatesSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    public init() {
        seedSampleData()
    }
    
    // MARK: - Program Management
    public func createProgram(_ program: Program) async throws -> Program {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Check for duplicate name
        if programs.values.contains(where: { $0.name == program.name }) {
            throw ProgramServiceError.duplicateProgram(name: program.name)
        }
        
        var newProgram = program
        newProgram.updatedAt = Date()
        
        programs[newProgram.id] = newProgram
        programUpdatesSubject.send(newProgram)
        
        return newProgram
    }
    
    public func getProgram(id: String) async throws -> Program? {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        return programs[id]
    }
    
    public func updateProgram(_ program: Program) async throws -> Program {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard programs[program.id] != nil else {
            throw ProgramServiceError.programNotFound(id: program.id)
        }
        
        var updatedProgram = program
        updatedProgram.updatedAt = Date()
        
        programs[program.id] = updatedProgram
        programUpdatesSubject.send(updatedProgram)
        
        return updatedProgram
    }
    
    public func deleteProgram(id: String) async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard programs[id] != nil else {
            throw ProgramServiceError.programNotFound(id: id)
        }
        
        programs.removeValue(forKey: id)
        
        // Clean up related data
        enrollments = enrollments.filter { $0.value.programId != id }
        progressRecords = progressRecords.filter { $0.value.programId != id }
        rankProgresses = rankProgresses.filter { $0.value.programId != id }
    }
    
    public func getAllPrograms() async throws -> [Program] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        return Array(programs.values)
    }
    
    public func getActivePrograms() async throws -> [Program] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        return programs.values.filter { $0.isActive }
    }
    
    // MARK: - Program Search and Filtering
    public func searchPrograms(query: String, limit: Int) async throws -> [Program] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        let lowercaseQuery = query.lowercased()
        let filteredPrograms = programs.values.filter { program in
            program.name.lowercased().contains(lowercaseQuery) ||
            program.description.lowercased().contains(lowercaseQuery)
        }
        
        return Array(filteredPrograms.prefix(limit))
    }
    
    public func getProgramsByType(_ type: ProgramType) async throws -> [Program] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        return programs.values.filter { $0.type == type }
    }
    
    public func getProgramsByInstructor(instructorId: String) async throws -> [Program] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        return programs.values.filter { $0.instructorIds.contains(instructorId) }
    }
    
    public func getProgramsByAccessLevel(_ accessLevel: AccessLevel) async throws -> [Program] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // For this mock, we'll filter based on program type
        // In reality, this would be based on actual access control
        switch accessLevel {
        case .free:
            return programs.values.filter { $0.type == .kungFu || $0.type == .meditation }
        case .subscriber:
            return programs.values.filter { $0.type != .demonstration }
        case .instructor, .admin:
            return Array(programs.values)
        }
    }
    
    // MARK: - Rank Management
    public func getRanksForProgram(programId: String) async throws -> [Rank] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        guard let program = programs[programId] else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        
        return program.ranks.sorted { $0.order < $1.order }
    }
    
    public func addRankToProgram(programId: String, rank: Rank) async throws -> Program {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        guard var program = programs[programId] else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        
        var updatedRanks = program.ranks
        updatedRanks.append(rank)
        
        program = Program(
            id: program.id,
            name: program.name,
            description: program.description,
            type: program.type,
            isActive: program.isActive,
            instructorIds: program.instructorIds,
            ranks: updatedRanks,
            curriculum: program.curriculum
        )
        
        programs[programId] = program
        programUpdatesSubject.send(program)
        
        return program
    }
    
    public func updateRankInProgram(programId: String, rank: Rank) async throws -> Program {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        guard var program = programs[programId] else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        
        guard let rankIndex = program.ranks.firstIndex(where: { $0.id == rank.id }) else {
            throw ProgramServiceError.rankNotFound(id: rank.id, programId: programId)
        }
        
        var updatedRanks = program.ranks
        updatedRanks[rankIndex] = rank
        
        program = Program(
            id: program.id,
            name: program.name,
            description: program.description,
            type: program.type,
            isActive: program.isActive,
            instructorIds: program.instructorIds,
            ranks: updatedRanks,
            curriculum: program.curriculum
        )
        
        programs[programId] = program
        programUpdatesSubject.send(program)
        
        return program
    }
    
    public func removeRankFromProgram(programId: String, rankId: String) async throws -> Program {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        guard var program = programs[programId] else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        
        guard program.ranks.contains(where: { $0.id == rankId }) else {
            throw ProgramServiceError.rankNotFound(id: rankId, programId: programId)
        }
        
        let updatedRanks = program.ranks.filter { $0.id != rankId }
        
        program = Program(
            id: program.id,
            name: program.name,
            description: program.description,
            type: program.type,
            isActive: program.isActive,
            instructorIds: program.instructorIds,
            ranks: updatedRanks,
            curriculum: program.curriculum
        )
        
        programs[programId] = program
        programUpdatesSubject.send(program)
        
        return program
    }
    
    public func getNextRank(programId: String, currentRank: String) async throws -> Rank? {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        guard let program = programs[programId] else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        
        let sortedRanks = program.ranks.sorted { $0.order < $1.order }
        
        guard let currentRankIndex = sortedRanks.firstIndex(where: { $0.id == currentRank }) else {
            return nil
        }
        
        let nextIndex = currentRankIndex + 1
        return nextIndex < sortedRanks.count ? sortedRanks[nextIndex] : nil
    }
    
    // MARK: - Curriculum Management
    public func getCurriculumForProgram(programId: String) async throws -> [CurriculumItem] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        guard let program = programs[programId] else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        
        return program.curriculum.sorted { $0.order < $1.order }
    }
    
    public func getCurriculumForRank(programId: String, rankId: String) async throws -> [CurriculumItem] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        guard let program = programs[programId] else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        
        return program.curriculum.filter { $0.rankId == rankId }.sorted { $0.order < $1.order }
    }
    
    public func addCurriculumItem(programId: String, item: CurriculumItem) async throws -> Program {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        guard var program = programs[programId] else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        
        var updatedCurriculum = program.curriculum
        updatedCurriculum.append(item)
        
        program = Program(
            id: program.id,
            name: program.name,
            description: program.description,
            type: program.type,
            isActive: program.isActive,
            instructorIds: program.instructorIds,
            ranks: program.ranks,
            curriculum: updatedCurriculum
        )
        
        programs[programId] = program
        programUpdatesSubject.send(program)
        
        return program
    }
    
    public func updateCurriculumItem(programId: String, item: CurriculumItem) async throws -> Program {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        guard var program = programs[programId] else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        
        guard let itemIndex = program.curriculum.firstIndex(where: { $0.id == item.id }) else {
            throw ProgramServiceError.curriculumItemNotFound(id: item.id)
        }
        
        var updatedCurriculum = program.curriculum
        updatedCurriculum[itemIndex] = item
        
        program = Program(
            id: program.id,
            name: program.name,
            description: program.description,
            type: program.type,
            isActive: program.isActive,
            instructorIds: program.instructorIds,
            ranks: program.ranks,
            curriculum: updatedCurriculum
        )
        
        programs[programId] = program
        programUpdatesSubject.send(program)
        
        return program
    }
    
    public func removeCurriculumItem(programId: String, itemId: String) async throws -> Program {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        guard var program = programs[programId] else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        
        guard program.curriculum.contains(where: { $0.id == itemId }) else {
            throw ProgramServiceError.curriculumItemNotFound(id: itemId)
        }
        
        let updatedCurriculum = program.curriculum.filter { $0.id != itemId }
        
        program = Program(
            id: program.id,
            name: program.name,
            description: program.description,
            type: program.type,
            isActive: program.isActive,
            instructorIds: program.instructorIds,
            ranks: program.ranks,
            curriculum: updatedCurriculum
        )
        
        programs[programId] = program
        programUpdatesSubject.send(program)
        
        return program
    }
    
    // MARK: - Enrollment Management
    public func getEnrollmentsForProgram(programId: String) async throws -> [Enrollment] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        return enrollments.values.filter { $0.programId == programId }
    }
    
    public func getEnrollmentForUser(userId: String, programId: String) async throws -> Enrollment? {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        return enrollments.values.first { $0.userId == userId && $0.programId == programId }
    }
    
    public func createEnrollment(_ enrollment: Enrollment) async throws -> Enrollment {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        // Check for duplicate enrollment
        if enrollments.values.contains(where: { $0.userId == enrollment.userId && $0.programId == enrollment.programId }) {
            throw ProgramServiceError.duplicateEnrollment(userId: enrollment.userId, programId: enrollment.programId)
        }
        
        enrollments[enrollment.id] = enrollment
        enrollmentUpdatesSubject.send(enrollment)
        
        return enrollment
    }
    
    public func updateEnrollment(_ enrollment: Enrollment) async throws -> Enrollment {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard enrollments[enrollment.id] != nil else {
            throw ProgramServiceError.enrollmentNotFound(id: enrollment.id)
        }
        
        enrollments[enrollment.id] = enrollment
        enrollmentUpdatesSubject.send(enrollment)
        
        return enrollment
    }
    
    public func deleteEnrollment(id: String) async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard enrollments[id] != nil else {
            throw ProgramServiceError.enrollmentNotFound(id: id)
        }
        
        enrollments.removeValue(forKey: id)
    }
    
    // MARK: - Progress Tracking
    public func getProgressForUser(userId: String, programId: String) async throws -> ProgramProgress? {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        return progressRecords.values.first { $0.userId == userId && $0.programId == programId }
    }
    
    public func updateUserProgress(userId: String, programId: String, progress: ProgramProgress) async throws -> ProgramProgress {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        var updatedProgress = progress
        updatedProgress.updatedAt = Date()
        
        progressRecords[progress.id] = updatedProgress
        progressUpdatesSubject.send(updatedProgress)
        
        return updatedProgress
    }
    
    public func getProgressForRank(userId: String, programId: String, rankId: String) async throws -> RankProgress? {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        return rankProgresses.values.first { $0.userId == userId && $0.programId == programId && $0.rankId == rankId }
    }
    
    public func updateRankProgress(userId: String, programId: String, rankId: String, progress: RankProgress) async throws -> RankProgress {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        var updatedProgress = progress
        updatedProgress.updatedAt = Date()
        
        rankProgresses[progress.id] = updatedProgress
        
        return updatedProgress
    }
    
    // MARK: - Instructor Management
    public func getInstructorsForProgram(programId: String) async throws -> [UserProfile] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        guard let program = programs[programId] else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        
        // In a real implementation, this would fetch UserProfile objects
        // For this mock, we'll return sample instructor profiles
        return program.instructorIds.map { instructorId in
            UserProfile(
                id: instructorId,
                email: "instructor\(instructorId)@sakungfu.com",
                firstName: "Instructor",
                lastName: instructorId,
                accessLevel: .instructor
            )
        }
    }
    
    public func addInstructorToProgram(programId: String, instructorId: String) async throws -> Program {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        guard var program = programs[programId] else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        
        if program.instructorIds.contains(instructorId) {
            return program // Already an instructor
        }
        
        var updatedInstructorIds = program.instructorIds
        updatedInstructorIds.append(instructorId)
        
        program = Program(
            id: program.id,
            name: program.name,
            description: program.description,
            type: program.type,
            isActive: program.isActive,
            instructorIds: updatedInstructorIds,
            ranks: program.ranks,
            curriculum: program.curriculum
        )
        
        programs[programId] = program
        programUpdatesSubject.send(program)
        
        return program
    }
    
    public func removeInstructorFromProgram(programId: String, instructorId: String) async throws -> Program {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        guard var program = programs[programId] else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        
        let updatedInstructorIds = program.instructorIds.filter { $0 != instructorId }
        
        program = Program(
            id: program.id,
            name: program.name,
            description: program.description,
            type: program.type,
            isActive: program.isActive,
            instructorIds: updatedInstructorIds,
            ranks: program.ranks,
            curriculum: program.curriculum
        )
        
        programs[programId] = program
        programUpdatesSubject.send(program)
        
        return program
    }
    
    // MARK: - Mock Helper Methods
    public func clearAllData() {
        programs.removeAll()
        enrollments.removeAll()
        progressRecords.removeAll()
        rankProgresses.removeAll()
    }
    
    // MARK: - Sample Data
    private func seedSampleData() {
        // Sample ranks
        let whiteRank = Rank(id: "white", name: "White Sash", order: 0, color: "white", description: "Beginning rank")
        let yellowRank = Rank(id: "yellow", name: "Yellow Sash", order: 1, color: "yellow", description: "First advancement")
        let blueRank = Rank(id: "blue1", name: "Blue Sash 1", order: 2, color: "blue", description: "Intermediate level")
        let blue2Rank = Rank(id: "blue2", name: "Blue Sash 2", order: 3, color: "blue", description: "Advanced intermediate")
        let blackRank = Rank(id: "black1", name: "Black Sash 1", order: 4, color: "black", description: "Advanced level")
        
        // Sample curriculum items
        let basicStances = CurriculumItem(
            programId: "kungfu-program",
            rankId: "white",
            name: "Basic Stances",
            description: "Horse stance, bow stance, cat stance",
            type: .technique,
            order: 1,
            requiredForPromotion: true,
            difficulty: .beginner,
            tags: ["stances", "basics"]
        )
        
        let form1 = CurriculumItem(
            programId: "kungfu-program",
            rankId: "yellow",
            name: "Form 1 - Five Element Fist",
            description: "First traditional form",
            type: .form,
            order: 1,
            requiredForPromotion: true,
            difficulty: .intermediate,
            tags: ["form", "traditional"]
        )
        
        // Sample programs
        let kungFuProgram = Program(
            id: "kungfu-program",
            name: "Kung Fu Program",
            description: "Traditional Shaolin Kung Fu training",
            type: .kungFu,
            isActive: true,
            instructorIds: ["user1"],
            ranks: [whiteRank, yellowRank, blueRank, blue2Rank, blackRank],
            curriculum: [basicStances, form1]
        )
        
        let youthProgram = Program(
            id: "youth-program",
            name: "Youth Kung Fu",
            description: "Kung Fu program designed for children",
            type: .youthKungFu,
            isActive: true,
            instructorIds: ["user1"],
            ranks: [whiteRank, yellowRank, blueRank],
            curriculum: [basicStances]
        )
        
        programs["kungfu-program"] = kungFuProgram
        programs["youth-program"] = youthProgram
        
        // Sample enrollments
        let enrollment1 = Enrollment(
            id: "enroll1",
            userId: "user2",
            programId: "kungfu-program",
            currentRank: "blue2",
            rankDate: Date()
        )
        
        let enrollment2 = Enrollment(
            id: "enroll2",
            userId: "user3",
            programId: "kungfu-program",
            currentRank: "white",
            rankDate: Date()
        )
        
        enrollments["enroll1"] = enrollment1
        enrollments["enroll2"] = enrollment2
        
        // Sample progress records
        let progress1 = ProgramProgress(
            id: "progress1",
            userId: "user2",
            programId: "kungfu-program",
            currentRankId: "blue2"
        )
        
        progressRecords["progress1"] = progress1
    }
}