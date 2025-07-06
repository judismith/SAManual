import Foundation
import CloudKit

// MARK: - CloudKit Record Mapping Extensions
extension CloudKitUserService {
    
    // MARK: - UserProfile Record Mapping
    func createUserProfileRecord(from userProfile: UserProfile) -> CKRecord {
        let recordID = CKRecord.ID(recordName: userProfile.id, zoneID: recordZone.zoneID)
        let record = CKRecord(recordType: RecordType.userProfile, recordID: recordID)
        
        record["email"] = userProfile.email
        record["firstName"] = userProfile.firstName
        record["lastName"] = userProfile.lastName
        record["displayName"] = userProfile.displayName
        record["profileImageURL"] = userProfile.profileImageURL
        record["accessLevel"] = userProfile.accessLevel.rawValue
        record["isActive"] = userProfile.isActive ? 1 : 0
        record["createdAt"] = userProfile.createdAt
        record["updatedAt"] = userProfile.updatedAt
        
        // Store programs as JSON data
        if let programsData = try? JSONEncoder().encode(userProfile.programs) {
            record["programs"] = programsData
        }
        
        return record
    }
    
    func updateUserProfileRecord(_ record: CKRecord, with userProfile: UserProfile) {
        record["email"] = userProfile.email
        record["firstName"] = userProfile.firstName
        record["lastName"] = userProfile.lastName
        record["displayName"] = userProfile.displayName
        record["profileImageURL"] = userProfile.profileImageURL
        record["accessLevel"] = userProfile.accessLevel.rawValue
        record["isActive"] = userProfile.isActive ? 1 : 0
        record["updatedAt"] = Date()
        
        // Store programs as JSON data
        if let programsData = try? JSONEncoder().encode(userProfile.programs) {
            record["programs"] = programsData
        }
    }
    
    func createUserProfile(from record: CKRecord) throws -> UserProfile {
        guard let email = record["email"] as? String,
              let firstName = record["firstName"] as? String,
              let lastName = record["lastName"] as? String,
              let displayName = record["displayName"] as? String,
              let accessLevelString = record["accessLevel"] as? String,
              let accessLevel = AccessLevel(rawValue: accessLevelString),
              let isActiveInt = record["isActive"] as? Int,
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date else {
            throw UserServiceError.invalidUserData(field: "required fields")
        }
        
        let profileImageURL = record["profileImageURL"] as? String
        let isActive = isActiveInt == 1
        
        // Decode programs from JSON data
        var programs: [String: Enrollment] = [:]
        if let programsData = record["programs"] as? Data {
            programs = (try? JSONDecoder().decode([String: Enrollment].self, from: programsData)) ?? [:]
        }
        
        return UserProfile(
            id: record.recordID.recordName,
            email: email,
            firstName: firstName,
            lastName: lastName,
            displayName: displayName,
            profileImageURL: profileImageURL,
            accessLevel: accessLevel,
            isActive: isActive,
            programs: programs
        )
    }
    
    // MARK: - Enrollment Record Mapping
    func createEnrollmentRecord(from enrollment: Enrollment) -> CKRecord {
        let recordID = CKRecord.ID(recordName: enrollment.id, zoneID: recordZone.zoneID)
        let record = CKRecord(recordType: RecordType.enrollment, recordID: recordID)
        
        record["userId"] = enrollment.userId
        record["programId"] = enrollment.programId
        record["enrolled"] = enrollment.enrolled ? 1 : 0
        record["enrollmentDate"] = enrollment.enrollmentDate
        record["currentRank"] = enrollment.currentRank
        record["rankDate"] = enrollment.rankDate
        record["isActive"] = enrollment.isActive ? 1 : 0
        
        return record
    }
    
    func updateEnrollmentRecord(_ record: CKRecord, with enrollment: Enrollment) {
        record["userId"] = enrollment.userId
        record["programId"] = enrollment.programId
        record["enrolled"] = enrollment.enrolled ? 1 : 0
        record["enrollmentDate"] = enrollment.enrollmentDate
        record["currentRank"] = enrollment.currentRank
        record["rankDate"] = enrollment.rankDate
        record["isActive"] = enrollment.isActive ? 1 : 0
    }
    
    func createEnrollment(from record: CKRecord) throws -> Enrollment {
        guard let userId = record["userId"] as? String,
              let programId = record["programId"] as? String,
              let enrolledInt = record["enrolled"] as? Int,
              let enrollmentDate = record["enrollmentDate"] as? Date,
              let isActiveInt = record["isActive"] as? Int else {
            throw UserServiceError.invalidUserData(field: "enrollment required fields")
        }
        
        let enrolled = enrolledInt == 1
        let isActive = isActiveInt == 1
        let currentRank = record["currentRank"] as? String
        let rankDate = record["rankDate"] as? Date
        
        return Enrollment(
            id: record.recordID.recordName,
            userId: userId,
            programId: programId,
            enrolled: enrolled,
            enrollmentDate: enrollmentDate,
            currentRank: currentRank,
            rankDate: rankDate,
            isActive: isActive
        )
    }
    
