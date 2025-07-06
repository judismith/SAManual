import Foundation
import Combine
import CloudKit

// MARK: - CloudKit User Service Implementation
public final class CloudKitUserService: UserService {
    
    // MARK: - CloudKit Configuration
    private let container: CKContainer
    private let database: CKDatabase
    private let recordZone: CKRecordZone
    
    // MARK: - Publishers
    private let currentUserSubject = CurrentValueSubject<UserProfile?, Never>(nil)
    private let userUpdatesSubject = PassthroughSubject<UserProfile, Never>()
    
    public var currentUserPublisher: AnyPublisher<UserProfile?, Never> {
        currentUserSubject.eraseToAnyPublisher()
    }
    
    public var userUpdatesPublisher: AnyPublisher<UserProfile, Never> {
        userUpdatesSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Cache
    private var userCache: [String: UserProfile] = [:]
    private var currentUser: UserProfile?
    
    // MARK: - Record Types
    private struct RecordType {
        static let userProfile = "UserProfile"
        static let enrollment = "Enrollment"
        static let userPreferences = "UserPreferences"
        static let userActivity = "UserActivity"
    }
    
    // MARK: - Initialization
    public init(container: CKContainer? = nil) {
        self.container = container ?? CKContainer(identifier: "iCloud.com.sakungfujournal")
        self.database = self.container.privateCloudDatabase
        self.recordZone = CKRecordZone(zoneName: "UserDataZone")
        
        setupCloudKit()
    }
    
    // MARK: - CloudKit Setup
    private func setupCloudKit() {
        Task {
            await createCustomZoneIfNeeded()
        }
    }
    
    private func createCustomZoneIfNeeded() async {
        do {
            let _ = try await database.save(recordZone)
            print("✅ [CloudKit] Custom zone created/verified")
        } catch let error as CKError where error.code == .zoneNotEmpty {
            // Zone already exists, which is fine
            print("✅ [CloudKit] Custom zone already exists")
        } catch {
            print("❌ [CloudKit] Failed to create custom zone: \(error)")
        }
    }
    
    // MARK: - User Profile Management
    public func createUser(_ userProfile: UserProfile) async throws -> UserProfile {
        do {
            // Check for duplicate email
            if try await getUserByEmail(userProfile.email) != nil {
                throw UserServiceError.duplicateUser(email: userProfile.email)
            }
            
            let record = createUserProfileRecord(from: userProfile)
            let savedRecord = try await database.save(record)
            
            let savedUser = try createUserProfile(from: savedRecord)
            userCache[savedUser.id] = savedUser
            userUpdatesSubject.send(savedUser)
            
            return savedUser
            
        } catch let error as CKError {
            throw convertCloudKitError(error)
        }
    }
    
    public func getUserProfile(id: String) async throws -> UserProfile? {
        // Check cache first
        if let cachedUser = userCache[id] {
            return cachedUser
        }
        
        do {
            let recordID = CKRecord.ID(recordName: id, zoneID: recordZone.zoneID)
            let record = try await database.record(for: recordID)
            
            let userProfile = try createUserProfile(from: record)
            userCache[id] = userProfile
            
            return userProfile
            
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch let error as CKError {
            throw convertCloudKitError(error)
        }
    }
    
    public func updateUserProfile(_ userProfile: UserProfile) async throws -> UserProfile {
        do {
            let recordID = CKRecord.ID(recordName: userProfile.id, zoneID: recordZone.zoneID)
            let record = try await database.record(for: recordID)
            
            updateUserProfileRecord(record, with: userProfile)
            let savedRecord = try await database.save(record)
            
            let updatedUser = try createUserProfile(from: savedRecord)
            userCache[updatedUser.id] = updatedUser
            userUpdatesSubject.send(updatedUser)
            
            // Update current user if it's the same
            if currentUser?.id == userProfile.id {
                currentUser = updatedUser
                currentUserSubject.send(updatedUser)
            }
            
            return updatedUser
            
        } catch let error as CKError {
            throw convertCloudKitError(error)
        }
    }
    
    public func deleteUser(id: String) async throws {
        do {
            let recordID = CKRecord.ID(recordName: id, zoneID: recordZone.zoneID)
            try await database.deleteRecord(withID: recordID)
            
            userCache.removeValue(forKey: id)
            
            // Clear current user if it was deleted
            if currentUser?.id == id {
                currentUser = nil
                currentUserSubject.send(nil)
            }
            
        } catch let error as CKError where error.code == .unknownItem {
            throw UserServiceError.userNotFound(id: id)
        } catch let error as CKError {
            throw convertCloudKitError(error)
        }
    }
    
    // MARK: - Current User Management
    public func getCurrentUser() async throws -> UserProfile? {
        return currentUser
    }
    
    public func updateCurrentUser(_ userProfile: UserProfile) async throws -> UserProfile {
        let updatedUser = try await updateUserProfile(userProfile)
        currentUser = updatedUser
        currentUserSubject.send(updatedUser)
        return updatedUser
    }
    
    public func signOut() async throws {
        currentUser = nil
        currentUserSubject.send(nil)
        userCache.removeAll()
    }
    
    // MARK: - User Search and Discovery
    public func searchUsers(query: String, limit: Int) async throws -> [UserProfile] {
        do {
            let predicate = NSPredicate(format: "displayName CONTAINS[cd] %@ OR email CONTAINS[cd] %@", query, query)
            let queryOp = CKQuery(recordType: RecordType.userProfile, predicate: predicate)
            queryOp.sortDescriptors = [NSSortDescriptor(key: "displayName", ascending: true)]
            
            let (matchResults, _) = try await database.records(matching: queryOp, inZoneWith: recordZone.zoneID)
            
            var users: [UserProfile] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let user = try? createUserProfile(from: record) {
                        users.append(user)
                        userCache[user.id] = user
                    }
                case .failure:
                    continue
                }
            }
            
            return Array(users.prefix(limit))
            
        } catch let error as CKError {
            throw convertCloudKitError(error)
        }
    }
    
