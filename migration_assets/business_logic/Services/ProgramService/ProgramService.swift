import Foundation
import Combine

// MARK: - Program Service Protocol
public protocol ProgramService {
    
    // MARK: - Program Management
    func createProgram(_ program: Program) async throws -> Program
    func getProgram(id: String) async throws -> Program?
    func updateProgram(_ program: Program) async throws -> Program
    func deleteProgram(id: String) async throws
    func getAllPrograms() async throws -> [Program]
    func getActivePrograms() async throws -> [Program]
    
    // MARK: - Program Search and Filtering
    func searchPrograms(query: String, limit: Int) async throws -> [Program]
    func getProgramsByType(_ type: ProgramType) async throws -> [Program]
    func getProgramsByInstructor(instructorId: String) async throws -> [Program]
    func getProgramsByAccessLevel(_ accessLevel: AccessLevel) async throws -> [Program]
    
    // MARK: - Rank Management
    func getRanksForProgram(programId: String) async throws -> [Rank]
    func addRankToProgram(programId: String, rank: Rank) async throws -> Program
    func updateRankInProgram(programId: String, rank: Rank) async throws -> Program
    func removeRankFromProgram(programId: String, rankId: String) async throws -> Program
    func getNextRank(programId: String, currentRank: String) async throws -> Rank?
    
    // MARK: - Curriculum Management
    func getCurriculumForProgram(programId: String) async throws -> [CurriculumItem]
    func getCurriculumForRank(programId: String, rankId: String) async throws -> [CurriculumItem]
    func addCurriculumItem(programId: String, item: CurriculumItem) async throws -> Program
    func updateCurriculumItem(programId: String, item: CurriculumItem) async throws -> Program
    func removeCurriculumItem(programId: String, itemId: String) async throws -> Program
    
    // MARK: - Enrollment Management
    func getEnrollmentsForProgram(programId: String) async throws -> [Enrollment]
    func getEnrollmentForUser(userId: String, programId: String) async throws -> Enrollment?
    func createEnrollment(_ enrollment: Enrollment) async throws -> Enrollment
    func updateEnrollment(_ enrollment: Enrollment) async throws -> Enrollment
    func deleteEnrollment(id: String) async throws
    
    // MARK: - Progress Tracking
    func getProgressForUser(userId: String, programId: String) async throws -> ProgramProgress?
    func updateUserProgress(userId: String, programId: String, progress: ProgramProgress) async throws -> ProgramProgress
    func getProgressForRank(userId: String, programId: String, rankId: String) async throws -> RankProgress?
    func updateRankProgress(userId: String, programId: String, rankId: String, progress: RankProgress) async throws -> RankProgress
    
    // MARK: - Instructor Management
    func getInstructorsForProgram(programId: String) async throws -> [UserProfile]
    func addInstructorToProgram(programId: String, instructorId: String) async throws -> Program
    func removeInstructorFromProgram(programId: String, instructorId: String) async throws -> Program
    
    // MARK: - Publisher for Real-time Updates
    var programUpdatesPublisher: AnyPublisher<Program, Never> { get }
    var enrollmentUpdatesPublisher: AnyPublisher<Enrollment, Never> { get }
    var progressUpdatesPublisher: AnyPublisher<ProgramProgress, Never> { get }
}





// MARK: - Program Service Errors
public enum ProgramServiceError: LocalizedError, Equatable {
    case programNotFound(id: String)
    case duplicateProgram(name: String)
    case invalidProgramData(field: String)
    case rankNotFound(id: String, programId: String)
    case invalidRankOrder(rank: String, programId: String)
    case curriculumItemNotFound(id: String)
    case invalidCurriculumData(field: String)
    case enrollmentNotFound(id: String)
    case duplicateEnrollment(userId: String, programId: String)
    case progressNotFound(userId: String, programId: String)
    case invalidProgressData(field: String)
    case instructorNotFound(id: String)
    case insufficientPermissions(userId: String, operation: String)
    case programNotActive(id: String)
    case prerequisitesNotMet(itemId: String, missing: [String])
    case networkError(underlying: Error)
    case unknown(underlying: Error)
    
