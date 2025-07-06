import Foundation
import FirebaseFirestore
import Combine
import FirebaseAuth

class FirestoreService {
    static let shared = FirestoreService()
    internal let db = Firestore.firestore()
    
    // MARK: - User Profile
    func fetchUserProfile(uid: String, completion: @escaping (Result<UserProfile, Error>) -> Void) {
        print("🔍 [FirestoreService] Fetching user profile for UID: \(uid)")
        db.collection("members").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("❌ [FirestoreService] Error fetching user profile: \(error.localizedDescription)")
                completion(.failure(error))
            } else if let snapshot = snapshot, let data = try? snapshot.data(as: UserProfile.self) {
                print("✅ [FirestoreService] Successfully fetched user profile: \(data.name)")
                completion(.success(data))
            } else {
                print("❌ [FirestoreService] User not found or failed to decode for UID: \(uid)")
                completion(.failure(NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found"])) )
            }
        }
    }
    
    func createOrUpdateUserProfile(_ profile: UserProfile, completion: @escaping (Error?) -> Void) {
        do {
            try db.collection("members").document(profile.uid).setData(from: profile, merge: true) { error in
                completion(error)
            }
        } catch {
            completion(error)
        }
    }
    
    // MARK: - Programs
    func fetchPrograms(completion: @escaping (Result<[Program], Error>) -> Void) {
        print("🔍 [FirestoreService] Fetching programs from Firestore")
        print("🔍 [FirestoreService] Current user: \(Auth.auth().currentUser?.uid ?? "No user")")
        
        db.collection("programs").getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("❌ [FirestoreService] Error fetching programs: \(error.localizedDescription)")
                print("❌ [FirestoreService] Error code: \(error._code)")
                print("❌ [FirestoreService] Error domain: \(error._domain)")
                completion(.failure(error))
                return
            }
            