    public func getUsersByAccessLevel(_ accessLevel: AccessLevel) async throws -> [UserProfile] {
        do {
            let predicate = NSPredicate(format: "accessLevel == %@", accessLevel.rawValue)
            let queryOp = CKQuery(recordType: RecordType.userProfile, predicate: predicate)
            
            let (matchResults, _) = try await database.records(matching: queryOp, inZoneWith: recordZone.zoneID)
            
            var users: [UserProfile] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let user = try? createUserProfile(from: record) {
                        users.append(user)
                        userCache[user.id] = user
                    }
                case .failure:
                    continue
                }
            }
            
            return users
            
        } catch let error as CKError {
            throw convertCloudKitError(error)
        }
    }
    
    public func getUsersByProgram(programId: String) async throws -> [UserProfile] {
        do {
            // Query enrollments for the program
            let predicate = NSPredicate(format: "programId == %@ AND enrolled == 1", programId)
            let queryOp = CKQuery(recordType: RecordType.enrollment, predicate: predicate)
            
            let (matchResults, _) = try await database.records(matching: queryOp, inZoneWith: recordZone.zoneID)
            
            var userIds: [String] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let userId = record["userId"] as? String {
                        userIds.append(userId)
                    }
                case .failure:
                    continue
                }
            }
            
            // Fetch user profiles for these IDs
            var users: [UserProfile] = []
            for userId in userIds {
                if let user = try await getUserProfile(id: userId) {
                    users.append(user)
                }
            }
            
            return users
            
        } catch let error as CKError {
            throw convertCloudKitError(error)
        }
    }
    
    // MARK: - User Enrollment Management
    public func enrollUserInProgram(userId: String, programId: String, startingRank: String) async throws -> UserProfile {
        do {
            // First, get the user
            guard var user = try await getUserProfile(id: userId) else {
                throw UserServiceError.userNotFound(id: userId)
            }
            
            // Check if already enrolled
            if user.programs[programId]?.enrolled == true {
                throw UserServiceError.enrollmentFailed(userId: userId, programId: programId)
            }
            
            // Create enrollment record
            let enrollment = Enrollment(
                userId: userId,
                programId: programId,
                enrolled: true,
                enrollmentDate: Date(),
                currentRank: startingRank,
                rankDate: Date(),
                isActive: true
            )
            
            let enrollmentRecord = createEnrollmentRecord(from: enrollment)
            try await database.save(enrollmentRecord)
            
            // Update user's programs
            var updatedPrograms = user.programs
            updatedPrograms[programId] = enrollment
            
            user = UserProfile(
                id: user.id,
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName,
                displayName: user.displayName,
                profileImageURL: user.profileImageURL,
                accessLevel: user.accessLevel,
                isActive: user.isActive,
                programs: updatedPrograms
            )
            
            return try await updateUserProfile(user)
            
        } catch let error as CKError {
            throw convertCloudKitError(error)
        }
    }
    
    public func unenrollUserFromProgram(userId: String, programId: String) async throws -> UserProfile {
        do {
            guard var user = try await getUserProfile(id: userId) else {
                throw UserServiceError.userNotFound(id: userId)
            }
            
            guard let enrollment = user.programs[programId] else {
                throw UserServiceError.unenrollmentFailed(userId: userId, programId: programId)
            }
            
            // Delete enrollment record
            let recordID = CKRecord.ID(recordName: enrollment.id, zoneID: recordZone.zoneID)
            try await database.deleteRecord(withID: recordID)
            
            // Update user's programs
            var updatedPrograms = user.programs
            updatedPrograms.removeValue(forKey: programId)
            
            user = UserProfile(
                id: user.id,
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName,
                displayName: user.displayName,
                profileImageURL: user.profileImageURL,
                accessLevel: user.accessLevel,
                isActive: user.isActive,
                programs: updatedPrograms
            )
            
            return try await updateUserProfile(user)
            
        } catch let error as CKError {
            throw convertCloudKitError(error)
        }
    }
    
    public func updateUserRank(userId: String, programId: String, newRank: String) async throws -> UserProfile {
        do {
            guard var user = try await getUserProfile(id: userId) else {
                throw UserServiceError.userNotFound(id: userId)
            }
            
            guard var enrollment = user.programs[programId] else {
                throw UserServiceError.enrollmentFailed(userId: userId, programId: programId)
            }
            
            // Update enrollment
            enrollment = Enrollment(
                id: enrollment.id,
                userId: enrollment.userId,
                programId: enrollment.programId,
                enrolled: enrollment.enrolled,
                enrollmentDate: enrollment.enrollmentDate,
                currentRank: newRank,
                rankDate: Date(),
                isActive: enrollment.isActive
            )
            
            // Update enrollment record in CloudKit
            let recordID = CKRecord.ID(recordName: enrollment.id, zoneID: recordZone.zoneID)
            let record = try await database.record(for: recordID)
            updateEnrollmentRecord(record, with: enrollment)
            try await database.save(record)
            
            // Update user's programs
            var updatedPrograms = user.programs
            updatedPrograms[programId] = enrollment
            
            user = UserProfile(
                id: user.id,
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName,
                displayName: user.displayName,
                profileImageURL: user.profileImageURL,
                accessLevel: user.accessLevel,
                isActive: user.isActive,
                programs: updatedPrograms
            )
            
            return try await updateUserProfile(user)
            
        } catch let error as CKError {
            throw convertCloudKitError(error)
        }
    }
    
    // MARK: - User Preferences
    public func getUserPreferences(userId: String) async throws -> UserPreferences? {
        do {
            let recordID = CKRecord.ID(recordName: "preferences_\(userId)", zoneID: recordZone.zoneID)
            let record = try await database.record(for: recordID)
            
            return try createUserPreferences(from: record)
            
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch let error as CKError {
            throw convertCloudKitError(error)
        }
    }
    
    public func updateUserPreferences(userId: String, preferences: UserPreferences) async throws -> UserPreferences {
        do {
            let recordID = CKRecord.ID(recordName: "preferences_\(userId)", zoneID: recordZone.zoneID)
            
            let record: CKRecord
            do {
                record = try await database.record(for: recordID)
            } catch let error as CKError where error.code == .unknownItem {
                // Create new record
                record = CKRecord(recordType: RecordType.userPreferences, recordID: recordID)
            }
            
            updateUserPreferencesRecord(record, with: preferences)
            try await database.save(record)
            
            return preferences
            
        } catch let error as CKError {
            throw convertCloudKitError(error)
        }
    }
    
    // MARK: - User Activity Tracking
    public func recordUserActivity(userId: String, activity: UserActivity) async throws {
        do {
            let activityRecord = createUserActivityRecord(from: activity)
            try await database.save(activityRecord)
            
        } catch let error as CKError {
            throw convertCloudKitError(error)
        }
    }
    
    public func getUserActivityHistory(userId: String, limit: Int) async throws -> [UserActivity] {
        do {
            let predicate = NSPredicate(format: "userId == %@", userId)
            let queryOp = CKQuery(recordType: RecordType.userActivity, predicate: predicate)
            queryOp.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            
            let (matchResults, _) = try await database.records(matching: queryOp, inZoneWith: recordZone.zoneID)
            
            var activities: [UserActivity] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let activity = try? createUserActivity(from: record) {
                        activities.append(activity)
                    }
                case .failure:
                    continue
                }
            }
            
            return Array(activities.prefix(limit))
            
        } catch let error as CKError {
            throw convertCloudKitError(error)
        }
    }
    
    // MARK: - Helper Methods
    private func getUserByEmail(_ email: String) async throws -> UserProfile? {
        let predicate = NSPredicate(format: "email == %@", email)
        let queryOp = CKQuery(recordType: RecordType.userProfile, predicate: predicate)
        
        let (matchResults, _) = try await database.records(matching: queryOp, inZoneWith: recordZone.zoneID)
        
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                return try? createUserProfile(from: record)
            case .failure:
                continue
            }
        }
        
        return nil
    }
    
    public func setCurrentUser(_ user: UserProfile?) {
        currentUser = user
        currentUserSubject.send(user)
    }
    
    public func clearCache() {
        userCache.removeAll()
    }
    
    // MARK: - CloudKit Error Conversion
    private func convertCloudKitError(_ error: CKError) -> UserServiceError {
        switch error.code {
        case .networkUnavailable, .networkFailure:
            return .networkError(underlying: error)
        case .notAuthenticated:
            return .insufficientPermissions(userId: "", operation: "CloudKit access")
        case .quotaExceeded:
            return .unknown(underlying: error) // Could add specific quota error
        case .recordSizeExceeded:
            return .invalidUserData(field: "record size")
        default:
            return .unknown(underlying: error)
        }
    }
}