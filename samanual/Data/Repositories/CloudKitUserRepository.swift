import Foundation
import CloudKit

// MARK: - CloudKit User Repository Implementation
public class CloudKitUserRepository: BaseUserRepository {
    
    // MARK: - Dependencies
    private let container: CKContainer
    private let database: CKDatabase
    private let recordType = "User"
    
    // MARK: - Initialization
    public init(container: CKContainer = CKContainer.default()) {
        self.container = container
        self.database = container.privateCloudDatabase
        super.init()
    }
    
    // MARK: - UserRepositoryProtocol Implementation
    
    public override func getCurrentUser() async throws -> User? {
        // Get current user ID from CloudKit
        let userRecordID = try await container.userRecordID()
        return try await getUser(id: userRecordID.recordName)
    }
    
    public override func getUser(id: String) async throws -> User {
        let recordID = CKRecord.ID(recordName: id)
        
        do {
            let record = try await database.record(for: recordID)
            let userDTO = try UserDTO.from(record)
            return try UserMapper.toDomain(userDTO)
        } catch let error as CKError {
            throw mapCloudKitError(error)
        } catch {
            throw AppError.userNotFound(id: id)
        }
    }
    
    public override func getUserByEmail(email: String) async throws -> User? {
        let predicate = NSPredicate(format: "email == %@", email)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        do {
            let result = try await database.records(matching: query)
            guard let recordResult = result.matchResults.first?.1 else {
                return nil
            }
            
            let record = try recordResult.get()
            let userDTO = try UserDTO.from(record)
            return try UserMapper.toDomain(userDTO)
        } catch let error as CKError {
            throw mapCloudKitError(error)
        } catch {
            throw AppError.networkError(underlying: error)
        }
    }
    
    public override func createUser(_ user: User) async throws -> User {
        let userDTO = UserMapper.toDTO(user)
        let record = try userDTO.toCKRecord()
        
        do {
            let savedRecord = try await database.save(record)
            let savedDTO = try UserDTO.from(savedRecord)
            return try UserMapper.toDomain(savedDTO)
        } catch let error as CKError {
            throw mapCloudKitError(error)
        } catch {
            throw AppError.userCreationFailed(reason: error.localizedDescription)
        }
    }
    
    public override func updateUser(_ user: User) async throws -> User {
        let userDTO = UserMapper.toDTO(user)
        let record = try userDTO.toCKRecord()
        
        do {
            let savedRecord = try await database.save(record)
            let savedDTO = try UserDTO.from(savedRecord)
            return try UserMapper.toDomain(savedDTO)
        } catch let error as CKError {
            throw mapCloudKitError(error)
        } catch {
            throw AppError.userUpdateFailed(reason: error.localizedDescription)
        }
    }
    
    public override func deleteUser(id: String) async throws {
        let recordID = CKRecord.ID(recordName: id)
        
        do {
            try await database.deleteRecord(withID: recordID)
        } catch let error as CKError {
            throw mapCloudKitError(error)
        } catch {
            throw AppError.userDeletionFailed(reason: error.localizedDescription)
        }
    }
    
    public override func searchUsers(criteria: UserSearchCriteria) async throws -> [User] {
        var predicates: [NSPredicate] = []
        
        if let name = criteria.name {
            predicates.append(NSPredicate(format: "name CONTAINS[cd] %@", name))
        }
        
        if let email = criteria.email {
            predicates.append(NSPredicate(format: "email CONTAINS[cd] %@", email))
        }
        
        if let userType = criteria.userType {
            predicates.append(NSPredicate(format: "userType == %@", userType.rawValue))
        }
        
        if let isActive = criteria.isActive {
            predicates.append(NSPredicate(format: "isActive == %@", NSNumber(value: isActive)))
        }
        
        let predicate = predicates.isEmpty ? NSPredicate(value: true) : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        // Add sorting
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            let result = try await database.records(matching: query)
            let userDTOs = try result.matchResults.compactMap { _, recordResult in
                let record = try recordResult.get()
                return try UserDTO.from(record)
            }
            
            // Apply limit and offset
            let limitedDTOs = applyLimitAndOffset(userDTOs, limit: criteria.limit, offset: criteria.offset)
            return try UserMapper.toDomainArray(limitedDTOs)
        } catch let error as CKError {
            throw mapCloudKitError(error)
        } catch {
            throw AppError.networkError(underlying: error)
        }
    }
    
    public override func getUsersByProgram(programId: String) async throws -> [User] {
        let predicate = NSPredicate(format: "ANY enrollments.programId == %@", programId)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        do {
            let result = try await database.records(matching: query)
            let userDTOs = try result.matchResults.compactMap { _, recordResult in
                let record = try recordResult.get()
                return try UserDTO.from(record)
            }
            
            return try UserMapper.toDomainArray(userDTOs)
        } catch let error as CKError {
            throw mapCloudKitError(error)
        } catch {
            throw AppError.networkError(underlying: error)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func applyLimitAndOffset<T>(_ array: [T], limit: Int?, offset: Int?) -> [T] {
        var result = array
        
        if let offset = offset, offset < result.count {
            result = Array(result.dropFirst(offset))
        }
        
        if let limit = limit, limit < result.count {
            result = Array(result.prefix(limit))
        }
        
        return result
    }
    
    private func mapCloudKitError(_ error: CKError) -> AppError {
        switch error.code {
        case .networkUnavailable, .networkFailure:
            return AppError.networkError(underlying: error)
        case .notAuthenticated:
            return AppError.authenticationFailed(reason: "User not authenticated")
        case .quotaExceeded:
            return AppError.storageQuotaExceeded
        case .serverResponseLost:
            return AppError.networkError(underlying: error)
        case .serviceUnavailable:
            return AppError.serviceUnavailable
        case .requestRateLimited:
            return AppError.rateLimitExceeded
        case .userDeletedZone:
            return AppError.userNotFound(id: "current")
        case .unknownItem:
            return AppError.userNotFound(id: "unknown")
        case .constraintViolation:
            return AppError.invalidUserData(field: "unknown", message: "Data constraint violation")
        default:
            return AppError.networkError(underlying: error)
        }
    }
}

 