    public var errorDescription: String? {
        switch self {
        case .programNotFound(let id):
            return "Program not found: \(id)"
        case .duplicateProgram(let name):
            return "Program with name '\(name)' already exists"
        case .invalidProgramData(let field):
            return "Invalid program data for field: \(field)"
        case .rankNotFound(let id, let programId):
            return "Rank \(id) not found in program \(programId)"
        case .invalidRankOrder(let rank, let programId):
            return "Invalid rank order for \(rank) in program \(programId)"
        case .curriculumItemNotFound(let id):
            return "Curriculum item not found: \(id)"
        case .invalidCurriculumData(let field):
            return "Invalid curriculum data for field: \(field)"
        case .enrollmentNotFound(let id):
            return "Enrollment not found: \(id)"
        case .duplicateEnrollment(let userId, let programId):
            return "User \(userId) is already enrolled in program \(programId)"
        case .progressNotFound(let userId, let programId):
            return "Progress not found for user \(userId) in program \(programId)"
        case .invalidProgressData(let field):
            return "Invalid progress data for field: \(field)"
        case .instructorNotFound(let id):
            return "Instructor not found: \(id)"
        case .insufficientPermissions(let userId, let operation):
            return "User \(userId) has insufficient permissions for operation: \(operation)"
        case .programNotActive(let id):
            return "Program is not active: \(id)"
        case .prerequisitesNotMet(let itemId, let missing):
            return "Prerequisites not met for item \(itemId): \(missing.joined(separator: ", "))"
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .unknown(let underlying):
            return "Unknown error: \(underlying.localizedDescription)"
        }
    }
    
    public static func == (lhs: ProgramServiceError, rhs: ProgramServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.programNotFound(let lhsId), .programNotFound(let rhsId)):
            return lhsId == rhsId
        case (.duplicateProgram(let lhsName), .duplicateProgram(let rhsName)):
            return lhsName == rhsName
        case (.invalidProgramData(let lhsField), .invalidProgramData(let rhsField)):
            return lhsField == rhsField
        case (.rankNotFound(let lhsId, let lhsProgramId), .rankNotFound(let rhsId, let rhsProgramId)):
            return lhsId == rhsId && lhsProgramId == rhsProgramId
        case (.invalidRankOrder(let lhsRank, let lhsProgramId), .invalidRankOrder(let rhsRank, let rhsProgramId)):
            return lhsRank == rhsRank && lhsProgramId == rhsProgramId
        case (.curriculumItemNotFound(let lhsId), .curriculumItemNotFound(let rhsId)):
            return lhsId == rhsId
        case (.invalidCurriculumData(let lhsField), .invalidCurriculumData(let rhsField)):
            return lhsField == rhsField
        case (.enrollmentNotFound(let lhsId), .enrollmentNotFound(let rhsId)):
            return lhsId == rhsId
        case (.duplicateEnrollment(let lhsUserId, let lhsProgramId), .duplicateEnrollment(let rhsUserId, let rhsProgramId)):
            return lhsUserId == rhsUserId && lhsProgramId == rhsProgramId
        case (.progressNotFound(let lhsUserId, let lhsProgramId), .progressNotFound(let rhsUserId, let rhsProgramId)):
            return lhsUserId == rhsUserId && lhsProgramId == rhsProgramId
        case (.invalidProgressData(let lhsField), .invalidProgressData(let rhsField)):
            return lhsField == rhsField
        case (.instructorNotFound(let lhsId), .instructorNotFound(let rhsId)):
            return lhsId == rhsId
        case (.insufficientPermissions(let lhsUserId, let lhsOperation), .insufficientPermissions(let rhsUserId, let rhsOperation)):
            return lhsUserId == rhsUserId && lhsOperation == rhsOperation
        case (.programNotActive(let lhsId), .programNotActive(let rhsId)):
            return lhsId == rhsId
        case (.prerequisitesNotMet(let lhsItemId, let lhsMissing), .prerequisitesNotMet(let rhsItemId, let rhsMissing)):
            return lhsItemId == rhsItemId && lhsMissing == rhsMissing
        default:
            return false
        }
    }
}