    // MARK: - UserPreferences Record Mapping
    func createUserPreferencesRecord(from preferences: UserPreferences) -> CKRecord {
        let recordID = CKRecord.ID(recordName: "preferences_\(preferences.userId)", zoneID: recordZone.zoneID)
        let record = CKRecord(recordType: RecordType.userPreferences, recordID: recordID)
        
        record["userId"] = preferences.userId
        record["createdAt"] = preferences.createdAt
        record["updatedAt"] = preferences.updatedAt
        
        // Store preferences as JSON data
        if let preferencesData = try? JSONEncoder().encode(preferences) {
            record["preferencesData"] = preferencesData
        }
        
        return record
    }
    
    func updateUserPreferencesRecord(_ record: CKRecord, with preferences: UserPreferences) {
        record["userId"] = preferences.userId
        record["updatedAt"] = Date()
        
        // Store preferences as JSON data
        if let preferencesData = try? JSONEncoder().encode(preferences) {
            record["preferencesData"] = preferencesData
        }
    }
    
    func createUserPreferences(from record: CKRecord) throws -> UserPreferences {
        guard let userId = record["userId"] as? String else {
            throw UserServiceError.invalidUserData(field: "userId")
        }
        
        // Decode preferences from JSON data
        if let preferencesData = record["preferencesData"] as? Data,
           let preferences = try? JSONDecoder().decode(UserPreferences.self, from: preferencesData) {
            return preferences
        } else {
            // Return default preferences if data is corrupt or missing
            return UserPreferences(userId: userId)
        }
    }
    
    // MARK: - UserActivity Record Mapping
    func createUserActivityRecord(from activity: UserActivity) -> CKRecord {
        let recordID = CKRecord.ID(recordName: activity.id.uuidString, zoneID: recordZone.zoneID)
        let record = CKRecord(recordType: RecordType.userActivity, recordID: recordID)
        
        record["userId"] = activity.userId
        record["activityType"] = activity.activityType.rawValue
        record["timestamp"] = activity.timestamp
        
        // Store details as JSON data
        if let detailsData = try? JSONSerialization.data(withJSONObject: activity.details) {
            record["details"] = detailsData
        }
        
        return record
    }
    
    func createUserActivity(from record: CKRecord) throws -> UserActivity {
        guard let userId = record["userId"] as? String,
              let activityTypeString = record["activityType"] as? String,
              let activityType = UserActivity.ActivityType(rawValue: activityTypeString),
              let timestamp = record["timestamp"] as? Date else {
            throw UserServiceError.invalidUserData(field: "activity required fields")
        }
        
        // Decode details from JSON data
        var details: [String: Any] = [:]
        if let detailsData = record["details"] as? Data {
            details = (try? JSONSerialization.jsonObject(with: detailsData) as? [String: Any]) ?? [:]
        }
        
        return UserActivity(userId: userId, activityType: activityType, details: details)
    }
}

// MARK: - CloudKit Query Helpers
extension CloudKitUserService {
    
    /// Performs a batch operation to fetch multiple users efficiently
    func fetchUsers(withIDs userIDs: [String]) async throws -> [UserProfile] {
        let recordIDs = userIDs.map { CKRecord.ID(recordName: $0, zoneID: recordZone.zoneID) }
        
        do {
            let records = try await database.records(for: recordIDs)
            var users: [UserProfile] = []
            
            for (_, result) in records {
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
    
    /// Efficiently checks if a user exists without loading full profile
    func userExists(withID userID: String) async throws -> Bool {
        let recordID = CKRecord.ID(recordName: userID, zoneID: recordZone.zoneID)
        
        do {
            let _ = try await database.record(for: recordID)
            return true
        } catch let error as CKError where error.code == .unknownItem {
            return false
        } catch let error as CKError {
            throw convertCloudKitError(error)
        }
    }
    
    /// Performs efficient pagination for user lists
    func fetchUsersPaginated(startAfter cursor: CKQueryOperation.Cursor?) async throws -> (users: [UserProfile], nextCursor: CKQueryOperation.Cursor?) {
        let queryOp = CKQuery(recordType: RecordType.userProfile, predicate: NSPredicate(value: true))
        queryOp.sortDescriptors = [NSSortDescriptor(key: "displayName", ascending: true)]
        
        do {
            let (matchResults, nextCursor) = try await database.records(matching: queryOp, 
                                                                      continuingFrom: cursor, 
                                                                      inZoneWith: recordZone.zoneID)
            
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
            
            return (users, nextCursor)
            
        } catch let error as CKError {
            throw convertCloudKitError(error)
        }
    }
}