import Foundation
import CloudKit
import Combine
import Firebase
import FirebaseAuth

class CloudKitService: ObservableObject {
    static let shared = CloudKitService()
    
    private let container = CKContainer(identifier: "iCloud.com.pjsengineering.samanual")
    internal let privateDatabase: CKDatabase
    internal let publicDatabase: CKDatabase
    
    @Published var isSignedInToiCloud = false
    @Published var currentUserID: String?
    
    init() {
        self.privateDatabase = container.privateCloudDatabase
        self.publicDatabase = container.publicCloudDatabase
        checkiCloudStatus()
    }
    
    // MARK: - iCloud Status
    func refreshiCloudStatus() {
        print("🔄 [CloudKitService] Manually refreshing iCloud status...")
        checkiCloudStatus()
    }
    
    func setupiCloud() async {
        print("🔄 [CloudKitService] Setting up iCloud...")
        
        // First check account status
        await withCheckedContinuation { continuation in
            container.accountStatus { [weak self] status, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ [CloudKitService] Error checking iCloud status: \(error)")
                    }
                    
                    switch status {
                    case .available:
                        print("✅ [CloudKitService] iCloud account available")
                        self?.isSignedInToiCloud = true
                        self?.fetchCurrentUserID()
                    case .noAccount:
                        print("❌ [CloudKitService] No iCloud account - please sign in to iCloud in Settings")
                    case .restricted:
                        print("❌ [CloudKitService] iCloud account restricted - check device restrictions")
                    case .couldNotDetermine:
                        print("❌ [CloudKitService] Could not determine iCloud status - check network connection")
                    case .temporarilyUnavailable:
                        print("❌ [CloudKitService] iCloud temporarily unavailable - try again later")
                    @unknown default:
                        print("❌ [CloudKitService] Unknown iCloud status")
                    }
                    continuation.resume()
                }
            }
        }
        
        // Wait a moment and check again
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        checkiCloudStatus()
    }
    
    private func checkiCloudStatus() {
        print("🔍 [CloudKitService] Checking iCloud status...")
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [CloudKitService] Error checking iCloud status: \(error)")
                }
                
                switch status {
                case .available:
                    print("✅ [CloudKitService] iCloud account available")
                    self?.isSignedInToiCloud = true
                    self?.fetchCurrentUserID()
                case .noAccount:
                    print("❌ [CloudKitService] No iCloud account")
                    self?.isSignedInToiCloud = false
                    self?.currentUserID = nil
                case .restricted:
                    print("❌ [CloudKitService] iCloud account restricted")
                    self?.isSignedInToiCloud = false
                    self?.currentUserID = nil
                case .couldNotDetermine:
                    print("❌ [CloudKitService] Could not determine iCloud status")
                    self?.isSignedInToiCloud = false
                    self?.currentUserID = nil
                case .temporarilyUnavailable:
                    print("❌ [CloudKitService] iCloud temporarily unavailable")
                    self?.isSignedInToiCloud = false
                    self?.currentUserID = nil
                @unknown default:
                    print("❌ [CloudKitService] Unknown iCloud status")
                    self?.isSignedInToiCloud = false
                    self?.currentUserID = nil
                }
            }
        }
    }
    
    private func fetchCurrentUserID() {
        print("🔍 [CloudKitService] Fetching current user ID...")
        container.fetchUserRecordID { [weak self] recordID, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [CloudKitService] Error fetching user record ID: \(error)")
                    self?.currentUserID = nil
                } else if let recordID = recordID {
                    print("✅ [CloudKitService] Current user ID: \(recordID.recordName)")
                    self?.currentUserID = recordID.recordName
                } else {
                    print("❌ [CloudKitService] No user record ID returned")
                    self?.currentUserID = nil
                }
            }
        }
    }
    
    // MARK: - User Profile Operations
    func saveUserProfile(_ profile: UserProfile) async throws {
        let record = CKRecord(recordType: "UserProfile")
        record.setValuesForKeys([
            "uid": profile.uid,
            "firebaseUid": profile.firebaseUid ?? "",
            "name": profile.name,
            "email": profile.email,
            "roles": profile.roles,
            "profilePhotoUrl": profile.profilePhotoUrl,
            "programs": try JSONEncoder().encode(profile.programs),
            "subscriptionId": profile.subscription?.id ?? "",
            "studioMembershipId": profile.studioMembership?.id ?? "",
            "practiceSessions": try JSONEncoder().encode(profile.practiceSessions),
            "userType": profile.userType.rawValue
        ])
        
        do {
            let sessionsData = try JSONEncoder().encode(profile.practiceSessions)
            record["practiceSessions"] = sessionsData
        } catch {
            print("⚠️ [CloudKitService] Failed to encode practiceSessions: \(error)")
        }
        
        try await privateDatabase.save(record)
    }
    
    func fetchUserProfile(uid: String) async throws -> UserProfile? {
        let predicate = NSPredicate(format: "uid == %@", uid)
        let query = CKQuery(recordType: "UserProfile", predicate: predicate)
        
        let result = try await privateDatabase.records(matching: query)
        guard let firstMatch = result.matchResults.first else { return nil }
        
        // Handle the Result<CKRecord, Error> type
        let record: CKRecord
        switch firstMatch.1 {
        case .success(let ckRecord):
            record = ckRecord
        case .failure(let error):
            throw error
        }
        
        return try decodeUserProfile(from: record)
    }
    
    // MARK: - Journal Entry Operations
    func saveJournalEntry(_ entry: JournalEntry) async throws {
        print("🔍 [CloudKitService] saveJournalEntry called with ID: \(entry.id)")
        
        let record: CKRecord
        
        // Try to fetch existing record first
        do {
            let recordID = CKRecord.ID(recordName: entry.id)
            let existingRecord = try await privateDatabase.record(for: recordID)
            print("🔍 [CloudKitService] Found existing record, updating")
            record = existingRecord
        } catch {
            // Record doesn't exist, create new one
            print("🔍 [CloudKitService] No existing record found, creating new")
            record = CKRecord(recordType: "JournalEntry")
        }
        
        // Encode referencedContent as JSON data for CloudKit storage
        let referencedContentData = try JSONEncoder().encode(entry.referencedContent)
        
        record.setValuesForKeys([
            "uid": entry.uid,
            "timestamp": entry.timestamp,
            "title": entry.title,
            "content": entry.content,
            "referencedContent": referencedContentData,
            "personalNotes": entry.personalNotes,
            "practiceNotes": entry.practiceNotes,
            "difficultyRating": entry.difficultyRating,
            "needsPractice": entry.needsPractice,
            "mediaUrls": entry.mediaUrls,
            "tags": entry.tags,
            "linkedPrograms": entry.linkedPrograms,
            "linkedTechniques": entry.linkedTechniques
        ])
        
        try await privateDatabase.save(record)
        print("🔍 [CloudKitService] Successfully saved journal entry")
    }
    
    func fetchJournalEntries(for uid: String) async throws -> [JournalEntry] {
        let predicate = NSPredicate(format: "uid == %@", uid)
        let query = CKQuery(recordType: "JournalEntry", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let result = try await privateDatabase.records(matching: query)
        return try result.matchResults.compactMap { _, recordResult in
            switch recordResult {
            case .success(let record):
                return try decodeJournalEntry(from: record)
            case .failure(let error):
                throw error
            }
        }
    }
    
    func deleteJournalEntry(_ entryId: String) async throws {
        let recordID = CKRecord.ID(recordName: entryId)
        try await privateDatabase.deleteRecord(withID: recordID)
    }
    
    // MARK: - Custom Content Operations
    func saveCustomContent(_ content: CustomContent) async throws {
        let record = CKRecord(recordType: "CustomContent")
        record.setValuesForKeys([
            "uid": content.uid,
            "title": content.title,
            "content": content.content,
            "mediaUrls": content.mediaUrls,
            "tags": content.tags
        ])
        
        try await privateDatabase.save(record)
    }
    
    func fetchCustomContent(for uid: String) async throws -> [CustomContent] {
        let predicate = NSPredicate(format: "uid == %@", uid)
        let query = CKQuery(recordType: "CustomContent", predicate: predicate)
        
        let result = try await privateDatabase.records(matching: query)
        return try result.matchResults.compactMap { _, recordResult in
            switch recordResult {
            case .success(let record):
                return try decodeCustomContent(from: record)
            case .failure(let error):
                throw error
            }
        }
    }
    
    // MARK: - Free Public Content Operations
    func saveFreeProgram(_ program: Program) async throws {
        guard program.accessLevel == .freePublic else {
            throw CloudKitError.invalidAccessLevel
        }
        
        let record = CKRecord(recordType: "FreeProgram")
        record.setValuesForKeys([
            "id": program.id,
            "meta": try JSONEncoder().encode(program),
            "ranks": program.ranks != nil ? try JSONEncoder().encode(program.ranks) : nil,
            "forms": program.forms != nil ? try JSONEncoder().encode(program.forms) : nil,
            "techniques": program.techniques != nil ? try JSONEncoder().encode(program.techniques) : nil,
            "accessLevel": program.accessLevel.rawValue,
            "dataStore": program.dataStore.rawValue,
            "studioMemberDiscount": program.physicalStudentDiscount ? 1 : 0
        ])
        
        try await publicDatabase.save(record)
    }
    
    func fetchFreePrograms() async throws -> [Program] {
        let query = CKQuery(recordType: "FreeProgram", predicate: NSPredicate(value: true))
        
        do {
            let result = try await publicDatabase.records(matching: query)
            return try result.matchResults.compactMap { _, recordResult in
                switch recordResult {
                case .success(let record):
                    return try decodeProgram(from: record)
                case .failure(let error):
                    throw error
                }
            }
        } catch let error as CKError {
            switch error.code {
            case .unknownItem:
                print("ℹ️ [CloudKitService] FreeProgram record type not found - this is expected for new containers")
                return []
            case .invalidArguments:
                print("ℹ️ [CloudKitService] FreeProgram record type not yet indexable - this is expected for new containers")
                return []
            default:
                print("❌ [CloudKitService] CloudKit error fetching free programs: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    func saveFreeMediaContent(_ content: MediaContent) async throws {
        guard content.accessLevel == .freePublic else {
            throw CloudKitError.invalidAccessLevel
        }
        
        let record = CKRecord(recordType: "FreeMediaContent")
        
        // Base fields
        var recordData: [String: Any] = [
            "id": content.id,
            "title": content.title,
            "description": content.description,
            "type": content.type.rawValue,
            "mediaUrl": content.mediaUrl,
            "thumbnailUrl": content.thumbnailUrl ?? "",
            "publishedDate": content.publishedDate,
            "author": content.author,
            "tags": content.tags,
            "accessLevel": content.accessLevel.rawValue,
            "dataStore": content.dataStore.rawValue,
            "mediaStorageLocation": content.mediaStorageLocation.rawValue,
            "isUserGenerated": content.isUserGenerated ? 1 : 0,
            "targetAudience": content.targetAudience.rawValue
        ]
        
        // Only add targeting arrays if they have values
        if let targetPrograms = content.targetPrograms, !targetPrograms.isEmpty {
            recordData["targetPrograms"] = targetPrograms
        }
        
        if let targetRoles = content.targetRoles, !targetRoles.isEmpty {
            recordData["targetRoles"] = targetRoles
        }
        
        record.setValuesForKeys(recordData)
        
        try await publicDatabase.save(record)
    }
    
    func fetchFreeMediaContent() async throws -> [MediaContent] {
        // Use the older perform method which is more reliable for new record types
        return try await withCheckedThrowingContinuation { continuation in
            let query = CKQuery(recordType: "FreeMediaContent", predicate: NSPredicate(value: true))
            
            let operation = CKQueryOperation(query: query)
            var results: [MediaContent] = []
            
            operation.recordMatchedBlock = { recordID, recordResult in
                switch recordResult {
                case .success(let record):
                    do {
                        let content = try self.decodeMediaContent(from: record)
                        results.append(content)
                    } catch {
                        print("❌ [CloudKitService] Error decoding record: \(error)")
                    }
                case .failure(let error):
                    print("❌ [CloudKitService] Error fetching record: \(error)")
                }
            }
            
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    // Sort by published date after fetching
                    let sortedResults = results.sorted { $0.publishedDate > $1.publishedDate }
                    continuation.resume(returning: sortedResults)
                case .failure(let error):
                    if let ckError = error as? CKError {
                        switch ckError.code {
                        case .unknownItem:
                            print("ℹ️ [CloudKitService] FreeMediaContent record type not found - this is expected for new containers")
                            continuation.resume(returning: [])
                        case .invalidArguments:
                            print("ℹ️ [CloudKitService] FreeMediaContent record type not yet indexable - this is expected for new containers")
                            print("ℹ️ [CloudKitService] Error details: \(ckError.localizedDescription)")
                            continuation.resume(returning: [])
                        default:
                            print("❌ [CloudKitService] CloudKit error: \(ckError.localizedDescription)")
                            continuation.resume(throwing: ckError)
                        }
                    } else {
                        print("❌ [CloudKitService] Unknown error: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            publicDatabase.add(operation)
        }
    }
    
    // MARK: - User Tag Management
    func saveUserTag(_ tag: Tag) async throws {
        let record = CKRecord(recordType: "UserTag")
        record.setValuesForKeys([
            "id": tag.id,
            "name": tag.name,
            "userId": tag.userId,
            "usageCount": tag.usageCount,
            "lastUsed": tag.lastUsed,
            "color": tag.color ?? ""
        ])
        
        try await privateDatabase.save(record)
    }
    
    func fetchUserTags(userId: String) async throws -> [Tag] {
        let predicate = NSPredicate(format: "userId == %@", userId)
        let query = CKQuery(recordType: "UserTag", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "usageCount", ascending: false), NSSortDescriptor(key: "lastUsed", ascending: false)]
        
        let result = try await privateDatabase.records(matching: query)
        return try result.matchResults.compactMap { _, recordResult in
            switch recordResult {
            case .success(let record):
                return try decodeTag(from: record)
            case .failure(let error):
                throw error
            }
        }
    }
    
    func updateTagUsage(_ tagId: String, userId: String) async throws {
        let predicate = NSPredicate(format: "id == %@ AND userId == %@", tagId, userId)
        let query = CKQuery(recordType: "UserTag", predicate: predicate)
        
        let result = try await privateDatabase.records(matching: query)
        guard let firstMatch = result.matchResults.first else { return }
        
        let record: CKRecord
        switch firstMatch.1 {
        case .success(let ckRecord):
            record = ckRecord
        case .failure(let error):
            throw error
        }
        
        let currentUsageCount = record["usageCount"] as? Int ?? 0
        record.setValue(currentUsageCount + 1, forKey: "usageCount")
        record.setValue(Date(), forKey: "lastUsed")
        
        try await privateDatabase.save(record)
    }
    
    func deleteUserTag(_ tagId: String, userId: String) async throws {
        let predicate = NSPredicate(format: "id == %@ AND userId == %@", tagId, userId)
        let query = CKQuery(recordType: "UserTag", predicate: predicate)
        
        let result = try await privateDatabase.records(matching: query)
        guard let firstMatch = result.matchResults.first else { return }
        
        let recordID: CKRecord.ID
        switch firstMatch.1 {
        case .success(let ckRecord):
            recordID = ckRecord.recordID
        case .failure(let error):
            throw error
        }
        
        try await privateDatabase.deleteRecord(withID: recordID)
    }
    
    private func decodeTag(from record: CKRecord) throws -> Tag {
        let id = record["id"] as? String ?? ""
        let name = record["name"] as? String ?? ""
        let userId = record["userId"] as? String ?? ""
        let usageCount = record["usageCount"] as? Int ?? 0
        let lastUsed = record["lastUsed"] as? Date ?? Date()
        let color = record["color"] as? String
        
        return Tag(
            id: id,
            name: name,
            userId: userId,
            usageCount: usageCount,
            lastUsed: lastUsed,
            color: color
        )
    }
    
    // MARK: - Decoding Helpers
    private func decodeUserProfile(from record: CKRecord) throws -> UserProfile {
        let uid = record["uid"] as? String ?? ""
        let firebaseUid = record["firebaseUid"] as? String
        let name = record["name"] as? String ?? ""
        let email = record["email"] as? String ?? ""
        let roles = record["roles"] as? [String] ?? []
        let profilePhotoUrl = record["profilePhotoUrl"] as? String ?? ""
        
        // Decode programs with backward compatibility
        var programs: [String: ProgramEnrollment] = [:]
        if let programsData = record["programs"] as? Data {
            do {
                programs = try JSONDecoder().decode([String: ProgramEnrollment].self, from: programsData)
            } catch {
                print("⚠️ [CloudKitService] Failed to decode programs, using empty dictionary: \(error)")
                programs = [:]
            }
        }
        
        // Decode practiceSessions
        var practiceSessions: [PracticeSession] = []
        if let sessionsData = record["practiceSessions"] as? Data {
            do {
                practiceSessions = try JSONDecoder().decode([PracticeSession].self, from: sessionsData)
            } catch {
                print("⚠️ [CloudKitService] Failed to decode practiceSessions, using empty array: \(error)")
                practiceSessions = []
            }
        }
        
        // Handle backward compatibility for new fields
        let dataStoreString = record["dataStore"] as? String
        let dataStore = dataStoreString != nil ? DataStore(rawValue: dataStoreString!) ?? .iCloud : .iCloud
        
        let accessLevelString = record["accessLevel"] as? String
        let accessLevel = accessLevelString != nil ? DataAccessLevel(rawValue: accessLevelString!) ?? .userPrivate : .userPrivate
        
        let userTypeString = record["userType"] as? String
        let userType = userTypeString != nil ? UserType(rawValue: userTypeString!) ?? .freeUser : .freeUser
        
        return UserProfile(
            uid: uid,
            firebaseUid: firebaseUid,
            name: name,
            email: email,
            roles: roles,
            profilePhotoUrl: profilePhotoUrl,
            programs: programs,
            subscription: nil, // Will be fetched separately from Firestore
            studioMembership: nil, // Will be fetched separately from Firestore
            dataStore: dataStore,
            accessLevel: accessLevel,
            userType: userType,
            practiceSessions: practiceSessions
        )
    }
    
    private func decodeJournalEntry(from record: CKRecord) throws -> JournalEntry {
        // Decode referencedContent with backward compatibility
        var referencedContent: [ContentReference] = []
        if let referencedContentData = record["referencedContent"] as? Data {
            do {
                referencedContent = try JSONDecoder().decode([ContentReference].self, from: referencedContentData)
            } catch {
                print("⚠️ [CloudKitService] Failed to decode referencedContent, using empty array: \(error)")
                referencedContent = []
            }
        }
        
        return JournalEntry(
            id: record.recordID.recordName,
            uid: record["uid"] as? String ?? "",
            timestamp: record["timestamp"] as? Date ?? Date(),
            title: record["title"] as? String ?? "",
            content: record["content"] as? String ?? "",
            referencedContent: referencedContent,
            personalNotes: record["personalNotes"] as? String ?? "",
            practiceNotes: record["practiceNotes"] as? String ?? "",
            difficultyRating: record["difficultyRating"] as? Int ?? 3,
            needsPractice: record["needsPractice"] as? Bool ?? false,
            mediaUrls: record["mediaUrls"] as? [String] ?? [],
            tags: record["tags"] as? [String] ?? [],
            linkedPrograms: record["linkedPrograms"] as? [String] ?? [],
            linkedTechniques: record["linkedTechniques"] as? [String] ?? []
        )
    }
    
    private func decodeCustomContent(from record: CKRecord) throws -> CustomContent {
        return CustomContent(
            id: record.recordID.recordName,
            uid: record["uid"] as? String ?? "",
            title: record["title"] as? String ?? "",
            content: record["content"] as? String ?? "",
            mediaUrls: record["mediaUrls"] as? [String] ?? [],
            tags: record["tags"] as? [String] ?? []
        )
    }
    
    private func decodeProgram(from record: CKRecord) throws -> Program {
        let id = record["id"] as? String ?? ""
        let metaData = record["meta"] as? Data ?? Data()
        let meta = try JSONDecoder().decode(ProgramMeta.self, from: metaData)
        
        let ranksData = record["ranks"] as? Data
        let ranks = ranksData != nil ? try JSONDecoder().decode([String: Rank].self, from: ranksData!) : nil
        
        let formsData = record["forms"] as? Data
        let forms = formsData != nil ? try JSONDecoder().decode([String: Form].self, from: formsData!) : nil
        
        let techniquesData = record["techniques"] as? Data
        let techniques = techniquesData != nil ? try JSONDecoder().decode([String: Technique].self, from: techniquesData!) : nil
        
        let accessLevelString = record["accessLevel"] as? String ?? ""
        let accessLevel = DataAccessLevel(rawValue: accessLevelString) ?? .freePublic
        
        let dataStoreString = record["dataStore"] as? String ?? ""
        let dataStore = DataStore(rawValue: dataStoreString) ?? .iCloud
        
        // Convert integer to boolean for CloudKit compatibility
        let studioMemberDiscountInt = record["studioMemberDiscount"] as? Int ?? 0
        let studioMemberDiscount = studioMemberDiscountInt == 1
        
        // Decode analytics with backward compatibility
        var analytics: ProgramAnalytics?
        if let analyticsData = record["analytics"] as? Data {
            do {
                analytics = try JSONDecoder().decode(ProgramAnalytics.self, from: analyticsData)
            } catch {
                print("⚠️ [CloudKitService] Failed to decode analytics, using nil: \(error)")
                analytics = nil
            }
        }
        
        return Program(
            id: id,
            name: meta.title,
            description: meta.description,
            color: meta.color,
            iconUrl: meta.iconUrl,
            accessLevel: accessLevel,
            createdAt: meta.createdAt,
            updatedAt: meta.updatedAt,
            isActive: meta.isActive,
            hasRanks: meta.hasRanks,
            physicalStudentDiscount: studioMemberDiscount,
            dataStore: dataStore,
            forms: forms ?? [:],
            ranks: ranks ?? [:],
            techniques: techniques ?? [:]
        )
    }
    
    private func decodeMediaContent(from record: CKRecord) throws -> MediaContent {
        let id = record["id"] as? String ?? ""
        let title = record["title"] as? String ?? ""
        let description = record["description"] as? String ?? ""
        let typeString = record["type"] as? String ?? "announcement"
        let type = MediaContentType(rawValue: typeString) ?? .announcement
        let mediaUrl = record["mediaUrl"] as? String ?? ""
        let thumbnailUrl = record["thumbnailUrl"] as? String
        let publishedDate = record["publishedDate"] as? Date ?? Date()
        let author = record["author"] as? String ?? ""
        let tags = record["tags"] as? [String] ?? []
        
        let accessLevelString = record["accessLevel"] as? String ?? ""
        let accessLevel = DataAccessLevel(rawValue: accessLevelString) ?? .freePublic
        
        let dataStoreString = record["dataStore"] as? String ?? ""
        let dataStore = DataStore(rawValue: dataStoreString) ?? .iCloud
        
        let mediaStorageLocationString = record["mediaStorageLocation"] as? String ?? ""
        let mediaStorageLocation = MediaStorageLocation(rawValue: mediaStorageLocationString) ?? .appPublic
        
        // Convert integer to boolean for CloudKit compatibility
        let isUserGeneratedInt = record["isUserGenerated"] as? Int ?? 0
        let isUserGenerated = isUserGeneratedInt == 1
        
        // Handle targeting fields with backward compatibility
        let targetAudienceString = record["targetAudience"] as? String ?? "everyone"
        let targetAudience = TargetAudience(rawValue: targetAudienceString) ?? .everyone
        
        // Handle optional targeting arrays - only set if they exist and are not empty
        let targetPrograms: [String]?
        if let programs = record["targetPrograms"] as? [String], !programs.isEmpty {
            targetPrograms = programs
        } else {
            targetPrograms = nil
        }
        
        let targetRoles: [String]?
        if let roles = record["targetRoles"] as? [String], !roles.isEmpty {
            targetRoles = roles
        } else {
            targetRoles = nil
        }
        
        return MediaContent(
            id: id,
            title: title,
            description: description,
            type: type,
            mediaUrl: mediaUrl,
            thumbnailUrl: thumbnailUrl,
            publishedDate: publishedDate,
            author: author,
            tags: tags,
            accessLevel: accessLevel,
            dataStore: dataStore,
            subscriptionRequired: nil,
            mediaStorageLocation: mediaStorageLocation,
            isUserGenerated: isUserGenerated,
            targeting: ContentTargeting(
                audience: targetAudience,
                programs: targetPrograms,
                roles: targetRoles
            )
        )
    }
    
    // MARK: - Test Data Creation
    func createTestAnnouncement() async throws {
        print("🔄 [CloudKitService] Creating test announcement...")
        
        // First check if the schema is ready
        let isSchemaReady = await checkSchemaReady()
        if !isSchemaReady {
            print("⚠️ [CloudKitService] Schema not ready, setting up CloudKit schema first...")
            await setupCloudKitSchema()
            
            // Wait a bit more for schema to be ready
            print("⏳ [CloudKitService] Waiting for schema to be ready...")
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        }
        
        let testAnnouncement = MediaContent(
            id: "test_announcement_\(Date().timeIntervalSince1970)",
            title: "Welcome to SA Kung Fu Journal!",
            description: "This is a test announcement to verify that the updates system is working correctly. You should see this if you're enrolled in any program.",
            type: .announcement,
            mediaUrl: "",
            thumbnailUrl: nil,
            publishedDate: Date(),
            author: "System",
            tags: ["welcome", "test", "important"],
            accessLevel: .freePublic,
            dataStore: .iCloud,
            subscriptionRequired: nil,
            mediaStorageLocation: .appPublic,
            isUserGenerated: false,
            targeting: ContentTargeting(
                audience: .everyone
            )
        )
        
        print("📝 [CloudKitService] Test announcement details:")
        print("  - ID: \(testAnnouncement.id)")
        print("  - Title: \(testAnnouncement.title)")
        print("  - Target Audience: \(testAnnouncement.targeting.audience)")
        print("  - Access Level: \(testAnnouncement.accessLevel)")
        print("  - Target Programs: \(testAnnouncement.targeting.programs ?? [])")
        print("  - Target Roles: \(testAnnouncement.targeting.roles ?? [])")
        
        try await saveFreeMediaContent(testAnnouncement)
        print("✅ [CloudKitService] Test announcement created successfully")
        
        // Try to fetch it immediately to verify it was saved
        do {
            let fetchedContent = try await fetchFreeMediaContent()
            print("🔍 [CloudKitService] Fetched \(fetchedContent.count) announcements after creating test")
            for content in fetchedContent {
                print("  - \(content.title) (ID: \(content.id))")
            }
        } catch {
            print("❌ [CloudKitService] Error fetching announcements after creation: \(error)")
        }
    }
    
    private func checkSchemaReady() async -> Bool {
        return await withCheckedContinuation { continuation in
            let query = CKQuery(recordType: "FreeMediaContent", predicate: NSPredicate(value: true))
            let operation = CKQueryOperation(query: query)
            
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure(let error):
                    if let ckError = error as? CKError {
                        if ckError.code == .unknownItem || ckError.code == .invalidArguments {
                            continuation.resume(returning: false)
                        } else {
                            continuation.resume(returning: true) // Other errors might not be schema-related
                        }
                    } else {
                        continuation.resume(returning: false)
                    }
                }
            }
            
            publicDatabase.add(operation)
        }
    }
    
    // MARK: - Schema Setup
    func setupCloudKitSchema() async {
        print("🔄 [CloudKitService] Setting up CloudKit schema automatically...")
        
        do {
            // Create sample records to automatically generate schema
            try await createSampleRecords()
            print("✅ [CloudKitService] CloudKit schema setup completed")
            print("ℹ️ [CloudKitService] Note: It may take a few minutes for CloudKit to fully index the new record types")
        } catch {
            print("❌ [CloudKitService] Failed to setup schema: \(error)")
            print("ℹ️ [CloudKitService] You may need to manually set up the schema in CloudKit Console")
        }
    }
    
    func checkSchemaStatus() async {
        print("🔍 [CloudKitService] Checking CloudKit schema status...")
        
        // Try to fetch from each record type to check if they're properly set up
        do {
            let _ = try await fetchFreePrograms()
            print("✅ [CloudKitService] FreeProgram record type is working")
        } catch {
            print("❌ [CloudKitService] FreeProgram record type has issues: \(error)")
        }
        
        do {
            let _ = try await fetchFreeMediaContent()
            print("✅ [CloudKitService] FreeMediaContent record type is working")
        } catch {
            print("❌ [CloudKitService] FreeMediaContent record type has issues: \(error)")
        }
        
        do {
            let _ = try await fetchUserTags(userId: "test")
            print("✅ [CloudKitService] UserTag record type is working")
        } catch {
            print("❌ [CloudKitService] UserTag record type has issues: \(error)")
        }
    }
    
    private func createSampleRecords() async throws {
        // Create a sample UserProfile to set up the record type
        let sampleProfile = UserProfile(
            uid: "schema_setup_user",
            firebaseUid: "schema_setup_firebase",
            name: "Schema Setup",
            email: "setup@example.com",
            roles: ["student"],
            profilePhotoUrl: "",
            programs: [:],
            subscription: nil,
            studioMembership: nil,
            dataStore: .iCloud,
            accessLevel: .userPrivate,
            userType: .freeUser
        )
        
        // Create a sample JournalEntry with non-empty arrays
        let sampleJournal = JournalEntry(
            id: "schema_setup_journal",
            uid: "schema_setup_user",
            timestamp: Date(),
            title: "Schema Setup Entry",
            content: "This is a setup entry",
            referencedContent: [],
            personalNotes: "Setup notes",
            practiceNotes: "Setup practice notes",
            difficultyRating: 3,
            needsPractice: false,
            mediaUrls: ["sample_url"],
            tags: ["setup"],
            linkedPrograms: ["sample_program"],
            linkedTechniques: ["sample_technique"]
        )
        
        // Create a sample Program
        let sampleProgram = Program(
            id: "schema_setup_program",
            name: "Schema Setup Program",
            description: "Setup program",
            color: "#FFFFFF",
            iconUrl: "",
            accessLevel: .freePublic,
            createdAt: "2025-01-01T00:00:00Z",
            updatedAt: "2025-01-01T00:00:00Z",
            isActive: true,
            hasRanks: false,
            physicalStudentDiscount: false,
            dataStore: .iCloud,
            forms: [:],
            ranks: [:],
            techniques: [:]
        )
        
        // Create a sample MediaContent with non-empty arrays
        let sampleMedia = MediaContent(
            id: "schema_setup_media",
            title: "Schema Setup Media",
            description: "Setup media content",
            type: .announcement,
            mediaUrl: "sample_media_url",
            thumbnailUrl: "sample_thumbnail_url",
            publishedDate: Date(),
            author: "System",
            tags: ["setup", "sample"],
            accessLevel: .freePublic,
            dataStore: .iCloud,
            subscriptionRequired: nil,
            mediaStorageLocation: .appPublic,
            isUserGenerated: false,
            targeting: ContentTargeting(
                audience: .everyone
            )
        )
        
        // Create a sample UserTag
        let sampleTag = Tag(
            id: "schema_setup_tag",
            name: "setup_tag",
            userId: "schema_setup_user",
            usageCount: 1,
            lastUsed: Date(),
            color: "#007AFF"
        )
        
        // Save all sample records to create schema
        try await saveUserProfile(sampleProfile)
        try await saveJournalEntry(sampleJournal)
        try await saveFreeProgram(sampleProgram)
        try await saveFreeMediaContent(sampleMedia)
        try await saveUserTag(sampleTag)
        
        // Clean up sample records
        try await cleanupSampleRecords()
    }
    
    private func cleanupSampleRecords() async throws {
        // Delete the sample records we created for schema setup
        let privateRecordIDs = [
            CKRecord.ID(recordName: "schema_setup_user"),
            CKRecord.ID(recordName: "schema_setup_journal"),
            CKRecord.ID(recordName: "schema_setup_tag")
        ]
        
        let publicRecordIDs = [
            CKRecord.ID(recordName: "schema_setup_program"),
            CKRecord.ID(recordName: "schema_setup_media")
        ]
        
        // Delete private records
        for recordID in privateRecordIDs {
            try await privateDatabase.deleteRecord(withID: recordID)
        }
        
        // Delete public records
        for recordID in publicRecordIDs {
            try await publicDatabase.deleteRecord(withID: recordID)
        }
    }
    
    // MARK: - Analytics Tracking (User Private)
    func trackContentReference(contentId: String, type: ContentType) async throws {
        let record = CKRecord(recordType: "ContentAnalytics")
        
        // Create a unique ID for this analytics entry
        let analyticsId = "\(contentId)_\(type.rawValue)_\(Date().timeIntervalSince1970)"
        
        record.setValuesForKeys([
            "analyticsId": analyticsId,
            "contentId": contentId,
            "contentType": type.rawValue,
            "eventType": "reference",
            "timestamp": Date(),
            "uid": getCurrentUserId() ?? "unknown"
        ])
        
        try await privateDatabase.save(record)
    }
    
    func trackContentView(contentId: String, type: ContentType) async throws {
        let record = CKRecord(recordType: "ContentAnalytics")
        
        // Create a unique ID for this analytics entry
        let analyticsId = "\(contentId)_\(type.rawValue)_\(Date().timeIntervalSince1970)"
        
        record.setValuesForKeys([
            "analyticsId": analyticsId,
            "contentId": contentId,
            "contentType": type.rawValue,
            "eventType": "view",
            "timestamp": Date(),
            "uid": getCurrentUserId() ?? "unknown"
        ])
        
        try await privateDatabase.save(record)
    }
    
    // MARK: - Analytics Retrieval
    func fetchUserAnalytics(userId: String) async throws -> [ContentAnalytics] {
        let predicate = NSPredicate(format: "uid == %@", userId)
        let query = CKQuery(recordType: "ContentAnalytics", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let result = try await privateDatabase.records(matching: query)
        return try result.matchResults.compactMap { _, recordResult in
            switch recordResult {
            case .success(let record):
                return try decodeContentAnalytics(from: record)
            case .failure(let error):
                throw error
            }
        }
    }
    
    private func decodeContentAnalytics(from record: CKRecord) throws -> ContentAnalytics {
        let contentId = record["contentId"] as? String ?? ""
        let contentTypeString = record["contentType"] as? String ?? ""
        let contentType = ContentType(rawValue: contentTypeString) ?? .program
        let eventType = record["eventType"] as? String ?? ""
        let timestamp = record["timestamp"] as? Date ?? Date()
        
        return ContentAnalytics(
            id: record.recordID.recordName,
            contentId: contentId,
            contentType: contentType,
            eventType: eventType,
            timestamp: timestamp
        )
    }
    
    private func getCurrentUserId() -> String? {
        // Get the current user ID for analytics tracking
        // This should match the user ID used in journal entries
        return Auth.auth().currentUser?.uid
    }
}

// MARK: - Errors
enum CloudKitError: Error, LocalizedError {
    case invalidAccessLevel
    case recordNotFound
    case encodingError
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidAccessLevel:
            return "Invalid access level for this operation"
        case .recordNotFound:
            return "Record not found"
        case .encodingError:
            return "Failed to encode data"
        case .decodingError:
            return "Failed to decode data"
        }
    }
} 