            guard let snapshot = snapshot else {
                print("❌ [FirestoreService] No snapshot returned")
                completion(.failure(NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data returned"])))
                return
            }
            
            print("📊 [FirestoreService] Found \(snapshot.documents.count) program documents")
            print("📊 [FirestoreService] Document IDs: \(snapshot.documents.map { $0.documentID })")
            
            // Log each document's data
            for doc in snapshot.documents {
                print("📄 [FirestoreService] Document \(doc.documentID): \(doc.data())")
            }
            
            if snapshot.documents.isEmpty {
                print("⚠️ [FirestoreService] No program documents found - this might be a permissions issue")
                completion(.success([]))
                return
            }
            
            let group = DispatchGroup()
            var programs: [Program] = []
            var fetchError: Error?
            
            for document in snapshot.documents {
                let programId = document.documentID
                print("🔍 [FirestoreService] Processing program: \(programId)")
                
                group.enter()
                self?.fetchCompleteProgram(programId: programId, document: document) { result in
                    switch result {
                    case .success(let program):
                        programs.append(program)
                        print("✅ [FirestoreService] Successfully loaded program: \(program.name)")
                    case .failure(let error):
                        print("❌ [FirestoreService] Error loading program \(programId): \(error.localizedDescription)")
                        fetchError = error
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                if let error = fetchError {
                    completion(.failure(error))
                } else {
                    print("✅ [FirestoreService] Successfully fetched \(programs.count) complete programs")
                    completion(.success(programs))
                }
            }
        }
    }
    
    private func fetchCompleteProgram(programId: String, document: DocumentSnapshot, completion: @escaping (Result<Program, Error>) -> Void) {
        print("🚀 [FirestoreService] fetchCompleteProgram called for \(programId)")
        let programData = document.data() ?? [:]
        print("📄 [FirestoreService] Program data for \(programId): \(programData)")
        print("📄 [FirestoreService] Program document fields: \(programData.keys.sorted())")

        // Map new Program fields
        let id = programData["id"] as? String ?? programId
        let name = programData["name"] as? String ?? "Unknown Program"
        let description = programData["description"] as? String ?? ""
        let color = programData["color"] as? String ?? ""
        let iconUrl = programData["iconUrl"] as? String ?? ""
        let accessLevelString = programData["accessLevel"] as? String ?? "free_public"
        let accessLevel = DataAccessLevel(rawValue: accessLevelString) ?? .freePublic
        let createdAt = programData["createdAt"] as? String ?? ""
        let updatedAt = programData["updatedAt"] as? String ?? ""
        let isActive = programData["isActive"] as? Bool ?? true
        let hasRanks = programData["hasRanks"] as? Bool ?? false
        let physicalStudentDiscount = programData["physicalStudentDiscount"] as? Bool ?? false

        // Decode forms
        var forms: [String: Form] = [:]
        if let embeddedForms = programData["forms"] as? [String: Any] {
            for (formId, formData) in embeddedForms {
                if let formDict = formData as? [String: Any],
                   let formData = try? JSONSerialization.data(withJSONObject: formDict),
                   let form = try? JSONDecoder().decode(Form.self, from: formData) {
                    forms[formId] = form
                }
            }
        }

        // Decode ranks
        var ranks: [String: Rank] = [:]
        if let embeddedRanks = programData["ranks"] as? [String: Any] {
            for (rankId, rankData) in embeddedRanks {
                if let rankDict = rankData as? [String: Any],
                   let rankData = try? JSONSerialization.data(withJSONObject: rankDict),
                   let rank = try? JSONDecoder().decode(Rank.self, from: rankData) {
                    ranks[rankId] = rank
                }
            }
        }

        // Decode techniques
        var techniques: [String: Technique] = [:]
        if let embeddedTechniques = programData["techniques"] as? [String: Any] {
            for (techId, techData) in embeddedTechniques {
                if let techDict = techData as? [String: Any],
                   let techData = try? JSONSerialization.data(withJSONObject: techDict),
                   let technique = try? JSONDecoder().decode(Technique.self, from: techData) {
                    techniques[techId] = technique
                }
            }
        }

        let program = Program(
            id: id,
            name: name,
            description: description,
            color: color,
            iconUrl: iconUrl,
            accessLevel: accessLevel,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isActive: isActive,
            hasRanks: hasRanks,
            physicalStudentDiscount: physicalStudentDiscount,
            dataStore: .firestore,
            forms: forms,
            ranks: ranks,
            techniques: techniques
        )
        completion(.success(program))
    }
    
    func fetchProgram(withId programId: String, completion: @escaping (Result<Program, Error>) -> Void) {
        print("🔍 [FirestoreService] fetchProgram(withId: \(programId)) called")
        
        db.collection("programs").document(programId).getDocument { snapshot, error in
            if let error = error {
                print("❌ [FirestoreService] Error fetching program document: \(error.localizedDescription)")
                completion(.failure(error))
            } else if let snapshot = snapshot, let data = snapshot.data() {
                print("✅ [FirestoreService] Found program document, loading subcollections...")
                
                // Use the same logic as fetchCompleteProgram to load subcollections
                self.fetchCompleteProgram(programId: programId, document: snapshot) { result in
                    switch result {
                    case .success(let program):
                        print("✅ [FirestoreService] Successfully loaded complete program: \(program.name)")
                        print("  - Forms: \(program.forms.count)")
                        print("  - Techniques: \(program.techniques.count)")
                        print("  - Ranks: \(program.ranks?.count ?? 0)")
                        completion(.success(program))
                    case .failure(let error):
                        print("❌ [FirestoreService] Error loading complete program: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                }
            } else {
                print("❌ [FirestoreService] Program document not found: \(programId)")
                completion(.failure(NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Program not found"])))
            }
        }
    }
    
    // Fetch program names for multiple program IDs
    func fetchProgramNames(for programIds: [String], completion: @escaping (Result<[String: String], Error>) -> Void) {
        print("🔍 [FirestoreService] Fetching program names for IDs: \(programIds)")
        
        guard !programIds.isEmpty else {
            completion(.success([:]))
            return
        }
        
        // Use batch to fetch multiple program documents efficiently
        let batch = programIds.map { programId in
            db.collection("programs").document(programId)
        }
        
        var programNames: [String: String] = [:]
        let dispatchGroup = DispatchGroup()
        var fetchError: Error?
        
        for (index, documentRef) in batch.enumerated() {
            let programId = programIds[index]
            dispatchGroup.enter()
            
            documentRef.getDocument { snapshot, error in
                defer { dispatchGroup.leave() }
                
                if let error = error {
                    print("❌ [FirestoreService] Error fetching program \(programId): \(error.localizedDescription)")
                    fetchError = error
                    return
                }
                
                if let snapshot = snapshot, let data = snapshot.data(),
                   let name = data["name"] as? String {
                    programNames[programId] = name
                    print("✅ [FirestoreService] Fetched program name: \(programId) -> \(name)")
                } else {
                    print("⚠️ [FirestoreService] No name found for program \(programId), using capitalized ID")
                    programNames[programId] = programId.capitalized
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if let error = fetchError {
                completion(.failure(error))
            } else {
                print("✅ [FirestoreService] Successfully fetched \(programNames.count) program names")
                completion(.success(programNames))
            }
        }
    }
    
    // Update program names in a UserProfile with names from Firestore
    func updateProfileWithFirestoreProgramNames(_ profile: UserProfile, completion: @escaping (Result<UserProfile, Error>) -> Void) {
        print("🔄 [FirestoreService] Updating profile program names from Firestore")
        
        // Extract all program IDs from the profile
        let programIds = Array(profile.programs.keys)
        
        guard !programIds.isEmpty else {
            print("ℹ️ [FirestoreService] No programs in profile to update")
            completion(.success(profile))
            return
        }
        
        // Fetch the program names from Firestore
        fetchProgramNames(for: programIds) { result in
            switch result {
            case .success(let firestoreProgramNames):
                print("✅ [FirestoreService] Got program names from Firestore: \(firestoreProgramNames)")
                
                // Update the program enrollments with correct names
                var updatedPrograms = profile.programs
                for (programId, enrollment) in profile.programs {
                    if let correctName = firestoreProgramNames[programId],
                       correctName != enrollment.programName {
                        print("🔄 [FirestoreService] Updating program name: \(enrollment.programName) -> \(correctName)")
                        
                        // Create updated enrollment with correct name
                        let updatedEnrollment = ProgramEnrollment(
                            programId: enrollment.programId,
                            programName: correctName, // Use the Firestore name
                            enrolled: enrollment.enrolled,
                            enrollmentDate: enrollment.enrollmentDate,
                            currentRank: enrollment.currentRank,
                            rankDate: enrollment.rankDate,
                            membershipType: enrollment.membershipType,
                            isActive: enrollment.isActive
                        )
                        updatedPrograms[programId] = updatedEnrollment
                    }
                }
                
                // Create updated profile with corrected program names
                let updatedProfile = UserProfile(
                    uid: profile.uid,
                    firebaseUid: profile.firebaseUid,
                    name: profile.name,
                    email: profile.email,
                    roles: profile.roles,
                    profilePhotoUrl: profile.profilePhotoUrl,
                    programs: updatedPrograms,
                    subscription: profile.subscription,
                    studioMembership: profile.studioMembership,
                    dataStore: profile.dataStore,
                    accessLevel: profile.accessLevel,
                    userType: profile.userType
                )
                
                print("✅ [FirestoreService] Successfully updated profile with Firestore program names")
                completion(.success(updatedProfile))
                
            case .failure(let error):
                print("❌ [FirestoreService] Failed to fetch program names: \(error.localizedDescription)")
                // Return original profile if fetching fails
                completion(.success(profile))
            }
        }
    }
    
    // Helper method to get ranks for a specific program
    func getRanks(for program: Program) -> [Rank] {
        return program.ranks?.values.sorted { $0.level < $1.level } ?? []
    }
    
    // Helper method to get forms for a specific program
    func getForms(for program: Program) -> [Form] {
        return program.forms.values.sorted { $0.name < $1.name }
    }
    
    // Helper method to get forms up to a specific rank
    func getFormsUpToRank(for program: Program, rankName: String) -> [Form] {
        guard let ranks = program.ranks else { return Array(program.forms.values) }
        // Find the rank level
        let targetRank = ranks.values.first { $0.name == rankName }
        let targetLevel = targetRank?.level ?? 0
        // Get all forms (since Form no longer has rankRequired property)
        return Array(program.forms.values).sorted { $0.name < $1.name }
    }
    
    // Helper method to get techniques for a specific program
    func getTechniques(for program: Program) -> [Technique] {
        return program.techniques.values.sorted { $0.name < $1.name }
    }
    
    // Helper method to get techniques up to a specific rank
    func getTechniquesUpToRank(for program: Program, rankName: String) -> [Technique] {
        guard let ranks = program.ranks else {
            return []
        }
        // Find the rank level
        let targetRank = ranks.values.first { $0.name == rankName }
        let targetLevel = targetRank?.level ?? 0
        // Get all techniques that require rank level <= target level
        return program.techniques.values.filter { technique in
            if let techniqueRank = ranks.values.first(where: { $0.id == technique.requiredRankId }) {
                return techniqueRank.level <= targetLevel
            }
            return false
        }.sorted { $0.name < $1.name }
    }
    
    // MARK: - Announcements & MediaContent
    func fetchAnnouncements(completion: @escaping (Result<[MediaContent], Error>) -> Void) {
        db.collection("announcements")
            .order(by: "publishedDate", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ [FirestoreService] Error fetching announcements: \(error)")
                    completion(.failure(error))
                } else if let snapshot = snapshot {
                    let announcements = snapshot.documents.compactMap { doc -> MediaContent? in
                        var data = doc.data()
                        data["id"] = doc.documentID
                        
                        do {
                            let announcement = try Firestore.Decoder().decode(MediaContent.self, from: data)
                            print("📢 [FirestoreService] Decoded announcement: \(announcement.title)")
                            return announcement
                        } catch {
                            print("❌ [FirestoreService] Error decoding announcement \(doc.documentID): \(error)")
                            return nil
                        }
                    }
                    
                    print("✅ [FirestoreService] Successfully fetched \(announcements.count) announcements")
                    completion(.success(announcements))
                } else {
                    print("ℹ️ [FirestoreService] No announcements found")
                    completion(.success([]))
                }
            }
    }
    
    // MARK: - Subscriptions
    func fetchSubscriptions(completion: @escaping (Result<[Subscription], Error>) -> Void) {
        db.collection("subscriptions").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
            } else if let snapshot = snapshot {
                let subs = snapshot.documents.compactMap { doc -> Subscription? in
                    var data = doc.data()
                    data["id"] = doc.documentID
                    return try? Firestore.Decoder().decode(Subscription.self, from: data)
                }
                completion(.success(subs))
            }
        }
    }
    
    // MARK: - Member Association
    func checkExistingMember(email: String, completion: @escaping (Result<UserProfile?, Error>) -> Void) {
        print("🔍 [FirestoreService] Checking for existing member with email: '\(email)'")
        print("🔍 [FirestoreService] Email length: \(email.count)")
        print("🔍 [FirestoreService] Email trimmed: '\(email.trimmingCharacters(in: .whitespacesAndNewlines))'")
        
        // First try exact match
        db.collection("members")
            .whereField("email", isEqualTo: email)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ [FirestoreService] Error checking existing member: \(error.localizedDescription)")
                    completion(.failure(error))
                } else if let snapshot = snapshot {
                    print("📊 [FirestoreService] Query returned \(snapshot.documents.count) documents")
                    
                    // Log all documents found for debugging
                    for (index, doc) in snapshot.documents.enumerated() {
                        print("📄 [FirestoreService] Document \(index): ID=\(doc.documentID), Data=\(doc.data())")
                    }
                    
                    if !snapshot.documents.isEmpty {
                        // Found existing member
                        if let doc = snapshot.documents.first {
                            let profile = try? doc.data(as: UserProfile.self)
                            if let profile = profile {
                                print("✅ [FirestoreService] Found existing member: \(profile.name) with UID: \(profile.uid)")
                                print("✅ [FirestoreService] Member roles: \(profile.roles)")
                            } else {
                                print("❌ [FirestoreService] Failed to decode existing member profile")
                                print("❌ [FirestoreService] Raw document data: \(doc.data())")
                            }
                            completion(.success(profile))
                        } else {
                            print("❌ [FirestoreService] No documents found for email: \(email)")
                            completion(.success(nil))
                        }
                    } else {
                        print("❌ [FirestoreService] No existing member found for email: \(email)")
                        
                        // Try case-insensitive search as fallback
                        print("🔍 [FirestoreService] Trying case-insensitive search...")
                        self.tryCaseInsensitiveSearch(email: email, completion: completion)
                    }
                } else {
                    print("❌ [FirestoreService] No snapshot returned")
                    completion(.success(nil))
                }
            }
    }
    
    private func tryCaseInsensitiveSearch(email: String, completion: @escaping (Result<UserProfile?, Error>) -> Void) {
        // Get all users and filter by email case-insensitively
        db.collection("members").getDocuments { snapshot, error in
            if let error = error {
                print("❌ [FirestoreService] Error in case-insensitive search: \(error.localizedDescription)")
                completion(.failure(error))
            } else if let snapshot = snapshot {
                print("📊 [FirestoreService] Case-insensitive search found \(snapshot.documents.count) total documents")
                
                // Find document with matching email (case-insensitive)
                let matchingDoc = snapshot.documents.first { doc in
                    if let docEmail = doc.data()["email"] as? String {
                        return docEmail.lowercased() == email.lowercased()
                    }
                    return false
                }
                
                if let matchingDoc = matchingDoc {
                    print("✅ [FirestoreService] Found matching document with case-insensitive search: \(matchingDoc.documentID)")
                    let profile = try? matchingDoc.data(as: UserProfile.self)
                    if let profile = profile {
                        print("✅ [FirestoreService] Successfully decoded profile: \(profile.name)")
                        completion(.success(profile))
                    } else {
                        print("❌ [FirestoreService] Failed to decode profile from case-insensitive search")
                        completion(.success(nil))
                    }
                } else {
                    print("❌ [FirestoreService] No matching document found with case-insensitive search")
                    
                    // Let's also try a broader search to see what's in the collection
                    print("🔍 [FirestoreService] Performing broader search to debug...")
                    for (index, doc) in snapshot.documents.prefix(5).enumerated() {
                        let data = doc.data()
                        print("📄 [FirestoreService] Sample doc \(index): ID=\(doc.documentID), Email=\(data["email"] ?? "NO_EMAIL"), Roles=\(data["roles"] ?? "NO_ROLES")")
                    }
                    
                    completion(.success(nil))
                }
            } else {
                print("❌ [FirestoreService] No snapshot returned from case-insensitive search")
                completion(.success(nil))
            }
        }
    }
    
    func fetchProfileByFirebaseUid(firebaseUid: String, completion: @escaping (UserProfile?, Error?) -> Void) {
        print("🔍 [FirestoreService] Fetching profile by Firebase UID: \(firebaseUid)")
        
        db.collection("members").whereField("firebaseUid", isEqualTo: firebaseUid).getDocuments { snapshot, error in
            if let error = error {
                print("❌ [FirestoreService] Error fetching profile by Firebase UID \(firebaseUid): \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let snapshot = snapshot, !snapshot.documents.isEmpty else {
                print("❌ [FirestoreService] Profile document not found for Firebase UID: \(firebaseUid)")
                completion(nil, NSError(domain: "FirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"]))
                return
            }
            
            // Should only be one document with this Firebase UID
            guard let document = snapshot.documents.first else {
                print("❌ [FirestoreService] No documents found for Firebase UID: \(firebaseUid)")
                completion(nil, NSError(domain: "FirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"]))
                return
            }
            
            print("✅ [FirestoreService] Found profile document for Firebase UID: \(firebaseUid)")
            print("📄 [FirestoreService] Document data: \(document.data())")
            
            do {
                let profile = try self.decodeUserProfile(from: document.data(), uid: document.documentID)
                print("✅ [FirestoreService] Successfully decoded profile: \(profile.name)")
                completion(profile, nil)
            } catch {
                print("❌ [FirestoreService] Error decoding profile: \(error.localizedDescription)")
                completion(nil, error)
            }
        }
    }
    
    func fetchProfileByUid(uid: String, completion: @escaping (UserProfile?, Error?) -> Void) {
        print("🔍 [FirestoreService] Fetching profile by UID: \(uid)")
        
        db.collection("members").document(uid).getDocument { document, error in
            if let error = error {
                print("❌ [FirestoreService] Error fetching profile by UID \(uid): \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let document = document, document.exists else {
                print("❌ [FirestoreService] Profile document not found for UID: \(uid)")
                completion(nil, NSError(domain: "FirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"]))
                return
            }
            
            print("✅ [FirestoreService] Found profile document for UID: \(uid)")
            print("📄 [FirestoreService] Document data: \(document.data() ?? [:])")
            
            do {
                let profile = try self.decodeUserProfile(from: document.data() ?? [:], uid: uid)
                print("✅ [FirestoreService] Successfully decoded profile: \(profile.name)")
                completion(profile, nil)
            } catch {
                print("❌ [FirestoreService] Error decoding profile: \(error.localizedDescription)")
                completion(nil, error)
            }
        }
    }
    
    private func decodeUserProfile(from data: [String: Any], uid: String) throws -> UserProfile {
        let firebaseUid = data["firebaseUid"] as? String
        let name = data["name"] as? String ?? ""
        let email = data["email"] as? String ?? ""
        let roles = data["roles"] as? [String] ?? []
        let profilePhotoUrl = data["profilePhotoUrl"] as? String ?? ""
        
        // Program name mapping
        let programNames: [String: String] = [
            "kungfu": "Kung Fu",
            "taichi": "Tai Chi",
            "traditionalKungFu": "Traditional Kung Fu",
            "holisticTaiChi": "Holistic Tai Chi",
            "warriorKungFu": "Warrior Kung Fu",
            "youthKungFu": "Youth Kung Fu"
        ]
        
        // Decode programs with backward compatibility
        var programs: [String: ProgramEnrollment] = [:]
        if let programsData = data["programs"] as? [String: [String: Any]] {
            for (programId, enrollmentData) in programsData {
                // Firestore stores booleans as 1 (true) and 0 (false)
                let enrolled = (enrollmentData["enrolled"] as? Int) == 1
                
                let membershipTypeString = enrollmentData["membershipType"] as? String ?? "student"
                let membershipType = MembershipType(rawValue: membershipTypeString) ?? .student
                let currentRank = enrollmentData["currentRank"] as? String
                let joinedDateString = enrollmentData["joinedDate"] as? String
                
                // Parse join date
                var enrollmentDate = Date()
                if let joinedDateString = joinedDateString {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    enrollmentDate = formatter.date(from: joinedDateString) ?? Date()
                }
                
                // Parse rank date (if available)
                var rankDate: Date? = nil
                if let currentRank = currentRank {
                    // For now, assume rank was achieved 6 months after enrollment
                    // In a real system, this would come from the data
                    rankDate = Calendar.current.date(byAdding: .month, value: 6, to: enrollmentDate)
                }
                
                let programName = programNames[programId] ?? programId.capitalized
                
                let enrollment = ProgramEnrollment(
                    programId: programId,
                    programName: programName,
                    enrolled: enrolled,
                    enrollmentDate: enrollmentDate,
                    currentRank: currentRank,
                    rankDate: rankDate,
                    membershipType: membershipType,
                    isActive: enrolled
                )
                
                programs[programId] = enrollment
            }
        }
        
        // Handle backward compatibility for new fields
        let dataStoreString = data["dataStore"] as? String
        let dataStore = dataStoreString != nil ? DataStore(rawValue: dataStoreString!) ?? .iCloud : .iCloud
        
        let accessLevelString = data["accessLevel"] as? String ?? ""
        let accessLevel = DataAccessLevel(rawValue: accessLevelString) ?? .freePublic
        
        // Decode userType from Firestore data
        var userType: UserType = .freeUser // Default
        if let userTypeString = data["userType"] as? String {
            userType = UserType(rawValue: userTypeString) ?? .freeUser
        } else {
            // Determine userType from roles and programs if not present in data
            if roles.contains("student") {
                userType = .student
            } else if roles.contains("parent") {
                userType = .parent
            } else if roles.contains("instructor") {
                userType = .instructor
            } else if roles.contains("admin") {
                userType = .admin
            } else if programs.values.contains(where: { $0.enrolled }) {
                userType = .student
            } else {
                userType = .freeUser
            }
        }
        
        return UserProfile(
            uid: uid,
            firebaseUid: firebaseUid,
            name: name,
            email: email,
            roles: roles,
            profilePhotoUrl: profilePhotoUrl,
            programs: programs,
            subscription: nil, // Will be fetched separately
            studioMembership: nil, // Will be fetched separately
            dataStore: dataStore,
            accessLevel: accessLevel,
            userType: userType // Set the determined user type
        )
    }
    
    // MARK: - Subscription Management
    func fetchUserSubscription(userId: String, completion: @escaping (Result<UserSubscription?, Error>) -> Void) {
        print("🔍 [FirestoreService] Fetching subscription for user: \(userId)")
        
        // Query by userId field instead of using userId as document ID
        db.collection("subscriptions")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ [FirestoreService] Error fetching subscription: \(error.localizedDescription)")
                    completion(.failure(error))
                } else if let snapshot = snapshot, let doc = snapshot.documents.first {
                    do {
                        var data = doc.data()
                        data["id"] = doc.documentID
                        let subscription = try Firestore.Decoder().decode(UserSubscription.self, from: data)
                        print("✅ [FirestoreService] Successfully fetched subscription: \(subscription.subscriptionType.displayName)")
                        completion(.success(subscription))
                    } catch {
                        print("❌ [FirestoreService] Error decoding subscription: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                } else {
                    print("ℹ️ [FirestoreService] No subscription found for user: \(userId)")
                    completion(.success(nil))
                }
            }
    }
    
    func saveUserSubscription(_ subscription: UserSubscription, completion: @escaping (Error?) -> Void) {
        do {
            // Generate a unique document ID if one doesn't exist
            let documentId = subscription.id.isEmpty ? UUID().uuidString : subscription.id
            
            // Ensure the userId field is set
            var subscriptionData = subscription.toDictionary()
            subscriptionData["userId"] = subscription.userId
            subscriptionData["firebaseUid"] = subscription.userId // Also set firebaseUid for compatibility
            
            db.collection("subscriptions").document(documentId).setData(subscriptionData, merge: true) { error in
                if let error = error {
                    print("❌ [FirestoreService] Error saving subscription: \(error.localizedDescription)")
                } else {
                    print("✅ [FirestoreService] Successfully saved subscription for user: \(subscription.userId)")
                }
                completion(error)
            }
        } catch {
            print("❌ [FirestoreService] Error preparing subscription data: \(error.localizedDescription)")
            completion(error)
        }
    }
    
    // MARK: - Studio Membership
    func fetchStudioMembership(userId: String, completion: @escaping (Result<StudioMembership?, Error>) -> Void) {
        print("🔍 [FirestoreService] === FETCH STUDIO MEMBERSHIP CALLED ===")
        print("🔍 [FirestoreService] Fetching studio membership for user: \(userId)")
        print("🔍 [FirestoreService] Query: studioMemberships collection where userId == '\(userId)'")
        
        db.collection("studioMemberships").whereField("userId", isEqualTo: userId).getDocuments { snapshot, error in
            if let error = error {
                print("❌ [FirestoreService] Error fetching studio membership: \(error.localizedDescription)")
                completion(.failure(error))
            } else if let snapshot = snapshot {
                print("🔍 [FirestoreService] Query returned \(snapshot.documents.count) documents")
                if snapshot.documents.isEmpty {
                    print("📝 [FirestoreService] No documents found in studioMemberships collection for userId: \(userId)")
                    print("📝 [FirestoreService] This means either:")
                    print("   1. No studio membership exists for this user")
                    print("   2. The userId in Firestore doesn't match the query userId")
                    print("   3. The document exists but with a different userId field value")
                } else {
                    let doc = snapshot.documents.first!
                    print("✅ [FirestoreService] Found studio membership document: \(doc.documentID)")
                    print("📄 [FirestoreService] Document data: \(doc.data())")
                }
                
                if let doc = snapshot.documents.first {
                    do {
                        var data = doc.data()
                        data["id"] = doc.documentID
                        
                        // Handle missing/mismatched fields
                        print("🔧 [FirestoreService] Fixing document data for decoding...")
                        
                        // Map firebaseUid to userId if needed
                        if data["userId"] == nil, let firebaseUid = data["firebaseUid"] as? String {
                            data["userId"] = firebaseUid
                            print("🔧 [FirestoreService] Mapped firebaseUid to userId: \(firebaseUid)")
                        }
                        
                        // Convert isActive from Int to Bool
                        if let isActiveInt = data["isActive"] as? Int {
                            data["isActive"] = isActiveInt == 1
                            print("🔧 [FirestoreService] Converted isActive: \(isActiveInt) -> \(isActiveInt == 1)")
                        }
                        
                        // Add missing fields with defaults
                        if data["studioId"] == nil {
                            data["studioId"] = "shaolin_arts_kung_fu_tai_chi"
                            print("🔧 [FirestoreService] Added default studioId")
                        }
                        
                        if data["membershipNumber"] == nil, let userId = data["userId"] as? String {
                            data["membershipNumber"] = "SA-\(userId)"
                            print("🔧 [FirestoreService] Generated membershipNumber: SA-\(userId)")
                        }
                        
                        print("🔧 [FirestoreService] Attempting to decode with fixed data...")
                        let membership = try Firestore.Decoder().decode(StudioMembership.self, from: data)
                        print("✅ [FirestoreService] Successfully fetched studio membership: \(membership.studioName)")
                        completion(.success(membership))
                    } catch {
                        print("❌ [FirestoreService] Error decoding studio membership: \(error.localizedDescription)")
                        print("❌ [FirestoreService] Error details: \(error)")
                        completion(.failure(error))
                    }
                } else {
                    print("ℹ️ [FirestoreService] No studio membership found for user: \(userId)")
                    completion(.success(nil))
                }
            }
        }
    }
    
    func saveStudioMembership(_ membership: StudioMembership, completion: @escaping (Error?) -> Void) {
        do {
            // Generate a unique document ID if one doesn't exist
            let documentId = membership.id.isEmpty ? UUID().uuidString : membership.id
            
            // Ensure the userId field is set
            var membershipData = membership.toDictionary()
            membershipData["userId"] = membership.userId
            membershipData["firebaseUid"] = membership.userId // Also set firebaseUid for compatibility
            
            db.collection("studioMemberships").document(documentId).setData(membershipData, merge: true) { error in
                if let error = error {
                    print("❌ [FirestoreService] Error saving studio membership: \(error.localizedDescription)")
                } else {
                    print("✅ [FirestoreService] Successfully saved studio membership for user: \(membership.userId)")
                }
                completion(error)
            }
        } catch {
            print("❌ [FirestoreService] Error preparing studio membership data: \(error.localizedDescription)")
            completion(error)
        }
    }
    
    // MARK: - Premium Programs (Subscription Required)
    func fetchPremiumPrograms(completion: @escaping (Result<[Program], Error>) -> Void) {
        db.collection("premiumPrograms").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
            } else if let snapshot = snapshot {
                let programs = snapshot.documents.compactMap { doc -> Program? in
                    var data = doc.data()
                    data["id"] = doc.documentID
                    return try? Firestore.Decoder().decode(Program.self, from: data)
                }
                completion(.success(programs))
            }
        }
    }
    
    func fetchPremiumProgram(withId programId: String, completion: @escaping (Result<Program, Error>) -> Void) {
        db.collection("premiumPrograms").document(programId).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
            } else if let snapshot = snapshot, let data = snapshot.data() {
                var programData = data
                programData["id"] = programId
                if let program = try? Firestore.Decoder().decode(Program.self, from: programData) {
                    completion(.success(program))
                } else {
                    completion(.failure(NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode program"])))
                }
            } else {
                completion(.failure(NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Program not found"])))
            }
        }
    }
    
    // MARK: - Premium Media Content
    func fetchPremiumMediaContent(completion: @escaping (Result<[MediaContent], Error>) -> Void) {
        db.collection("premiumMediaContent").order(by: "publishedDate", descending: true).getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
            } else if let snapshot = snapshot {
                let content = snapshot.documents.compactMap { doc -> MediaContent? in
                    var data = doc.data()
                    data["id"] = doc.documentID
                    return try? Firestore.Decoder().decode(MediaContent.self, from: data)
                }
                completion(.success(content))
            }
        }
    }
    
    func savePremiumMediaContent(_ content: MediaContent, completion: @escaping (Error?) -> Void) {
        do {
            let encoder = Firestore.Encoder()
            var data = try encoder.encode(content)
            data["id"] = content.id
            
            db.collection("premiumMediaContent").document(content.id).setData(data) { error in
                if let error = error {
                    completion(error)
                } else {
                    completion(nil)
                }
            }
        } catch {
            completion(error)
        }
    }
    
    // MARK: - Subscription Plans
    func fetchSubscriptionPlans(completion: @escaping (Result<[Subscription], Error>) -> Void) {
        db.collection("subscriptionPlans").getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
            } else if let snapshot = snapshot {
                let plans = snapshot.documents.compactMap { doc -> Subscription? in
                    var data = doc.data()
                    data["id"] = doc.documentID
                    return try? Firestore.Decoder().decode(Subscription.self, from: data)
                }
                completion(.success(plans))
            }
        }
    }
    
    // MARK: - Access Control
    func checkUserAccess(userId: String, programId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        // First check if user has an active subscription
        fetchUserSubscription(userId: userId) { result in
            switch result {
            case .success(let subscription):
                if let subscription = subscription, subscription.isActive {
                    // Check if the subscription type allows access to this program
                    // This would typically involve checking the program's subscription requirements
                    completion(.success(true))
                } else {
                    completion(.success(false))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Legacy Member Operations (for existing data)
    func fetchExistingMember(uid: String, completion: @escaping (UserProfile?, Error?) -> Void) {
        print("🔍 [FirestoreService] Fetching existing member by UID: \(uid)")
        
        db.collection("members").document(uid).getDocument { document, error in
            if let error = error {
                print("❌ [FirestoreService] Error fetching existing member: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let document = document, document.exists else {
                print("❌ [FirestoreService] Existing member not found for UID: \(uid)")
                completion(nil, NSError(domain: "FirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Member not found"]))
                return
            }
            
            print("✅ [FirestoreService] Found existing member: \(document.data()?["name"] ?? "Unknown")")
            
            do {
                let profile = try self.decodeExistingMember(from: document.data() ?? [:], uid: uid)
                completion(profile, nil)
            } catch {
                print("❌ [FirestoreService] Error decoding existing member: \(error.localizedDescription)")
                completion(nil, error)
            }
        }
    }
    
    private func decodeExistingMember(from data: [String: Any], uid: String) throws -> UserProfile {
        let email = data["email"] as? String ?? ""
        let name = data["name"] as? String ?? ""
        let profilePhotoUrl = data["profilePhotoUrl"] as? String ?? ""
        let roles = data["roles"] as? [String] ?? []
        let firebaseUid = data["firebaseUid"] as? String
        let dataStore = data["dataStore"] as? String ?? "icloud"
        let accessLevelString = data["accessLevel"] as? String ?? "free_public"
        let accessLevel = DataAccessLevel(rawValue: accessLevelString) ?? .freePublic
        
        // Program name mapping
        let programNames: [String: String] = [
            "kungfu": "Kung Fu",
            "taichi": "Tai Chi",
            "traditionalKungFu": "Traditional Kung Fu",
            "holisticTaiChi": "Holistic Tai Chi",
            "warriorKungFu": "Warrior Kung Fu",
            "youthKungFu": "Youth Kung Fu"
        ]
        
        // Decode programs from the actual Firestore structure
        var programs: [String: ProgramEnrollment] = [:]
        if let programsData = data["programs"] as? [String: [String: Any]] {
            for (programId, enrollmentData) in programsData {
                // Firestore stores booleans as 1 (true) and 0 (false)
                let enrolled = (enrollmentData["enrolled"] as? Int) == 1
                
                let membershipTypeString = enrollmentData["membershipType"] as? String ?? "student"
                let membershipType = MembershipType(rawValue: membershipTypeString) ?? .student
                let currentRank = enrollmentData["currentRank"] as? String
                let joinedDateString = enrollmentData["joinedDate"] as? String
                
                // Parse join date
                var enrollmentDate = Date()
                if let joinedDateString = joinedDateString {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    enrollmentDate = formatter.date(from: joinedDateString) ?? Date()
                }
                
                // Parse rank date (if available)
                var rankDate: Date? = nil
                if let currentRank = currentRank {
                    // For now, assume rank was achieved 6 months after enrollment
                    // In a real system, this would come from the data
                    rankDate = Calendar.current.date(byAdding: .month, value: 6, to: enrollmentDate)
                }
                
                let programName = programNames[programId] ?? programId.capitalized
                
                let enrollment = ProgramEnrollment(
                    programId: programId,
                    programName: programName,
                    enrolled: enrolled,
                    enrollmentDate: enrollmentDate,
                    currentRank: currentRank,
                    rankDate: rankDate,
                    membershipType: membershipType,
                    isActive: enrolled
                )
                
                programs[programId] = enrollment
                print("📋 [FirestoreService] Decoded program: \(programName) (enrolled: \(enrolled), rank: \(currentRank ?? "none"))")
            }
        }
        
        // Convert dataStore and accessLevel strings to enums
        let dataStoreEnum: DataStore = dataStore == "icloud" ? .iCloud : .firestore
        
        return UserProfile(
            uid: uid,
            firebaseUid: firebaseUid,
            name: name,
            email: email,
            roles: roles,
            profilePhotoUrl: profilePhotoUrl,
            programs: programs,
            subscription: nil, // Will be fetched separately
            studioMembership: nil, // Will be fetched separately
            dataStore: dataStoreEnum,
            accessLevel: accessLevel
        )
    }
    
    func associateFirebaseUserWithExistingMember(firebaseUid: String, existingUid: String, completion: @escaping (Error?) -> Void) {
        print("🔗 [FirestoreService] Associating Firebase UID \(firebaseUid) with existing member \(existingUid)")
        
        let updateData: [String: Any] = [
            "firebaseUid": firebaseUid
        ]
        
        db.collection("members").document(existingUid).updateData(updateData) { error in
            if let error = error {
                print("❌ [FirestoreService] Failed to associate Firebase UID: \(error.localizedDescription)")
                completion(error)
            } else {
                print("✅ [FirestoreService] Successfully associated Firebase UID with existing member")
                completion(nil)
            }
        }
    }
    
    func createStudioMembershipFromExistingMember(memberUid: String, completion: @escaping (Error?) -> Void) {
        print("📝 [FirestoreService] Creating studio membership from existing member: \(memberUid)")
        print("📝 [FirestoreService] This should be the Firebase UID: \(memberUid)")
        
        // First, let's check if there's an existing member document with this Firebase UID
        db.collection("members").whereField("firebaseUid", isEqualTo: memberUid).getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("❌ [FirestoreService] Error finding member by Firebase UID: \(error.localizedDescription)")
                completion(error)
                return
            }
            
            if let snapshot = snapshot, let doc = snapshot.documents.first {
                print("✅ [FirestoreService] Found member document by Firebase UID: \(doc.documentID)")
                print("📄 [FirestoreService] Member data: \(doc.data())")
                
                // Use the document ID (not Firebase UID) to get the full member data
                self?.createStudioMembershipFromMemberDocument(doc, completion: completion)
            } else {
                print("❌ [FirestoreService] No member found with Firebase UID: \(memberUid)")
                print("🔍 [FirestoreService] Let's try to find any member documents...")
                
                // Fallback: try to find any member document
                self?.db.collection("members").limit(to: 5).getDocuments { snapshot, error in
                    if let error = error {
                        print("❌ [FirestoreService] Error listing members: \(error.localizedDescription)")
                        completion(error)
                        return
                    }
                    
                    if let snapshot = snapshot {
                        print("📊 [FirestoreService] Found \(snapshot.documents.count) member documents")
                        for doc in snapshot.documents {
                            let data = doc.data()
                            print("📄 [FirestoreService] Member \(doc.documentID): name=\(data["name"] ?? "Unknown"), email=\(data["email"] ?? "Unknown"), firebaseUid=\(data["firebaseUid"] ?? "None")")
                        }
                    }
                    
                    completion(NSError(domain: "FirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No member found with Firebase UID: \(memberUid)"]))
                }
            }
        }
    }
    
    private func createStudioMembershipFromMemberDocument(_ document: QueryDocumentSnapshot, completion: @escaping (Error?) -> Void) {
        let memberUid = document.documentID
        let data = document.data()
        
        print("✅ [FirestoreService] Creating studio membership from member document: \(memberUid)")
        print("📄 [FirestoreService] Member data: \(data)")
        
        // Extract program data from the actual Firestore structure
        let programsData = data["programs"] as? [String: [String: Any]] ?? [:]
        print("📊 [FirestoreService] Programs data: \(programsData)")
        
        var programEnrollments: [ProgramEnrollment] = []
        
        // Program name mapping
        let programNames: [String: String] = [
            "kungfu": "Kung Fu",
            "taichi": "Tai Chi",
            "traditionalKungFu": "Traditional Kung Fu",
            "holisticTaiChi": "Holistic Tai Chi",
            "warriorKungFu": "Warrior Kung Fu",
            "youthKungFu": "Youth Kung Fu"
        ]
        
        for (programId, enrollmentData) in programsData {
            // Firestore stores booleans as 1 (true) and 0 (false)
            let enrolled = (enrollmentData["enrolled"] as? Int) == 1
            print("📋 [FirestoreService] Program \(programId): enrolled = \(enrollmentData["enrolled"] ?? "nil") -> \(enrolled)")
            
            let membershipTypeString = enrollmentData["membershipType"] as? String ?? "student"
            let membershipType = MembershipType(rawValue: membershipTypeString) ?? .student
            let currentRank = enrollmentData["currentRank"] as? String
            let joinedDateString = enrollmentData["joinedDate"] as? String
            
            // Parse join date
            var enrollmentDate = Date()
            if let joinedDateString = joinedDateString {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                enrollmentDate = formatter.date(from: joinedDateString) ?? Date()
            }
            
            // Parse rank date (if available)
            var rankDate: Date? = nil
            if let currentRank = currentRank {
                // For now, assume rank was achieved 6 months after enrollment
                // In a real system, this would come from the data
                rankDate = Calendar.current.date(byAdding: .month, value: 6, to: enrollmentDate)
            }
            
            let programName = programNames[programId] ?? programId.capitalized
            
            let enrollment = ProgramEnrollment(
                programId: programId,
                programName: programName,
                enrolled: enrolled,
                enrollmentDate: enrollmentDate,
                currentRank: currentRank,
                rankDate: rankDate,
                membershipType: membershipType,
                isActive: enrolled
            )
            
            programEnrollments.append(enrollment)
            print("📋 [FirestoreService] Created enrollment for \(programName): \(currentRank ?? "No rank")")
        }
        
        // Create studio membership with the new structure
        let membership = StudioMembership(
            id: "membership_\(memberUid)",
            userId: memberUid,
            studioId: "shaolin_arts_kung_fu_tai_chi",
            studioName: "Shaolin Arts Kung Fu & Tai Chi",
            membershipNumber: "SA-\(memberUid)",
            startDate: Date(),
            endDate: nil,
            membershipType: .student,
            programEnrollments: programEnrollments,
            isActive: true,
            discountPercentage: 25.0
        )
        
        print("🏛️ [FirestoreService] Creating studio membership for: \(membership.studioName)")
        print("📊 [FirestoreService] Programs: \(programEnrollments.map { "\($0.programName) (\($0.currentRank ?? "No rank"))" }.joined(separator: ", "))")
        print("💾 [FirestoreService] About to save studio membership with ID: \(membership.id)")
        
        // Save studio membership
        saveStudioMembership(membership) { error in
            if let error = error {
                print("❌ [FirestoreService] Error saving studio membership: \(error.localizedDescription)")
                completion(error)
            } else {
                print("✅ [FirestoreService] Successfully saved studio membership, now creating subscription")
                // Create subscription for studio member
                let subscription = UserSubscription(
                    id: "subscription_\(memberUid)",
                    userId: memberUid,
                    subscriptionType: .studioMember,
                    status: .active,
                    startDate: Date(),
                    endDate: nil,
                    autoRenew: true,
                    studioMembershipId: membership.id,
                    lastBillingDate: Date(),
                    nextBillingDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())
                )
                
                print("💳 [FirestoreService] Creating studio member subscription")
                
                self.saveUserSubscription(subscription) { subscriptionError in
                    if let subscriptionError = subscriptionError {
                        print("❌ [FirestoreService] Error creating subscription: \(subscriptionError)")
                        completion(subscriptionError)
                    } else {
                        print("✅ [FirestoreService] Successfully created studio membership and subscription")
                        completion(nil)
                    }
                }
            }
        }
    }
    
    // MARK: - Analytics Tracking
    func updateContentAnalytics(contentId: String, type: ContentType, completion: @escaping (Error?) -> Void) {
        let collectionName = getCollectionName(for: type)
        
        let updateData: [String: Any] = [
            "analytics.journalReferenceCount": FieldValue.increment(Int64(1)),
            "analytics.lastReferencedAt": FieldValue.serverTimestamp()
        ]
        
        db.collection(collectionName).document(contentId).updateData(updateData) { error in
            if let error = error {
                print("❌ [FirestoreService] Error updating analytics for \(type.displayName) (\(contentId)): \(error)")
                completion(error)
            } else {
                print("✅ [FirestoreService] Analytics updated for \(type.displayName) (\(contentId))")
                completion(nil)
            }
        }
    }
    
    func updateContentViewCount(contentId: String, type: ContentType, completion: @escaping (Error?) -> Void) {
        let collectionName = getCollectionName(for: type)
        
        let updateData: [String: Any] = [
            "analytics.viewCount": FieldValue.increment(Int64(1))
        ]
        
        db.collection(collectionName).document(contentId).updateData(updateData) { error in
            if let error = error {
                print("❌ [FirestoreService] Error updating view count for \(type.displayName) (\(contentId)): \(error)")
                completion(error)
            } else {
                print("✅ [FirestoreService] View count updated for \(type.displayName) (\(contentId))")
                completion(nil)
            }
        }
    }
    
    private func getCollectionName(for type: ContentType) -> String {
        switch type {
        case .program:
            return "programs"
        case .technique:
            return "techniques"
        case .form:
            return "forms"
        case .announcement:
            return "announcements"
        }
    }
    
    // MARK: - Rank Progress Calculation
    func calculateRankProgress(for program: Program, currentRankName: String, completedForms: [String] = [], completedTechniques: [String] = []) -> RankProgress {
        let ranks = program.ranks
        if let ranks = ranks {
            let currentRank = ranks.values.first { $0.name == currentRankName }
            let nextRank = ranks.values.filter { $0.level > (currentRank?.level ?? 0) }.sorted { $0.level < $1.level }.first
            guard let currentRank = currentRank else {
                return RankProgress(
                    currentRank: nil,
                    nextRank: nextRank,
                    progress: 0.0,
                    completedItems: [],
                    remainingItems: [],
                    requiredForms: [],
                    requiredTechniques: [],
                    completedForms: [],
                    completedTechniques: []
                )
            }
            // requirements is now a String, so we can't access .forms or .techniques
            // Instead, treat requirements as a description string
            // If you want to parse forms/techniques, you need to change the model or parse the string
            // For now, just leave these empty
            let requiredForms: [String] = []
            let requiredTechniques: [String] = []
            let completedFormItems: [String] = []
            let completedTechniqueItems: [String] = []
            let completedItems: [String] = []
            let remainingFormItems: [String] = []
            let remainingTechniqueItems: [String] = []
            let remainingItems: [String] = []
            let totalRequired = 0
            let progress = 0.0
            return RankProgress(
                currentRank: currentRank,
                nextRank: nextRank,
                progress: progress,
                completedItems: completedItems,
                remainingItems: remainingItems,
                requiredForms: requiredForms,
                requiredTechniques: requiredTechniques,
                completedForms: completedFormItems,
                completedTechniques: completedTechniqueItems
            )
        } else {
            return RankProgress(
                currentRank: nil,
                nextRank: nil,
                progress: 0.0,
                completedItems: [],
                remainingItems: [],
                requiredForms: [],
                requiredTechniques: [],
                completedForms: [],
                completedTechniques: []
            )
        }
    }
    
    func getRankProgression(for program: Program) -> [Rank] {
        if let ranks = program.ranks {
            return ranks.values.sorted { $0.level < $1.level }
        } else {
            return []
        }
    }
    
    func getNextRank(for program: Program, currentRankName: String) -> Rank? {
        let ranks = program.ranks
        if let ranks = ranks {
            let currentRank = ranks.values.first { $0.name == currentRankName }
            let currentLevel = currentRank?.level ?? 0
            let nextRanks = ranks.values
                .filter { $0.level > currentLevel }
                .sorted { $0.level < $1.level }
            return nextRanks.first
        } else {
            return nil
        }
    }
    
    // MARK: - Content Details
    func getFormDetails(for program: Program, formIds: [String]) -> [Form] {
        return formIds.compactMap { program.forms[$0] }
    }
    
    func getTechniqueDetails(for program: Program, techniqueIds: [String]) -> [Technique] {
        return techniqueIds.compactMap { program.techniques[$0] }
    }
    
    func getRankRequirementsDetails(for program: Program, rankName: String) -> (forms: [Form], techniques: [Technique]) {
        let ranks = program.ranks
        if let ranks = ranks {
            guard let rank = ranks.values.first(where: { $0.name == rankName }) else {
                return ([], [])
            }
            // requirements is now a String, so we can't access .forms or .techniques
            // For now, just return empty arrays
            return ([], [])
        } else {
            return ([], [])
        }
    }
    
    // MARK: - Test Methods
    func testFirestoreConnection(completion: @escaping (Bool, String) -> Void) {
        print("🧪 [FirestoreService] Testing Firestore connection...")
        
        // Test 1: Check if we can read the programs collection
        db.collection("programs").limit(to: 1).getDocuments { snapshot, error in
            if let error = error {
                print("❌ [FirestoreService] Test failed - Error reading programs: \(error.localizedDescription)")
                completion(false, "Error reading programs: \(error.localizedDescription)")
                return
            }
            
            if let snapshot = snapshot {
                print("✅ [FirestoreService] Test passed - Can read programs collection")
                print("📊 [FirestoreService] Found \(snapshot.documents.count) documents in test")
                completion(true, "Successfully connected to Firestore")
            } else {
                print("❌ [FirestoreService] Test failed - No snapshot returned")
                completion(false, "No snapshot returned")
            }
        }
    }
    
    func testProgramsCollection(completion: @escaping (Bool, String) -> Void) {
        print("🧪 [FirestoreService] Testing programs collection specifically...")
        
        db.collection("programs").getDocuments { snapshot, error in
            if let error = error {
                print("❌ [FirestoreService] Programs test failed: \(error.localizedDescription)")
                completion(false, "Error: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot else {
                print("❌ [FirestoreService] Programs test failed - No snapshot")
                completion(false, "No snapshot returned")
                return
            }
            
            print("✅ [FirestoreService] Programs test passed")
            print("📊 [FirestoreService] Found \(snapshot.documents.count) program documents")
            print("📊 [FirestoreService] Document IDs: \(snapshot.documents.map { $0.documentID })")
            
            for doc in snapshot.documents {
                print("📄 [FirestoreService] Document \(doc.documentID): \(doc.data())")
            }
            
            completion(true, "Found \(snapshot.documents.count) programs")
        }
    }
    
    func listAllMembers(completion: @escaping (Bool, String) -> Void) {
        print("🧪 [FirestoreService] Listing all member documents...")
        
        db.collection("members").getDocuments { snapshot, error in
            if let error = error {
                print("❌ [FirestoreService] Error listing members: \(error.localizedDescription)")
                completion(false, "Error: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot else {
                print("❌ [FirestoreService] No snapshot returned for members")
                completion(false, "No snapshot returned")
                return
            }
            
            print("✅ [FirestoreService] Found \(snapshot.documents.count) member documents")
            
            var memberInfo: [String] = []
            for doc in snapshot.documents {
                let data = doc.data()
                let name = data["name"] as? String ?? "Unknown"
                let email = data["email"] as? String ?? "Unknown"
                let firebaseUid = data["firebaseUid"] as? String ?? "None"
                let memberDesc = "\(doc.documentID): \(name) (\(email)) [Firebase: \(firebaseUid)]"
                memberInfo.append(memberDesc)
                print("📄 [FirestoreService] Member: \(memberDesc)")
            }
            
            let result = "Found \(snapshot.documents.count) members:\n" + memberInfo.joined(separator: "\n")
            completion(true, result)
        }
    }
    
    func checkStudioMembershipExists(userId: String, completion: @escaping (Bool, String) -> Void) {
        print("🔍 [FirestoreService] Checking if studio membership exists for user: \(userId)")
        
        db.collection("studioMemberships").whereField("userId", isEqualTo: userId).getDocuments { snapshot, error in
            if let error = error {
                print("❌ [FirestoreService] Error checking studio membership: \(error.localizedDescription)")
                completion(false, "Error: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot else {
                print("❌ [FirestoreService] No snapshot returned")
                completion(false, "No snapshot returned")
                return
            }
            
            if snapshot.documents.isEmpty {
                print("ℹ️ [FirestoreService] No studio membership found for user: \(userId)")
                completion(false, "No studio membership found")
            } else {
                print("✅ [FirestoreService] Found \(snapshot.documents.count) studio membership(s) for user: \(userId)")
                for doc in snapshot.documents {
                    let data = doc.data()
                    print("📄 [FirestoreService] Studio membership \(doc.documentID): \(data)")
                }
                completion(true, "Found \(snapshot.documents.count) studio membership(s)")
            }
        }
    }
    
    func listAllStudioMemberships(completion: @escaping (Bool, String) -> Void) {
        print("🧪 [FirestoreService] Listing all studio membership documents...")
        
        db.collection("studioMemberships").getDocuments { snapshot, error in
            if let error = error {
                print("❌ [FirestoreService] Error listing studio memberships: \(error.localizedDescription)")
                completion(false, "Error: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot else {
                print("❌ [FirestoreService] No snapshot returned for studio memberships")
                completion(false, "No snapshot returned")
                return
            }
            
            print("✅ [FirestoreService] Found \(snapshot.documents.count) studio membership documents")
            
            var membershipInfo: [String] = []
            for doc in snapshot.documents {
                let data = doc.data()
                let userId = data["userId"] as? String ?? "Unknown"
                let studioName = data["studioName"] as? String ?? "Unknown"
                let membershipType = data["membershipType"] as? String ?? "Unknown"
                let isActive = data["isActive"] as? Bool ?? false
                let membershipDesc = "\(doc.documentID): \(studioName) (User: \(userId), Type: \(membershipType), Active: \(isActive))"
                membershipInfo.append(membershipDesc)
                print("📄 [FirestoreService] Studio membership: \(membershipDesc)")
            }
            
            let result = "Found \(snapshot.documents.count) studio memberships:\n" + membershipInfo.joined(separator: "\n")
            completion(true, result)
        }
    }
    
    func listAllSubscriptions(completion: @escaping (Bool, String) -> Void) {
        print("🧪 [FirestoreService] Listing all subscription documents...")
        
        db.collection("subscriptions").getDocuments { snapshot, error in
            if let error = error {
                print("❌ [FirestoreService] Error listing subscriptions: \(error.localizedDescription)")
                completion(false, "Error: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot else {
                print("❌ [FirestoreService] No snapshot returned for subscriptions")
                completion(false, "No snapshot returned")
                return
            }
            
            print("✅ [FirestoreService] Found \(snapshot.documents.count) subscription documents")
            
            var subscriptionInfo: [String] = []
            for doc in snapshot.documents {
                let data = doc.data()
                let userId = data["userId"] as? String ?? "Unknown"
                let subscriptionType = data["subscriptionType"] as? String ?? "Unknown"
                let status = data["status"] as? String ?? "Unknown"
                let isActive = data["isActive"] as? Bool ?? false
                let subscriptionDesc = "\(doc.documentID): \(subscriptionType) (User: \(userId), Status: \(status), Active: \(isActive))"
                subscriptionInfo.append(subscriptionDesc)
                print("📄 [FirestoreService] Subscription: \(subscriptionDesc)")
            }
            
            let result = "Found \(snapshot.documents.count) subscriptions:\n" + subscriptionInfo.joined(separator: "\n")
            completion(true, result)
        }
    }
    
    func inspectFirestoreDocuments(completion: @escaping (Bool, String) -> Void) {
        print("🧪 [FirestoreService] Inspecting Firestore document field names...")
        
        var results: [String] = []
        
        // Check subscriptions
        db.collection("subscriptions").limit(to: 3).getDocuments { snapshot, error in
            if let error = error {
                results.append("❌ Error listing subscriptions: \(error.localizedDescription)")
            } else if let snapshot = snapshot {
                results.append("📊 Found \(snapshot.documents.count) subscription documents")
                for (index, doc) in snapshot.documents.enumerated() {
                    let data = doc.data()
                    let userId = data["userId"] as? String ?? "NO_USERID"
                    let uid = data["uid"] as? String ?? "NO_UID"
                    let firebaseUid = data["firebaseUid"] as? String ?? "NO_FIREBASEUID"
                    results.append("📄 Subscription \(index): userId=\(userId), uid=\(uid), firebaseUid=\(firebaseUid)")
                }
            }
            
            // Check studio memberships
            self.db.collection("studioMemberships").limit(to: 3).getDocuments { snapshot, error in
                if let error = error {
                    results.append("❌ Error listing studio memberships: \(error.localizedDescription)")
                } else if let snapshot = snapshot {
                    results.append("📊 Found \(snapshot.documents.count) studio membership documents")
                    for (index, doc) in snapshot.documents.enumerated() {
                        let data = doc.data()
                        let userId = data["userId"] as? String ?? "NO_USERID"
                        let uid = data["uid"] as? String ?? "NO_UID"
                        let firebaseUid = data["firebaseUid"] as? String ?? "NO_FIREBASEUID"
                        results.append("📄 Studio Membership \(index): userId=\(userId), uid=\(uid), firebaseUid=\(firebaseUid)")
                    }
                }
                
                // Check members
                self.db.collection("members").limit(to: 3).getDocuments { snapshot, error in
                    if let error = error {
                        results.append("❌ Error listing members: \(error.localizedDescription)")
                    } else if let snapshot = snapshot {
                        results.append("📊 Found \(snapshot.documents.count) member documents")
                        for (index, doc) in snapshot.documents.enumerated() {
                            let data = doc.data()
                            let userId = data["userId"] as? String ?? "NO_USERID"
                            let uid = data["uid"] as? String ?? "NO_UID"
                            let firebaseUid = data["firebaseUid"] as? String ?? "NO_FIREBASEUID"
                            results.append("📄 Member \(index): userId=\(userId), uid=\(uid), firebaseUid=\(firebaseUid)")
                        }
                    }
                    
                    let result = "Firestore Document Field Analysis:\n" + results.joined(separator: "\n")
                    completion(true, result)
                }
            }
        }
    }
    
    func testFetchWithUserId(userId: String, completion: @escaping (Bool, String) -> Void) {
        print("🧪 [FirestoreService] Testing fetch logic with userId: \(userId)")
        
        var results: [String] = []
        results.append("Testing fetch with userId: \(userId)")
        
        // Test 1: Fetch subscription
        db.collection("subscriptions").whereField("userId", isEqualTo: userId).getDocuments { snapshot, error in
            if let error = error {
                results.append("❌ Subscription fetch error: \(error.localizedDescription)")
            } else if let snapshot = snapshot {
                results.append("📊 Subscription query returned \(snapshot.documents.count) documents")
                for (index, doc) in snapshot.documents.enumerated() {
                    let data = doc.data()
                    results.append("📄 Subscription \(index): \(doc.documentID) - \(data)")
                }
            } else {
                results.append("❌ No subscription snapshot returned")
            }
            
            // Test 2: Fetch studio membership
            self.db.collection("studioMemberships").whereField("userId", isEqualTo: userId).getDocuments { snapshot, error in
                if let error = error {
                    results.append("❌ Studio membership fetch error: \(error.localizedDescription)")
                } else if let snapshot = snapshot {
                    results.append("📊 Studio membership query returned \(snapshot.documents.count) documents")
                    for (index, doc) in snapshot.documents.enumerated() {
                        let data = doc.data()
                        results.append("📄 Studio membership \(index): \(doc.documentID) - \(data)")
                    }
                } else {
                    results.append("❌ No studio membership snapshot returned")
                }
                
                // Test 3: Fetch member
                self.db.collection("members").whereField("firebaseUid", isEqualTo: userId).getDocuments { snapshot, error in
                    if let error = error {
                        results.append("❌ Member fetch error: \(error.localizedDescription)")
                    } else if let snapshot = snapshot {
                        results.append("📊 Member query returned \(snapshot.documents.count) documents")
                        for (index, doc) in snapshot.documents.enumerated() {
                            let data = doc.data()
                            results.append("📄 Member \(index): \(doc.documentID) - \(data)")
                        }
                    } else {
                        results.append("❌ No member snapshot returned")
                    }
                    
                    let result = "Fetch Test Results:\n" + results.joined(separator: "\n")
                    completion(true, result)
                }
            }
        }
    }
    
    func testProgramPermissions(completion: @escaping (Bool, String) -> Void) {
        print("🧪 [FirestoreService] Testing program permissions...")
        
        var results: [String] = []
        results.append("Testing program permissions...")
        
        // Test 1: Read programs collection
        db.collection("programs").limit(to: 1).getDocuments { snapshot, error in
            if let error = error {
                results.append("❌ Programs collection error: \(error.localizedDescription)")
                results.append("❌ Error code: \(error._code)")
                results.append("❌ Error domain: \(error._domain)")
            } else if let snapshot = snapshot {
                results.append("✅ Programs collection: Found \(snapshot.documents.count) documents")
                if let doc = snapshot.documents.first {
                    results.append("📄 Sample program: \(doc.documentID)")
                }
            } else {
                results.append("❌ No programs snapshot returned")
            }
            
            // Test 2: Read a specific program's subcollections
            if let programId = snapshot?.documents.first?.documentID {
                results.append("🔍 Testing subcollections for program: \(programId)")
                
                // Test ranks subcollection
                self.db.collection("programs").document(programId).collection("ranks").limit(to: 1).getDocuments { snapshot, error in
                    if let error = error {
                        results.append("❌ Ranks subcollection error: \(error.localizedDescription)")
                    } else if let snapshot = snapshot {
                        results.append("✅ Ranks subcollection: Found \(snapshot.documents.count) documents")
                    } else {
                        results.append("❌ No ranks snapshot returned")
                    }
                    
                    // Test forms subcollection
                    self.db.collection("programs").document(programId).collection("forms").limit(to: 1).getDocuments { snapshot, error in
                        if let error = error {
                            results.append("❌ Forms subcollection error: \(error.localizedDescription)")
                        } else if let snapshot = snapshot {
                            results.append("✅ Forms subcollection: Found \(snapshot.documents.count) documents")
                        } else {
                            results.append("❌ No forms snapshot returned")
                        }
                        
                        // Test techniques subcollection
                        self.db.collection("programs").document(programId).collection("techniques").limit(to: 1).getDocuments { snapshot, error in
                            if let error = error {
                                results.append("❌ Techniques subcollection error: \(error.localizedDescription)")
                            } else if let snapshot = snapshot {
                                results.append("✅ Techniques subcollection: Found \(snapshot.documents.count) documents")
                            } else {
                                results.append("❌ No techniques snapshot returned")
                            }
                            
                            let result = "Permission Test Results:\n" + results.joined(separator: "\n")
                            completion(true, result)
                        }
                    }
                }
            } else {
                results.append("⚠️ No program found to test subcollections")
                let result = "Permission Test Results:\n" + results.joined(separator: "\n")
                completion(true, result)
            }
        }
    }
    
    // MARK: - Announcements (Free Marketing Content)
    func saveAnnouncement(_ announcement: MediaContent, completion: @escaping (Error?) -> Void) {
        print("🔄 [FirestoreService] Saving announcement: \(announcement.title)")
        
        do {
            let encoder = Firestore.Encoder()
            var data = try encoder.encode(announcement)
            data["id"] = announcement.id
            
            db.collection("announcements").document(announcement.id).setData(data) { error in
                if let error = error {
                    print("❌ [FirestoreService] Error saving announcement: \(error)")
                    completion(error)
                } else {
                    print("✅ [FirestoreService] Announcement saved successfully")
                    completion(nil)
                }
            }
        } catch {
            print("❌ [FirestoreService] Error encoding announcement: \(error)")
            completion(error)
        }
    }
} 
