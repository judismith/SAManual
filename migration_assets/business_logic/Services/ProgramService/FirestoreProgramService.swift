import Foundation
import Combine
import FirebaseFirestore

// MARK: - Firestore Program Service Implementation
public final class FirestoreProgramService: ProgramService {
    
    // MARK: - Firestore Configuration
    private let db: Firestore
    private let programsCollection: CollectionReference
    private let enrollmentsCollection: CollectionReference
    private let progressCollection: CollectionReference
    private let rankProgressCollection: CollectionReference
    
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
    
    // MARK: - Cache
    private var programCache: [String: Program] = [:]
    private var enrollmentCache: [String: Enrollment] = [:]
    private let cacheQueue = DispatchQueue(label: "com.sakungfujournal.programservice.cache", attributes: .concurrent)
    
    // MARK: - Initialization
    public init(firestore: Firestore = Firestore.firestore()) {
        self.db = firestore
        self.programsCollection = db.collection("programs")
        self.enrollmentsCollection = db.collection("enrollments")
        self.progressCollection = db.collection("programProgress")
        self.rankProgressCollection = db.collection("rankProgress")
    }
    
    // MARK: - Program Management
    public func createProgram(_ program: Program) async throws -> Program {
        do {
            // Check for duplicate name
            let existingProgram = try await getProgramByName(program.name)
            if existingProgram != nil {
                throw ProgramServiceError.duplicateProgram(name: program.name)
            }
            
            // Create program document
            var newProgram = program
            newProgram.updatedAt = Date()
            
            let programData = try newProgram.toFirestoreData()
            try await programsCollection.document(newProgram.id).setData(programData)
            
            // Update cache
            cacheQueue.async(flags: .barrier) {
                self.programCache[newProgram.id] = newProgram
            }
            
            // Notify subscribers
            programUpdatesSubject.send(newProgram)
            
            return newProgram
            
        } catch let error as ProgramServiceError {
            throw error
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    public func getProgram(id: String) async throws -> Program? {
        // Check cache first
        return await cacheQueue.sync {
            if let cachedProgram = programCache[id] {
                return cachedProgram
            }
            return nil
        } ?? {
            do {
                let document = try await programsCollection.document(id).getDocument()
                
                guard document.exists, let data = document.data() else {
                    return nil
                }
                
                let program = try Program.from(firestoreData: data, id: id)
                
                // Update cache
                cacheQueue.async(flags: .barrier) {
                    self.programCache[id] = program
                }
                
                return program
                
            } catch {
                throw convertFirestoreError(error)
            }
        }()
    }
    
    public func updateProgram(_ program: Program) async throws -> Program {
        do {
            // Verify program exists
            let existingDoc = try await programsCollection.document(program.id).getDocument()
            guard existingDoc.exists else {
                throw ProgramServiceError.programNotFound(id: program.id)
            }
            
            // Update program
            var updatedProgram = program
            updatedProgram.updatedAt = Date()
            
            let programData = try updatedProgram.toFirestoreData()
            try await programsCollection.document(updatedProgram.id).updateData(programData)
            
            // Update cache
            cacheQueue.async(flags: .barrier) {
                self.programCache[updatedProgram.id] = updatedProgram
            }
            
            // Notify subscribers
            programUpdatesSubject.send(updatedProgram)
            
            return updatedProgram
            
        } catch let error as ProgramServiceError {
            throw error
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    public func deleteProgram(id: String) async throws {
        do {
            // Check if program exists
            let existingDoc = try await programsCollection.document(id).getDocument()
            guard existingDoc.exists else {
                throw ProgramServiceError.programNotFound(id: id)
            }
            
            // Check for active enrollments
            let enrollmentsQuery = enrollmentsCollection
                .whereField("programId", isEqualTo: id)
                .whereField("enrolled", isEqualTo: true)
            
            let enrollmentSnapshot = try await enrollmentsQuery.getDocuments()
            if !enrollmentSnapshot.documents.isEmpty {
                throw ProgramServiceError.programHasActiveEnrollments(id: id)
            }
            
            // Delete program
            try await programsCollection.document(id).delete()
            
            // Clean up related data
            try await deleteRelatedProgramData(programId: id)
            
            // Update cache
            cacheQueue.async(flags: .barrier) {
                self.programCache.removeValue(forKey: id)
            }
            
        } catch let error as ProgramServiceError {
            throw error
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    public func getAllPrograms() async throws -> [Program] {
        do {
            let snapshot = try await programsCollection
                .whereField("isActive", isEqualTo: true)
                .order(by: "name")
                .getDocuments()
            
            var programs: [Program] = []
            
            for document in snapshot.documents {
                if let program = try? Program.from(firestoreData: document.data(), id: document.documentID) {
                    programs.append(program)
                    
                    // Update cache
                    cacheQueue.async(flags: .barrier) {
                        self.programCache[program.id] = program
                    }
                }
            }
            
            return programs
            
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    public func getProgramsByCategory(_ category: ProgramType) async throws -> [Program] {
        do {
            let snapshot = try await programsCollection
                .whereField("category", isEqualTo: category.rawValue)
                .whereField("isActive", isEqualTo: true)
                .order(by: "name")
                .getDocuments()
            
            var programs: [Program] = []
            
            for document in snapshot.documents {
                if let program = try? Program.from(firestoreData: document.data(), id: document.documentID) {
                    programs.append(program)
                    
                    // Update cache
                    cacheQueue.async(flags: .barrier) {
                        self.programCache[program.id] = program
                    }
                }
            }
            
            return programs
            
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    public func searchPrograms(query: String, limit: Int) async throws -> [Program] {
        do {
            // Firestore doesn't support full-text search natively
            // This is a simple implementation using name and description contains
            let snapshot = try await programsCollection
                .whereField("isActive", isEqualTo: true)
                .limit(to: limit * 2) // Get more to filter locally
                .getDocuments()
            
            var programs: [Program] = []
            let lowercaseQuery = query.lowercased()
            
            for document in snapshot.documents {
                if let program = try? Program.from(firestoreData: document.data(), id: document.documentID) {
                    // Simple text matching
                    if program.name.lowercased().contains(lowercaseQuery) ||
                       program.description.lowercased().contains(lowercaseQuery) {
                        programs.append(program)
                        
                        // Update cache
                        cacheQueue.async(flags: .barrier) {
                            self.programCache[program.id] = program
                        }
                    }
                }
            }
            
            return Array(programs.prefix(limit))
            
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    // MARK: - Enrollment Management
    public func enrollUser(userId: String, programId: String, startingRank: String) async throws -> Enrollment {
        do {
            // Verify program exists
            guard let program = try await getProgram(id: programId) else {
                throw ProgramServiceError.programNotFound(id: programId)
            }
            
            // Check if user is already enrolled
            let existingEnrollment = try await getUserEnrollment(userId: userId, programId: programId)
            if existingEnrollment?.enrolled == true {
                throw ProgramServiceError.userAlreadyEnrolled(userId: userId, programId: programId)
            }
            
            // Validate starting rank
            guard program.ranks.contains(where: { $0.name == startingRank }) else {
                throw ProgramServiceError.invalidRank(rank: startingRank, programId: programId)
            }
            
            // Create enrollment
            let enrollment = Enrollment(
                userId: userId,
                programId: programId,
                enrolled: true,
                enrollmentDate: Date(),
                currentRank: startingRank,
                rankDate: Date(),
                isActive: true
            )
            
            let enrollmentData = try enrollment.toFirestoreData()
            try await enrollmentsCollection.document(enrollment.id).setData(enrollmentData)
            
            // Update cache
            cacheQueue.async(flags: .barrier) {
                self.enrollmentCache[enrollment.id] = enrollment
            }
            
            // Notify subscribers
            enrollmentUpdatesSubject.send(enrollment)
            
            return enrollment
            
        } catch let error as ProgramServiceError {
            throw error
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    public func unenrollUser(userId: String, programId: String) async throws {
        do {
            guard let enrollment = try await getUserEnrollment(userId: userId, programId: programId) else {
                throw ProgramServiceError.enrollmentNotFound(userId: userId, programId: programId)
            }
            
            // Update enrollment to inactive
            var updatedEnrollment = enrollment
            updatedEnrollment.enrolled = false
            updatedEnrollment.isActive = false
            
            let enrollmentData = try updatedEnrollment.toFirestoreData()
            try await enrollmentsCollection.document(enrollment.id).updateData(enrollmentData)
            
            // Update cache
            cacheQueue.async(flags: .barrier) {
                self.enrollmentCache[enrollment.id] = updatedEnrollment
            }
            
            // Notify subscribers
            enrollmentUpdatesSubject.send(updatedEnrollment)
            
        } catch let error as ProgramServiceError {
            throw error
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    public func updateEnrollment(_ enrollment: Enrollment) async throws -> Enrollment {
        do {
            // Verify enrollment exists
            let existingDoc = try await enrollmentsCollection.document(enrollment.id).getDocument()
            guard existingDoc.exists else {
                throw ProgramServiceError.enrollmentNotFound(userId: enrollment.userId, programId: enrollment.programId)
            }
            
            // Update enrollment
            let enrollmentData = try enrollment.toFirestoreData()
            try await enrollmentsCollection.document(enrollment.id).updateData(enrollmentData)
            
            // Update cache
            cacheQueue.async(flags: .barrier) {
                self.enrollmentCache[enrollment.id] = enrollment
            }
            
            // Notify subscribers
            enrollmentUpdatesSubject.send(enrollment)
            
            return enrollment
            
        } catch let error as ProgramServiceError {
            throw error
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    public func getUserEnrollments(userId: String) async throws -> [Enrollment] {
        do {
            let snapshot = try await enrollmentsCollection
                .whereField("userId", isEqualTo: userId)
                .whereField("enrolled", isEqualTo: true)
                .getDocuments()
            
            var enrollments: [Enrollment] = []
            
            for document in snapshot.documents {
                if let enrollment = try? Enrollment.from(firestoreData: document.data(), id: document.documentID) {
                    enrollments.append(enrollment)
                    
                    // Update cache
                    cacheQueue.async(flags: .barrier) {
                        self.enrollmentCache[enrollment.id] = enrollment
                    }
                }
            }
            
            return enrollments
            
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    public func getProgramEnrollments(programId: String) async throws -> [Enrollment] {
        do {
            let snapshot = try await enrollmentsCollection
                .whereField("programId", isEqualTo: programId)
                .whereField("enrolled", isEqualTo: true)
                .getDocuments()
            
            var enrollments: [Enrollment] = []
            
            for document in snapshot.documents {
                if let enrollment = try? Enrollment.from(firestoreData: document.data(), id: document.documentID) {
                    enrollments.append(enrollment)
                    
                    // Update cache
                    cacheQueue.async(flags: .barrier) {
                        self.enrollmentCache[enrollment.id] = enrollment
                    }
                }
            }
            
            return enrollments
            
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    public func updateUserRank(userId: String, programId: String, newRank: String) async throws -> Enrollment {
        do {
            guard let enrollment = try await getUserEnrollment(userId: userId, programId: programId) else {
                throw ProgramServiceError.enrollmentNotFound(userId: userId, programId: programId)
            }
            
            // Verify program and rank exist
            guard let program = try await getProgram(id: programId) else {
                throw ProgramServiceError.programNotFound(id: programId)
            }
            
            guard program.ranks.contains(where: { $0.name == newRank }) else {
                throw ProgramServiceError.invalidRank(rank: newRank, programId: programId)
            }
            
            // Update enrollment
            var updatedEnrollment = enrollment
            updatedEnrollment.currentRank = newRank
            updatedEnrollment.rankDate = Date()
            
            let enrollmentData = try updatedEnrollment.toFirestoreData()
            try await enrollmentsCollection.document(enrollment.id).updateData(enrollmentData)
            
            // Update cache
            cacheQueue.async(flags: .barrier) {
                self.enrollmentCache[enrollment.id] = updatedEnrollment
            }
            
            // Notify subscribers
            enrollmentUpdatesSubject.send(updatedEnrollment)
            
            return updatedEnrollment
            
        } catch let error as ProgramServiceError {
            throw error
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    // MARK: - Progress Tracking
    public func recordProgress(userId: String, programId: String, progress: ProgramProgress) async throws -> ProgramProgress {
        do {
            // Verify enrollment exists
            guard let _ = try await getUserEnrollment(userId: userId, programId: programId) else {
                throw ProgramServiceError.enrollmentNotFound(userId: userId, programId: programId)
            }
            
            var newProgress = progress
            newProgress.timestamp = Date()
            
            let progressData = try newProgress.toFirestoreData()
            try await progressCollection.document(newProgress.id).setData(progressData)
            
            // Notify subscribers
            progressUpdatesSubject.send(newProgress)
            
            return newProgress
            
        } catch let error as ProgramServiceError {
            throw error
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    public func getUserProgress(userId: String, programId: String, limit: Int) async throws -> [ProgramProgress] {
        do {
            let snapshot = try await progressCollection
                .whereField("userId", isEqualTo: userId)
                .whereField("programId", isEqualTo: programId)
                .order(by: "timestamp", descending: true)
                .limit(to: limit)
                .getDocuments()
            
            var progressRecords: [ProgramProgress] = []
            
            for document in snapshot.documents {
                if let progress = try? ProgramProgress.from(firestoreData: document.data(), id: document.documentID) {
                    progressRecords.append(progress)
                }
            }
            
            return progressRecords
            
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    public func getProgressForUser(userId: String, programId: String) async throws -> ProgramProgress? {
        do {
            let snapshot = try await progressCollection
                .whereField("userId", isEqualTo: userId)
                .whereField("programId", isEqualTo: programId)
                .order(by: "timestamp", descending: true)
                .limit(to: 1)
                .getDocuments()
            
            guard let document = snapshot.documents.first else {
                return nil
            }
            
            return try? ProgramProgress.from(firestoreData: document.data(), id: document.documentID)
            
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    public func updateUserProgress(userId: String, programId: String, progress: ProgramProgress) async throws -> ProgramProgress {
        return try await recordProgress(userId: userId, programId: programId, progress: progress)
    }
    
    public func getProgressForRank(userId: String, programId: String, rankId: String) async throws -> RankProgress? {
        return try await getRankProgress(userId: userId, programId: programId, rankId: rankId)
    }
    
    public func updateRankProgress(userId: String, programId: String, rankId: String, progress: RankProgress) async throws -> RankProgress {
        do {
            // Verify enrollment and rank
            guard let enrollment = try await getUserEnrollment(userId: userId, programId: programId) else {
                throw ProgramServiceError.enrollmentNotFound(userId: userId, programId: programId)
            }
            
            guard let program = try await getProgram(id: programId) else {
                throw ProgramServiceError.programNotFound(id: programId)
            }
            
            guard program.ranks.contains(where: { $0.name == rankId }) else {
                throw ProgramServiceError.invalidRank(rank: rankId, programId: programId)
            }
            
            var updatedProgress = progress
            updatedProgress.lastUpdated = Date()
            
            let progressId = "\(userId)_\(programId)_\(rankId)"
            let progressData = try updatedProgress.toFirestoreData()
            try await rankProgressCollection.document(progressId).setData(progressData, merge: true)
            
            return updatedProgress
            
        } catch let error as ProgramServiceError {
            throw error
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    public func getRankProgress(userId: String, programId: String, rankId: String) async throws -> RankProgress? {
        do {
            let progressId = "\(userId)_\(programId)_\(rankId)"
            let document = try await rankProgressCollection.document(progressId).getDocument()
            
            guard document.exists, let data = document.data() else {
                return nil
            }
            
            return try RankProgress.from(firestoreData: data, id: progressId)
            
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    public func getAllRankProgress(userId: String, programId: String) async throws -> [RankProgress] {
        do {
            let snapshot = try await rankProgressCollection
                .whereField("userId", isEqualTo: userId)
                .whereField("programId", isEqualTo: programId)
                .getDocuments()
            
            var progressRecords: [RankProgress] = []
            
            for document in snapshot.documents {
                if let progress = try? RankProgress.from(firestoreData: document.data(), id: document.documentID) {
                    progressRecords.append(progress)
                }
            }
            
            return progressRecords
            
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    // MARK: - Analytics and Reporting
    public func getProgramAnalytics(programId: String, dateRange: DateRange) async throws -> ProgramAnalytics {
        do {
            // Get program info
            guard let program = try await getProgram(id: programId) else {
                throw ProgramServiceError.programNotFound(id: programId)
            }
            
            // Get enrollment count
            let enrollmentCount = try await getProgramEnrollmentCount(programId: programId)
            
            // Get progress data
            let progressData = try await getProgramProgressData(programId: programId, dateRange: dateRange)
            
            // Calculate completion rates
            let completionRates = try await calculateCompletionRates(programId: programId)
            
            // Get rank distribution
            let rankDistribution = try await getRankDistribution(programId: programId)
            
            return ProgramAnalytics(
                programId: programId,
                programName: program.name,
                totalEnrollments: enrollmentCount,
                activeEnrollments: enrollmentCount, // For now, same as total
                completionRate: completionRates.overall,
                averageProgressTime: progressData.averageTime,
                rankDistribution: rankDistribution,
                dailyActivityCounts: progressData.dailyActivity,
                topPerformers: [], // Would require user data integration
                strugglingStudents: [], // Would require user data integration
                dateRange: dateRange
            )
            
        } catch let error as ProgramServiceError {
            throw error
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    public func getUserAnalytics(userId: String, programId: String) async throws -> UserProgramAnalytics {
        do {
            // Get enrollment
            guard let enrollment = try await getUserEnrollment(userId: userId, programId: programId) else {
                throw ProgramServiceError.enrollmentNotFound(userId: userId, programId: programId)
            }
            
            // Get progress records
            let progressRecords = try await getUserProgress(userId: userId, programId: programId, limit: 100)
            
            // Get rank progress
            let rankProgresses = try await getAllRankProgress(userId: userId, programId: programId)
            
            // Calculate statistics
            let totalSessions = progressRecords.count
            let totalPracticeTime = progressRecords.reduce(0) { $0 + ($1.duration ?? 0) }
            let averageSessionDuration = totalSessions > 0 ? totalPracticeTime / Double(totalSessions) : 0
            
            // Calculate current rank progress
            let currentRankProgress = rankProgresses.first { $0.rank == enrollment.currentRank }
            let currentRankCompletion = currentRankProgress?.overallProgress ?? 0.0
            
            return UserProgramAnalytics(
                userId: userId,
                programId: programId,
                enrollmentDate: enrollment.enrollmentDate,
                currentRank: enrollment.currentRank ?? "",
                totalSessions: totalSessions,
                totalPracticeTime: totalPracticeTime,
                averageSessionDuration: averageSessionDuration,
                currentRankProgress: currentRankCompletion,
                rankProgresses: rankProgresses,
                recentActivity: Array(progressRecords.prefix(10)),
                achievements: [] // Would require achievements system
            )
            
        } catch let error as ProgramServiceError {
            throw error
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    // MARK: - Enrollment Management Additional Methods
    public func deleteEnrollment(id: String) async throws {
        do {
            let document = try await enrollmentsCollection.document(id).getDocument()
            
            guard document.exists else {
                throw ProgramServiceError.enrollmentNotFound(userId: "", programId: "")
            }
            
            try await enrollmentsCollection.document(id).delete()
            
            // Update cache
            cacheQueue.async(flags: .barrier) {
                self.enrollmentCache.removeValue(forKey: id)
            }
            
        } catch let error as ProgramServiceError {
            throw error
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    // MARK: - Instructor Management
    public func getInstructorsForProgram(programId: String) async throws -> [UserProfile] {
        // This would require integration with UserService
        // For now, return empty array as instructors are managed separately
        return []
    }
    
    public func addInstructorToProgram(programId: String, instructorId: String) async throws -> Program {
        do {
            guard let program = try await getProgram(id: programId) else {
                throw ProgramServiceError.programNotFound(id: programId)
            }
            
            // In a real implementation, this would update the program's instructor list
            // For now, just return the program unchanged
            return program
            
        } catch let error as ProgramServiceError {
            throw error
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    public func removeInstructorFromProgram(programId: String, instructorId: String) async throws -> Program {
        do {
            guard let program = try await getProgram(id: programId) else {
                throw ProgramServiceError.programNotFound(id: programId)
            }
            
            // In a real implementation, this would update the program's instructor list
            // For now, just return the program unchanged
            return program
            
        } catch let error as ProgramServiceError {
            throw error
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    // MARK: - Additional Protocol Requirements
    
    public func getActivePrograms() async throws -> [Program] {
        do {
            let snapshot = try await programsCollection
                .whereField("isActive", isEqualTo: true)
                .whereField("status", isEqualTo: "active")
                .order(by: "name")
                .getDocuments()
            
            var programs: [Program] = []
            
            for document in snapshot.documents {
                if let program = try? Program.from(firestoreData: document.data(), id: document.documentID) {
                    programs.append(program)
                }
            }
            
            return programs
            
        } catch {
            throw convertFirestoreError(error)
        }
    }
    
    public func getProgramsByType(_ type: ProgramType) async throws -> [Program] {
        return try await getProgramsByCategory(type)
    }
    
    public func getProgramsByInstructor(instructorId: String) async throws -> [Program] {
        // TODO: Implement when instructor tracking is added to programs
        return []
    }
    
    public func getProgramsByAccessLevel(_ accessLevel: AccessLevel) async throws -> [Program] {
        // TODO: Implement when access level tracking is added to programs
        return try await getAllPrograms()
    }
    
    public func getRanksForProgram(programId: String) async throws -> [Rank] {
        guard let program = try await getProgram(id: programId) else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        return program.ranks
    }
    
    public func addRankToProgram(programId: String, rank: Rank) async throws -> Program {
        guard var program = try await getProgram(id: programId) else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        program.ranks.append(rank)
        return try await updateProgram(program)
    }
    
    public func updateRankInProgram(programId: String, rank: Rank) async throws -> Program {
        guard var program = try await getProgram(id: programId) else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        if let index = program.ranks.firstIndex(where: { $0.id == rank.id }) {
            program.ranks[index] = rank
            return try await updateProgram(program)
        } else {
            throw ProgramServiceError.invalidProgramData(field: "rank", reason: "Rank not found")
        }
    }
    
    public func removeRankFromProgram(programId: String, rankId: String) async throws -> Program {
        guard var program = try await getProgram(id: programId) else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        program.ranks.removeAll { $0.id == rankId }
        return try await updateProgram(program)
    }
    
    public func getNextRank(programId: String, currentRank: String) async throws -> Rank? {
        guard let program = try await getProgram(id: programId) else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        
        // Find current rank index
        guard let currentIndex = program.ranks.firstIndex(where: { $0.name == currentRank }) else {
            return nil
        }
        
        // Return next rank if exists
        let nextIndex = currentIndex + 1
        return nextIndex < program.ranks.count ? program.ranks[nextIndex] : nil
    }
    
    public func getCurriculumForProgram(programId: String) async throws -> [CurriculumItem] {
        // TODO: Implement curriculum management
        return []
    }
    
    public func getCurriculumForRank(programId: String, rankId: String) async throws -> [CurriculumItem] {
        // TODO: Implement curriculum management
        return []
    }
    
    public func addCurriculumItem(programId: String, item: CurriculumItem) async throws -> Program {
        guard let program = try await getProgram(id: programId) else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        // TODO: Implement curriculum management
        return program
    }
    
    public func updateCurriculumItem(programId: String, item: CurriculumItem) async throws -> Program {
        guard let program = try await getProgram(id: programId) else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        // TODO: Implement curriculum management
        return program
    }
    
    public func removeCurriculumItem(programId: String, itemId: String) async throws -> Program {
        guard let program = try await getProgram(id: programId) else {
            throw ProgramServiceError.programNotFound(id: programId)
        }
        // TODO: Implement curriculum management
        return program
    }
    
    public func getEnrollmentsForProgram(programId: String) async throws -> [Enrollment] {
        return try await getProgramEnrollments(programId: programId)
    }
    
    public func getEnrollmentForUser(userId: String, programId: String) async throws -> Enrollment? {
        return try await getUserEnrollment(userId: userId, programId: programId)
    }
    
    public func createEnrollment(_ enrollment: Enrollment) async throws -> Enrollment {
        return try await enrollUser(
            userId: enrollment.userId,
            programId: enrollment.programId,
            startingRank: enrollment.currentRank ?? "white"
        )
    }
    
    // MARK: - Cache Management
    public func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.programCache.removeAll()
            self.enrollmentCache.removeAll()
        }
    }
    
    // MARK: - Private Helper Methods
    private func getUserEnrollment(userId: String, programId: String) async throws -> Enrollment? {
        // Check cache first
        let cachedEnrollment = await cacheQueue.sync {
            return enrollmentCache.values.first { $0.userId == userId && $0.programId == programId && $0.enrolled }
        }
        
        if let cached = cachedEnrollment {
            return cached
        }
        
        // Query Firestore
        let snapshot = try await enrollmentsCollection
            .whereField("userId", isEqualTo: userId)
            .whereField("programId", isEqualTo: programId)
            .whereField("enrolled", isEqualTo: true)
            .limit(to: 1)
            .getDocuments()
        
        guard let document = snapshot.documents.first else {
            return nil
        }
        
        let enrollment = try Enrollment.from(firestoreData: document.data(), id: document.documentID)
        
        // Update cache
        cacheQueue.async(flags: .barrier) {
            self.enrollmentCache[enrollment.id] = enrollment
        }
        
        return enrollment
    }
    
    private func getProgramByName(_ name: String) async throws -> Program? {
        // Check cache first
        let cachedProgram = await cacheQueue.sync {
            return programCache.values.first { $0.name == name }
        }
        
        if let cached = cachedProgram {
            return cached
        }
        
        // Query Firestore
        let snapshot = try await programsCollection
            .whereField("name", isEqualTo: name)
            .limit(to: 1)
            .getDocuments()
        
        guard let document = snapshot.documents.first else {
            return nil
        }
        
        let program = try Program.from(firestoreData: document.data(), id: document.documentID)
        
        // Update cache
        cacheQueue.async(flags: .barrier) {
            self.programCache[program.id] = program
        }
        
        return program
    }
    
    private func deleteRelatedProgramData(programId: String) async throws {
        // Delete enrollments
        let enrollmentsSnapshot = try await enrollmentsCollection
            .whereField("programId", isEqualTo: programId)
            .getDocuments()
        
        for document in enrollmentsSnapshot.documents {
            try await document.reference.delete()
        }
        
        // Delete progress records
        let progressSnapshot = try await progressCollection
            .whereField("programId", isEqualTo: programId)
            .getDocuments()
        
        for document in progressSnapshot.documents {
            try await document.reference.delete()
        }
        
        // Delete rank progress
        let rankProgressSnapshot = try await rankProgressCollection
            .whereField("programId", isEqualTo: programId)
            .getDocuments()
        
        for document in rankProgressSnapshot.documents {
            try await document.reference.delete()
        }
    }
    
    private func getProgramEnrollmentCount(programId: String) async throws -> Int {
        let snapshot = try await enrollmentsCollection
            .whereField("programId", isEqualTo: programId)
            .whereField("enrolled", isEqualTo: true)
            .getDocuments()
        
        return snapshot.documents.count
    }
    
    private func getProgramProgressData(programId: String, dateRange: DateRange) async throws -> (averageTime: Double, dailyActivity: [String: Int]) {
        let snapshot = try await progressCollection
            .whereField("programId", isEqualTo: programId)
            .whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: dateRange.startDate))
            .whereField("timestamp", isLessThanOrEqualTo: Timestamp(date: dateRange.endDate))
            .getDocuments()
        
        var totalDuration: Double = 0
        var sessionCount = 0
        var dailyActivity: [String: Int] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for document in snapshot.documents {
            if let progress = try? ProgramProgress.from(firestoreData: document.data(), id: document.documentID) {
                if let duration = progress.duration {
                    totalDuration += duration
                    sessionCount += 1
                }
                
                let dateKey = dateFormatter.string(from: progress.timestamp)
                dailyActivity[dateKey, default: 0] += 1
            }
        }
        
        let averageTime = sessionCount > 0 ? totalDuration / Double(sessionCount) : 0
        return (averageTime, dailyActivity)
    }
    
    private func calculateCompletionRates(programId: String) async throws -> (overall: Double, byRank: [String: Double]) {
        // This would require more complex logic to determine what "completion" means
        // For now, return mock data
        return (overall: 0.75, byRank: [:])
    }
    
    private func getRankDistribution(programId: String) async throws -> [String: Int] {
        let snapshot = try await enrollmentsCollection
            .whereField("programId", isEqualTo: programId)
            .whereField("enrolled", isEqualTo: true)
            .getDocuments()
        
        var distribution: [String: Int] = [:]
        
        for document in snapshot.documents {
            if let enrollment = try? Enrollment.from(firestoreData: document.data(), id: document.documentID),
               let currentRank = enrollment.currentRank {
                distribution[currentRank, default: 0] += 1
            }
        }
        
        return distribution
    }
    
    private func convertFirestoreError(_ error: Error) -> ProgramServiceError {
        if let firestoreError = error as NSError? {
            switch firestoreError.code {
            case FirestoreErrorCode.unavailable.rawValue, FirestoreErrorCode.networkError.rawValue:
                return .networkError(underlying: error)
            case FirestoreErrorCode.permissionDenied.rawValue:
                return .insufficientPermissions(operation: "Firestore operation")
            case FirestoreErrorCode.notFound.rawValue:
                return .unknown(underlying: error) // Handle specifically in calling context
            default:
                return .unknown(underlying: error)
            }
        }
        return .unknown(underlying: error)
    }
}

// MARK: - Model Extensions for Firestore
extension Program {
    func toFirestoreData() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        
        return [
            "name": name,
            "description": description,
            "category": category.rawValue,
            "isActive": isActive,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "ranks": try ranks.map { rank in
                [
                    "id": rank.id,
                    "name": rank.name,
                    "description": rank.description,
                    "color": rank.color,
                    "requirements": rank.requirements,
                    "forms": try rank.forms.map { form in
                        [
                            "id": form.id,
                            "name": form.name,
                            "description": form.description,
                            "difficulty": form.difficulty.rawValue,
                            "estimatedDuration": form.estimatedDuration,
                            "videoURL": form.videoURL ?? "",
                            "techniques": try form.techniques.map { technique in
                                [
                                    "id": technique.id,
                                    "name": technique.name,
                                    "description": technique.description,
                                    "category": technique.category.rawValue,
                                    "difficulty": technique.difficulty.rawValue,
                                    "instructions": technique.instructions,
                                    "tips": technique.tips,
                                    "commonMistakes": technique.commonMistakes,
                                    "videoURL": technique.videoURL ?? "",
                                    "imageURL": technique.imageURL ?? ""
                                ]
                            }
                        ]
                    }
                ]
            }
        ]
    }
    
    static func from(firestoreData: [String: Any], id: String) throws -> Program {
        guard let name = firestoreData["name"] as? String,
              let description = firestoreData["description"] as? String,
              let categoryString = firestoreData["category"] as? String,
              let category = ProgramType(rawValue: categoryString),
              let isActive = firestoreData["isActive"] as? Bool,
              let createdAtTimestamp = firestoreData["createdAt"] as? Timestamp,
              let updatedAtTimestamp = firestoreData["updatedAt"] as? Timestamp,
              let ranksData = firestoreData["ranks"] as? [[String: Any]] else {
            throw ProgramServiceError.invalidProgramData(field: "required fields")
        }
        
        let ranks = try ranksData.map { rankData -> Rank in
            try Rank.from(firestoreData: rankData)
        }
        
        return Program(
            id: id,
            name: name,
            description: description,
            category: category,
            ranks: ranks,
            isActive: isActive,
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: updatedAtTimestamp.dateValue()
        )
    }
}

extension Rank {
    static func from(firestoreData: [String: Any]) throws -> Rank {
        guard let id = firestoreData["id"] as? String,
              let name = firestoreData["name"] as? String,
              let description = firestoreData["description"] as? String,
              let color = firestoreData["color"] as? String,
              let requirements = firestoreData["requirements"] as? [String],
              let formsData = firestoreData["forms"] as? [[String: Any]] else {
            throw ProgramServiceError.invalidProgramData(field: "rank fields")
        }
        
        let forms = try formsData.map { formData -> Form in
            try Form.from(firestoreData: formData)
        }
        
        return Rank(
            id: id,
            name: name,
            description: description,
            color: color,
            requirements: requirements,
            forms: forms
        )
    }
}

extension Form {
    static func from(firestoreData: [String: Any]) throws -> Form {
        guard let id = firestoreData["id"] as? String,
              let name = firestoreData["name"] as? String,
              let description = firestoreData["description"] as? String,
              let difficultyString = firestoreData["difficulty"] as? String,
              let difficulty = Difficulty(rawValue: difficultyString),
              let estimatedDuration = firestoreData["estimatedDuration"] as? Double,
              let techniquesData = firestoreData["techniques"] as? [[String: Any]] else {
            throw ProgramServiceError.invalidProgramData(field: "form fields")
        }
        
        let videoURL = firestoreData["videoURL"] as? String
        
        let techniques = try techniquesData.map { techniqueData -> Technique in
            try Technique.from(firestoreData: techniqueData)
        }
        
        return Form(
            id: id,
            name: name,
            description: description,
            difficulty: difficulty,
            estimatedDuration: estimatedDuration,
            videoURL: videoURL,
            techniques: techniques
        )
    }
}

extension Technique {
    static func from(firestoreData: [String: Any]) throws -> Technique {
        guard let id = firestoreData["id"] as? String,
              let name = firestoreData["name"] as? String,
              let description = firestoreData["description"] as? String,
              let categoryString = firestoreData["category"] as? String,
              let category = TechniqueCategory(rawValue: categoryString),
              let difficultyString = firestoreData["difficulty"] as? String,
              let difficulty = Difficulty(rawValue: difficultyString),
              let instructions = firestoreData["instructions"] as? [String],
              let tips = firestoreData["tips"] as? [String],
              let commonMistakes = firestoreData["commonMistakes"] as? [String] else {
            throw ProgramServiceError.invalidProgramData(field: "technique fields")
        }
        
        let videoURL = firestoreData["videoURL"] as? String
        let imageURL = firestoreData["imageURL"] as? String
        
        return Technique(
            id: id,
            name: name,
            description: description,
            category: category,
            difficulty: difficulty,
            instructions: instructions,
            tips: tips,
            commonMistakes: commonMistakes,
            videoURL: videoURL,
            imageURL: imageURL
        )
    }
}

extension Enrollment {
    func toFirestoreData() throws -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "programId": programId,
            "enrolled": enrolled,
            "enrollmentDate": Timestamp(date: enrollmentDate),
            "isActive": isActive
        ]
        
        if let currentRank = currentRank {
            data["currentRank"] = currentRank
        }
        
        if let rankDate = rankDate {
            data["rankDate"] = Timestamp(date: rankDate)
        }
        
        return data
    }
    
    static func from(firestoreData: [String: Any], id: String) throws -> Enrollment {
        guard let userId = firestoreData["userId"] as? String,
              let programId = firestoreData["programId"] as? String,
              let enrolled = firestoreData["enrolled"] as? Bool,
              let enrollmentDateTimestamp = firestoreData["enrollmentDate"] as? Timestamp,
              let isActive = firestoreData["isActive"] as? Bool else {
            throw ProgramServiceError.invalidEnrollmentData(field: "required fields")
        }
        
        let currentRank = firestoreData["currentRank"] as? String
        let rankDate = (firestoreData["rankDate"] as? Timestamp)?.dateValue()
        
        return Enrollment(
            id: id,
            userId: userId,
            programId: programId,
            enrolled: enrolled,
            enrollmentDate: enrollmentDateTimestamp.dateValue(),
            currentRank: currentRank,
            rankDate: rankDate,
            isActive: isActive
        )
    }
}

extension ProgramProgress {
    func toFirestoreData() throws -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "programId": programId,
            "timestamp": Timestamp(date: timestamp),
            "progressType": progressType.rawValue
        ]
        
        if let sessionId = sessionId {
            data["sessionId"] = sessionId
        }
        
        if let rank = rank {
            data["rank"] = rank
        }
        
        if let form = form {
            data["form"] = form
        }
        
        if let technique = technique {
            data["technique"] = technique
        }
        
        if let duration = duration {
            data["duration"] = duration
        }
        
        if let score = score {
            data["score"] = score
        }
        
        if let notes = notes {
            data["notes"] = notes
        }
        
        if let metadata = metadata {
            data["metadata"] = metadata
        }
        
        return data
    }
    
    static func from(firestoreData: [String: Any], id: String) throws -> ProgramProgress {
        guard let userId = firestoreData["userId"] as? String,
              let programId = firestoreData["programId"] as? String,
              let timestampData = firestoreData["timestamp"] as? Timestamp,
              let progressTypeString = firestoreData["progressType"] as? String,
              let progressType = ProgressType(rawValue: progressTypeString) else {
            throw ProgramServiceError.invalidProgressData(field: "required fields")
        }
        
        return ProgramProgress(
            id: id,
            userId: userId,
            programId: programId,
            sessionId: firestoreData["sessionId"] as? String,
            rank: firestoreData["rank"] as? String,
            form: firestoreData["form"] as? String,
            technique: firestoreData["technique"] as? String,
            progressType: progressType,
            duration: firestoreData["duration"] as? Double,
            score: firestoreData["score"] as? Double,
            notes: firestoreData["notes"] as? String,
            metadata: firestoreData["metadata"] as? [String: Any],
            timestamp: timestampData.dateValue()
        )
    }
}

extension RankProgress {
    func toFirestoreData() throws -> [String: Any] {
        var data: [String: Any] = [
            "userId": userId,
            "programId": programId,
            "rank": rank,
            "overallProgress": overallProgress,
            "lastUpdated": Timestamp(date: lastUpdated)
        ]
        
        if !formProgresses.isEmpty {
            data["formProgresses"] = formProgresses
        }
        
        if !techniqueProgresses.isEmpty {
            data["techniqueProgresses"] = techniqueProgresses
        }
        
        if let notes = notes {
            data["notes"] = notes
        }
        
        return data
    }
    
    static func from(firestoreData: [String: Any], id: String) throws -> RankProgress {
        guard let userId = firestoreData["userId"] as? String,
              let programId = firestoreData["programId"] as? String,
              let rank = firestoreData["rank"] as? String,
              let overallProgress = firestoreData["overallProgress"] as? Double,
              let lastUpdatedTimestamp = firestoreData["lastUpdated"] as? Timestamp else {
            throw ProgramServiceError.invalidProgressData(field: "required fields")
        }
        
        return RankProgress(
            userId: userId,
            programId: programId,
            rank: rank,
            overallProgress: overallProgress,
            formProgresses: firestoreData["formProgresses"] as? [String: Double] ?? [:],
            techniqueProgresses: firestoreData["techniqueProgresses"] as? [String: Double] ?? [:],
            notes: firestoreData["notes"] as? String,
            lastUpdated: lastUpdatedTimestamp.dateValue()
        )
    }
}