import Foundation
import Combine
import UIKit
import FirebaseAuth
import CloudKit

class DataService: ObservableObject {
    static let shared = DataService()
    
    private let cloudKitService = CloudKitService.shared
    private let firestoreService = FirestoreService.shared
    private let mediaStorageService = MediaStorageService.shared
    
    @Published var currentUser: UserProfile?
    @Published var userSubscription: UserSubscription?
    @Published var studioMembership: StudioMembership?
    @Published var isLoading = false
    
    // MARK: - Clean Architecture: Program Management
    @Published var programs: [String: Program] = [:] // programId -> Program
    @Published var enrollments: [String: Enrollment] = [:] // programId -> Enrollment
    
    var currentUserId: String {
        return currentUser?.uid ?? cloudKitService.currentUserID ?? ""
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Monitor iCloud status changes
        cloudKitService.$isSignedInToiCloud
            .sink { [weak self] isSignedIn in
                if isSignedIn {
                    self?.loadUserData()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - User Data Management
    func loadUserData() {
        print("🔄 [DataService] === LOAD USER DATA CALLED ===")
        print("🔄 [DataService] loadUserData called")
        
        guard let firebaseUser = Auth.auth().currentUser else {
            print("❌ [DataService] No Firebase user available")
            return
        }
        
        let firebaseUserId = firebaseUser.uid
        print("✅ [DataService] Using Firebase user ID for Firestore operations: \(firebaseUserId)")
        
        // Set loading state
        DispatchQueue.main.async {
            self.isLoading = true
            print("⏳ [DataService] Loading state set to true")
        }
        
        Task {
            await loadUserDataForFirebaseUser(firebaseUserId: firebaseUserId)
            
            // Check for member status updates after loading user data
            await checkForMemberStatusUpdate()
            
            // Refresh studio membership in case it was created after initial profile load
            print("🔄 [DataService] About to call refreshStudioMembership() from loadUserData")
            await refreshStudioMembership()
            print("🔄 [DataService] Completed refreshStudioMembership() call from loadUserData")
            
            // Clear loading state
            await MainActor.run {
                self.isLoading = false
                print("⏳ [DataService] Loading state set to false")
            }
        }
    }
    
    private func loadUserDataForFirebaseUser(firebaseUserId: String) async {
        print("🔄 [DataService] Loading user data for Firebase UID: \(firebaseUserId)")
        print("🔄 [DataService] Current DataService.currentUser: \(currentUser?.name ?? "nil")")
        print("🔄 [DataService] Current DataService.currentUser?.firebaseUid: \(currentUser?.firebaseUid ?? "nil")")
        
        // If we already have a current user with the correct Firebase UID, use it
        if let existingUser = currentUser, existingUser.firebaseUid == firebaseUserId {
            print("✅ [DataService] Using existing currentUser with matching Firebase UID: \(existingUser.name)")
            await handleExistingProfile(existingProfile: existingUser, firebaseUser: Auth.auth().currentUser!)
            return
        }
        
        // First try to get existing profile from Firestore
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            firestoreService.fetchProfileByFirebaseUid(firebaseUid: firebaseUserId) { profile, error in
                if let error = error {
                    print("❌ [DataService] Error fetching profile: \(error)")
                    continuation.resume()
                    return
                }
                
                if let existingProfile = profile {
                    print("✅ [DataService] Found existing profile by Firebase UID: \(existingProfile.name)")
                    print("✅ [DataService] Using existing profile UID: \(existingProfile.uid)")
                    print("✅ [DataService] Existing profile firebaseUid: \(existingProfile.firebaseUid)")
                    
                    // Continue with existing profile logic
                    Task {
                        await self.handleExistingProfile(existingProfile: existingProfile, firebaseUser: Auth.auth().currentUser!)
                    }
                } else {
                    print("ℹ️ [DataService] No existing profile found, creating new one")
                    print("ℹ️ [DataService] This might mean the profile association didn't work properly")
                    
                    // Continue with new profile logic
                    Task {
                        await self.handleNewProfile(firebaseUser: Auth.auth().currentUser!)
                    }
                }
                continuation.resume()
            }
        }
    }
    
    private func handleExistingProfile(existingProfile: UserProfile, firebaseUser: User) async {
        print("🔄 [DataService] Handling existing profile: \(existingProfile.name)")
        
        // Check if this member has enrolled programs
        let hasEnrolledPrograms = existingProfile.programs.values.contains { $0.enrolled == true }
        
        print("🔍 [DataService] Enrollment check:")
        print("  - hasEnrolledPrograms: \(hasEnrolledPrograms)")
        print("  - All programs: \(existingProfile.programs.values.map { "\($0.programName) (enrolled: \($0.enrolled), rank: \($0.currentRank ?? "none"))" }.joined(separator: ", "))")
        print("  - Programs count: \(existingProfile.programs.count)")
        print("  - Programs keys: \(existingProfile.programs.keys.joined(separator: ", "))")
        print("  - Existing studio membership: \(existingProfile.studioMembership?.studioName ?? "None")")
        
        if hasEnrolledPrograms {
            print("🔍 [DataService] Member has enrolled programs, checking for studio membership")
            print("📊 [DataService] Programs: \(existingProfile.programs.values.map { "\($0.programName) (enrolled: \($0.enrolled), rank: \($0.currentRank ?? "none"))" }.joined(separator: ", "))")
            
            // Try to load existing studio membership
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                print("🔍 [DataService] Fetching existing studio membership for user: \(firebaseUser.uid)")
                firestoreService.fetchStudioMembership(userId: firebaseUser.uid) { result in
                    switch result {
                    case .success(let membership):
                        if let membership = membership {
                            print("✅ [DataService] Found existing studio membership: \(membership.studioName)")
                            print("✅ [DataService] Studio membership already exists, skipping creation")
                        } else {
                            print("🔄 [DataService] No studio membership found, creating one from existing member data")
                            print("🔄 [DataService] Starting studio membership creation for user: \(firebaseUser.uid)")
                            // Create studio membership from existing member data
                            self.firestoreService.createStudioMembershipFromExistingMember(memberUid: firebaseUser.uid) { error in
                                if let error = error {
                                    print("❌ [DataService] Error creating studio membership: \(error)")
                                    print("❌ [DataService] Error details: \(error.localizedDescription)")
                                } else {
                                    print("✅ [DataService] Successfully created studio membership from existing member")
                                }
                                continuation.resume()
                            }
                            return // Don't call continuation.resume() here since we're handling it in the completion
                        }
                    case .failure(let error):
                        print("❌ [DataService] Error checking studio membership: \(error)")
                        print("❌ [DataService] Error details: \(error.localizedDescription)")
                    }
                    continuation.resume()
                }
            }
            
            // Now load subscription and studio membership data from Firestore (after creation if needed)
            await loadSubscriptionData(userId: firebaseUser.uid)
        } else {
            // Load subscription and studio membership data from Firestore
            await loadSubscriptionData(userId: firebaseUser.uid)
        }
        
        // Create a complete profile with all the data
        var completeProfile = existingProfile
        
        // Debug: Print current user type
        print("🔍 [DataService] Current profile userType: \(existingProfile.userType)")
        print("🔍 [DataService] Current profile roles: \(existingProfile.roles)")
        print("🔍 [DataService] Current profile hasEnrolledPrograms: \(existingProfile.hasEnrolledPrograms())")
        print("🔍 [DataService] Current profile programs count: \(existingProfile.programs.count)")
        print("🔍 [DataService] Current profile programs: \(existingProfile.programs.keys.joined(separator: ", "))")
        for (programId, enrollment) in existingProfile.programs {
            print("  - Program \(programId): \(enrollment.programName) (enrolled: \(enrollment.enrolled), rank: \(enrollment.currentRank ?? "none"))")
        }
        
        // Update with subscription data if available
        if let subscription = userSubscription {
            completeProfile = UserProfile(
                uid: existingProfile.uid,
                firebaseUid: existingProfile.firebaseUid,
                name: existingProfile.name,
                email: existingProfile.email,
                roles: existingProfile.roles,
                profilePhotoUrl: existingProfile.profilePhotoUrl,
                programs: existingProfile.programs,
                subscription: subscription,
                studioMembership: existingProfile.studioMembership,
                dataStore: existingProfile.dataStore,
                accessLevel: existingProfile.accessLevel,
                userType: existingProfile.userType // Preserve the user type
            )
            print("✅ [DataService] Profile updated with subscription, userType preserved: \(completeProfile.userType)")
        }
        
        // Update with studio membership data if available
        if let membership = studioMembership {
            print("🔄 [DataService] Updating profile with studio membership: \(membership.studioName)")
            print("🔄 [DataService] Studio membership ID: \(membership.id)")
            print("🔄 [DataService] Studio membership userId: \(membership.userId)")
            completeProfile = UserProfile(
                uid: completeProfile.uid,
                firebaseUid: completeProfile.firebaseUid,
                name: completeProfile.name,
                email: completeProfile.email,
                roles: completeProfile.roles,
                profilePhotoUrl: completeProfile.profilePhotoUrl,
                programs: completeProfile.programs,
                subscription: completeProfile.subscription,
                studioMembership: membership,
                dataStore: completeProfile.dataStore,
                accessLevel: completeProfile.accessLevel,
                userType: completeProfile.userType // Preserve the user type
            )
            print("✅ [DataService] Profile updated with studio membership, userType preserved: \(completeProfile.userType)")
        } else {
            print("ℹ️ [DataService] No studio membership available to add to profile")
            print("ℹ️ [DataService] studioMembership property is nil")
            print("ℹ️ [DataService] This means the studio membership wasn't loaded properly")
        }
        
        // Final debug: Print the complete profile user type
        print("🔍 [DataService] Final complete profile userType: \(completeProfile.userType)")
        print("🔍 [DataService] Final complete profile roles: \(completeProfile.roles)")
        print("🔍 [DataService] Final complete profile hasEnrolledPrograms: \(completeProfile.hasEnrolledPrograms())")
        
        // Save the complete profile to iCloud
        do {
            try await saveUserProfile(completeProfile)
            print("✅ [DataService] Successfully saved complete profile to iCloud: \(completeProfile.name)")
            print("✅ [DataService] Profile studio membership: \(completeProfile.studioMembership?.studioName ?? "None")")
            
            // Update program names from Firestore before setting as current user
            await updateProgramNamesFromFirestore(profile: completeProfile)
            
        } catch {
            print("❌ [DataService] Error saving profile to iCloud: \(error)")
            // Fallback: just use the profile without saving to iCloud
            await updateProgramNamesFromFirestore(profile: completeProfile)
        }
    }
    
    private func updateProgramNamesFromFirestore(profile: UserProfile) async {
        // Convert legacy ProgramEnrollments to new Enrollment
        await MainActor.run {
            print("🔄 [DataService] Converting profile to clean architecture")
            
            // Extract enrollment data (without program names)
            self.enrollments = profile.programs.mapValues { programEnrollment in
                Enrollment.from(programEnrollment)
            }
            
            print("✅ [DataService] Converted \(self.enrollments.count) enrollments")
            for (programId, enrollment) in self.enrollments {
                print("  - Program \(programId): enrolled=\(enrollment.enrolled), rank=\(enrollment.currentRank ?? "none")")
            }
            
            // Set the current user (temporarily with old structure for backward compatibility)
            self.currentUser = profile
        }
        
        // Load the actual Program objects
        await loadEnrolledPrograms()
        
        print("✅ [DataService] Clean architecture setup complete!")
        print("✅ [DataService] Enrolled programs: \(enrolledPrograms.count)")
        for (enrollment, program) in enrolledPrograms {
            print("  - \(program.id): \(program.name) (rank: \(enrollment.currentRank ?? "none"))")
        }
    }
    
    private func handleNewProfile(firebaseUser: User) async {
        print("🔄 [DataService] Handling new profile for user: \(firebaseUser.uid)")
        print("🔄 [DataService] Firebase user email: \(firebaseUser.email ?? "nil")")
        print("🔄 [DataService] Firebase user display name: \(firebaseUser.displayName ?? "nil")")
        
        // No existing profile found, try using Firebase UID as document ID (for new users)
        let profile: UserProfile? = await withCheckedContinuation { (continuation: CheckedContinuation<UserProfile?, Never>) in
            firestoreService.fetchProfileByUid(uid: firebaseUser.uid) { profile, error in
                if let error = error {
                    print("❌ [DataService] Error fetching profile by UID: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else if let profile = profile {
                    print("✅ [DataService] Found existing profile by UID: \(profile.name)")
                    continuation.resume(returning: profile)
                } else {
                    print("ℹ️ [DataService] No existing profile found by UID")
                    continuation.resume(returning: nil)
                }
            }
        }
        
        if let profile = profile {
            print("✅ [DataService] Using existing profile: \(profile.name)")
            // Update program names from Firestore before setting as current user
            await updateProgramNamesFromFirestore(profile: profile)
            
            // Load subscription and studio membership data
            await loadSubscriptionData(userId: firebaseUser.uid)
            
            // Try to sync with iCloud if available
            if let cloudKitUserId = cloudKitService.currentUserID {
                await syncFirestoreDataWithProfile(userId: cloudKitUserId, profile: profile)
            }
        } else {
            print("❌ [DataService] No profile found for UID: \(firebaseUser.uid)")
            print("🔄 [DataService] Profile should be created by AuthViewModel during sign-in")
            
            // Don't create profile here - it should be created by AuthViewModel
            // Just keep loading until profile is created
            // Retry loading after a short delay to catch newly created profiles
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                print("🔄 [DataService] Retrying profile load after 3 second delay")
                self.loadUserData()
            }
            
            // Add another retry after 6 seconds in case the first one didn't work
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                print("🔄 [DataService] Second retry profile load after 6 second delay")
                self.loadUserData()
            }
        }
    }
    
    private func checkForExistingMember(userId: String) async -> UserProfile? {
        print("🔍 [DataService] Checking for existing member in Firestore")
        
        return await withCheckedContinuation { (continuation: CheckedContinuation<UserProfile?, Never>) in
            firestoreService.fetchExistingMember(uid: userId) { profile, error in
                if let error = error {
                    print("❌ [DataService] Error fetching existing member: \(error)")
                    continuation.resume(returning: nil)
                } else if let profile = profile {
                    print("✅ [DataService] Found existing member: \(profile.name)")
                    continuation.resume(returning: profile)
                } else {
                    print("ℹ️ [DataService] No existing member found")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func createNewProfile(userId: String) async -> UserProfile? {
        // Get user info from Firebase Auth
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ [DataService] No Firebase user found")
            return nil
        }
        let name = currentUser.displayName ?? "New User"
        let email = currentUser.email ?? ""
        // NOTE: When assigning a starting rank, it must be the exact rank document ID from the program's ranks dictionary (e.g., 'blue2').
        // Create a basic profile
        let profile = UserProfile(
            uid: userId,
            firebaseUid: currentUser.uid,
            name: name,
            email: email,
            roles: ["public"],
            profilePhotoUrl: "",
            programs: [:],
            subscription: nil,
            studioMembership: nil,
            dataStore: .iCloud,
            accessLevel: .userPrivate
        )
        // Save to iCloud
        do {
            try await saveUserProfile(profile)
            print("✅ [DataService] Created new iCloud profile for user: \(userId)")
            return profile
        } catch {
            print("❌ [DataService] Error creating new profile: \(error)")
            return nil
        }
    }
    
    private func loadSubscriptionData(userId: String) async {
        print("🔄 [DataService] loadSubscriptionData called for userId: \(userId)")
        
        // Load subscription
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            print("🔍 [DataService] Fetching subscription for userId: \(userId)")
            firestoreService.fetchUserSubscription(userId: userId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let subscription):
                        print("✅ [DataService] Subscription loaded: \(subscription?.subscriptionType.displayName ?? "None")")
                        self.userSubscription = subscription
                    case .failure(let error):
                        print("❌ [DataService] Error loading subscription: \(error)")
                    }
                    continuation.resume()
                }
            }
        }
        
        // Load studio membership
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            print("🔍 [DataService] Fetching studio membership for userId: \(userId)")
            firestoreService.fetchStudioMembership(userId: userId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let membership):
                        print("🔄 [DataService] Studio membership loaded: \(membership?.studioName ?? "None")")
                        print("🔄 [DataService] Studio membership details: \(membership?.id ?? "No ID"), \(membership?.userId ?? "No userId")")
                        self.studioMembership = membership
                    case .failure(let error):
                        print("❌ [DataService] Error loading studio membership: \(error)")
                    }
                    continuation.resume()
                }
            }
        }
        
        print("✅ [DataService] loadSubscriptionData completed")
        print("✅ [DataService] Final subscription: \(userSubscription?.subscriptionType.displayName ?? "None")")
        print("✅ [DataService] Final studio membership: \(studioMembership?.studioName ?? "None")")
    }
    
    // MARK: - Clean Architecture: Program & Enrollment Management
    
    /// Get enrolled programs with their full Program objects
    var enrolledPrograms: [(enrollment: Enrollment, program: Program)] {
        return enrollments.compactMap { (programId, enrollment) in
            guard enrollment.enrolled,
                  let program = programs[programId] else { return nil }
            return (enrollment: enrollment, program: program)
        }
    }
    
    /// Get a program by ID
    func getProgram(id: String) -> Program? {
        return programs[id]
    }
    
    /// Get enrollment data for a program
    func getEnrollment(for programId: String) -> Enrollment? {
        return enrollments[programId]
    }
    
    /// Load programs for enrolled program IDs
    private func loadEnrolledPrograms() async {
        let enrolledProgramIds = Array(enrollments.keys)
        
        guard !enrolledProgramIds.isEmpty else {
            print("ℹ️ [DataService] No enrolled programs to load")
            return
        }
        
        print("🔄 [DataService] Loading programs for enrolled IDs: \(enrolledProgramIds)")
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            firestoreService.fetchPrograms { result in
                switch result {
                case .success(let allPrograms):
                    // Filter to only enrolled programs
                    let enrolledPrograms = allPrograms.filter { program in
                        enrolledProgramIds.contains(program.id)
                    }
                    
                    DispatchQueue.main.async {
                        // Update programs dictionary
                        for program in enrolledPrograms {
                            self.programs[program.id] = program
                        }
                        print("✅ [DataService] Loaded \(enrolledPrograms.count) enrolled programs")
                        for program in enrolledPrograms {
                            print("  - \(program.id): \(program.name)")
                        }
                    }
                    
                case .failure(let error):
                    print("❌ [DataService] Error loading programs: \(error.localizedDescription)")
                }
                continuation.resume()
            }
        }
    }
    
    // MARK: - Studio Membership Refresh
    
    func refreshStudioMembership(onNewMembershipFound: (() -> Void)? = nil) async {
        guard let currentUser = currentUser else {
            print("⚠️ [DataService] No current user to refresh studio membership for")
            return
        }
        
        print("🔄 [DataService] === REFRESH STUDIO MEMBERSHIP CALLED ===")
        print("🔄 [DataService] Refreshing studio membership for user: \(currentUser.uid)")
        print("🔍 [DataService] Current user firebaseUid: \(currentUser.firebaseUid ?? "nil")")
        print("🔍 [DataService] Current user has existing studioMembership: \(currentUser.studioMembership != nil)")
        if let existing = currentUser.studioMembership {
            print("🔍 [DataService] Existing membership: \(existing.studioName) (ID: \(existing.id))")
        }
        
        // Fetch latest studio membership from Firestore
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // Use firebaseUid for the query since that's what's stored in the userId field
            let queryUserId = currentUser.firebaseUid ?? currentUser.uid
            print("🔍 [DataService] Querying studio membership with userId: \(queryUserId)")
            firestoreService.fetchStudioMembership(userId: queryUserId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let membership):
                        if let membership = membership {
                            print("✅ [DataService] Found studio membership during refresh: \(membership.studioName)")
                            
                            // Check if this is a new membership or different from current
                            if currentUser.studioMembership?.id != membership.id {
                                print("🔄 [DataService] Studio membership is new or changed, updating profile")
                                
                                // Check if this is a completely new membership (user had no membership before)
                                let isNewMembership = currentUser.studioMembership == nil
                                
                                // Update the current user profile with the new membership
                                let updatedProfile = UserProfile(
                                    uid: currentUser.uid,
                                    firebaseUid: currentUser.firebaseUid,
                                    name: currentUser.name,
                                    email: currentUser.email,
                                    roles: currentUser.roles,
                                    profilePhotoUrl: currentUser.profilePhotoUrl,
                                    programs: currentUser.programs,
                                    subscription: currentUser.subscription,
                                    studioMembership: membership,
                                    dataStore: currentUser.dataStore,
                                    accessLevel: currentUser.accessLevel,
                                    userType: currentUser.userType
                                )
                                
                                // Update the published property
                                self.currentUser = updatedProfile
                                self.studioMembership = membership
                                
                                // Trigger celebration if this is a new membership
                                if isNewMembership {
                                    print("🎉 [DataService] New studio membership detected, triggering celebration!")
                                    onNewMembershipFound?()
                                }
                                
                                // Save to iCloud
                                Task {
                                    do {
                                        try await self.saveUserProfile(updatedProfile)
                                        print("✅ [DataService] Successfully saved updated profile with studio membership")
                                    } catch {
                                        print("❌ [DataService] Error saving updated profile: \(error)")
                                    }
                                }
                            } else {
                                print("ℹ️ [DataService] Studio membership unchanged")
                            }
                        } else {
                            print("ℹ️ [DataService] No studio membership found during refresh")
                        }
                    case .failure(let error):
                        print("❌ [DataService] Error refreshing studio membership: \(error)")
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    private func syncFirestoreDataWithProfile(userId: String, profile: UserProfile) async {
        print("🔄 [DataService] Syncing Firestore data with iCloud profile for user: \(userId)")
        
        var updatedProfile = profile
        var needsUpdate = false
        
        // Check if we have studio membership data from Firestore
        if let membership = studioMembership {
            print("✅ [DataService] Found studio membership: \(membership.studioName)")
            
            if profile.studioMembership?.id != membership.id {
                updatedProfile = UserProfile(
                    uid: profile.uid,
                    firebaseUid: profile.firebaseUid,
                    name: profile.name,
                    email: profile.email,
                    roles: profile.roles,
                    profilePhotoUrl: profile.profilePhotoUrl,
                    programs: profile.programs,
                    subscription: profile.subscription,
                    studioMembership: membership,
                    dataStore: profile.dataStore,
                    accessLevel: profile.accessLevel
                )
                needsUpdate = true
            }
        }
        
        // Check if we have subscription data from Firestore
        if let subscription = userSubscription {
            print("✅ [DataService] Found subscription: \(subscription.subscriptionType.displayName)")
            
            if profile.subscription?.id != subscription.id {
                updatedProfile = UserProfile(
                    uid: updatedProfile.uid,
                    firebaseUid: updatedProfile.firebaseUid,
                    name: updatedProfile.name,
                    email: updatedProfile.email,
                    roles: updatedProfile.roles,
                    profilePhotoUrl: updatedProfile.profilePhotoUrl,
                    programs: updatedProfile.programs,
                    subscription: subscription,
                    studioMembership: updatedProfile.studioMembership,
                    dataStore: updatedProfile.dataStore,
                    accessLevel: updatedProfile.accessLevel
                )
                needsUpdate = true
                print("🔄 [DataService] Updated profile with subscription info")
            }
        }
        
        if needsUpdate {
            // Save updated profile to iCloud
            do {
                try await saveUserProfile(updatedProfile)
                print("✅ [DataService] Successfully synced Firestore data with iCloud profile")
            } catch {
                print("❌ [DataService] Error syncing profile to iCloud: \(error)")
            }
        }
        
        // Update current user
        await MainActor.run {
            self.currentUser = updatedProfile
        }
    }
    
    // MARK: - Journal Operations (CloudKit)
    func saveJournalEntry(_ entry: JournalEntry) async throws {
        try await cloudKitService.saveJournalEntry(entry)
    }
    
    func fetchJournalEntries(for uid: String) async throws -> [JournalEntry] {
        return try await cloudKitService.fetchJournalEntries(for: uid)
    }
    
    func deleteJournalEntry(_ entryId: String) async throws {
        try await cloudKitService.deleteJournalEntry(entryId)
    }
    
    // MARK: - Custom Content Operations (CloudKit)
    func saveCustomContent(_ content: CustomContent) async throws {
        try await cloudKitService.saveCustomContent(content)
    }
    
    func fetchCustomContent(for uid: String) async throws -> [CustomContent] {
        return try await cloudKitService.fetchCustomContent(for: uid)
    }
    
    // MARK: - Program Operations (Hybrid)
    func fetchPrograms() async throws -> [Program] {
        var allPrograms: [Program] = []
        // Fetch free programs from CloudKit
        do {
            let freePrograms = try await cloudKitService.fetchFreePrograms()
            allPrograms.append(contentsOf: freePrograms)
        } catch {
            // Fallback to Firestore for free programs
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                firestoreService.fetchPrograms { result in
                    switch result {
                    case .success(let programs):
                        let freePrograms = programs.filter { $0.accessLevel == .freePublic }
                        allPrograms.append(contentsOf: freePrograms)
                    case .failure(let error):
                        print("❌ [DataService] Error fetching free programs from Firestore fallback: \(error)")
                    }
                    continuation.resume()
                }
            }
        }
        let hasAccess = (userSubscription?.isActive == true) || 
                       (currentUser?.studioMembership != nil) ||
                       (currentUser?.programs.values.contains(where: { (enrollment: ProgramEnrollment) in enrollment.enrolled && enrollment.membershipType == MembershipType.student }) ?? false)
        let enrolledProgramIds = currentUser?.programs.values
            .filter { $0.enrolled }
            .map { $0.programId } ?? []
        if hasAccess || !enrolledProgramIds.isEmpty {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                firestoreService.fetchPrograms { result in
                    switch result {
                    case .success(let firestorePrograms):
                        let programsToAdd = hasAccess ? firestorePrograms : firestorePrograms.filter { program in
                            enrolledProgramIds.contains(program.id)
                        }
                        allPrograms.append(contentsOf: programsToAdd)
                    case .failure(let error):
                        print("❌ [DataService] Error fetching programs from Firestore: \(error)")
                    }
                    continuation.resume()
                }
            }
        }
        return allPrograms
    }
    func fetchProgram(withId programId: String) async throws -> Program? {
        do {
            let freePrograms = try await cloudKitService.fetchFreePrograms()
            if let program = freePrograms.first(where: { $0.id == programId }) {
                return program
            }
        } catch {
            // Ignore error, fallback to Firestore
        }
        let isEnrolledInProgram = currentUser?.programs.values.contains(where: { enrollment in
            enrollment.enrolled && enrollment.programId == programId
        }) ?? false
        let hasGeneralAccess = (userSubscription?.isActive == true) || 
                              (currentUser?.studioMembership != nil) ||
                              (currentUser?.programs.values.contains(where: { (enrollment: ProgramEnrollment) in enrollment.enrolled && enrollment.membershipType == MembershipType.student }) ?? false)
        let shouldHaveAccess = isEnrolledInProgram || hasGeneralAccess
        if shouldHaveAccess {
            return await withCheckedContinuation { (continuation: CheckedContinuation<Program?, Never>) in
                firestoreService.fetchProgram(withId: programId) { result in
                    switch result {
                    case .success(let program):
                        continuation.resume(returning: program)
                    case .failure(_):
                        self.firestoreService.fetchPrograms { fallbackResult in
                            switch fallbackResult {
                            case .success(let allPrograms):
                                if let program = allPrograms.first(where: { $0.id == programId }) {
                                    continuation.resume(returning: program)
                                } else {
                                    continuation.resume(returning: nil)
                                }
                            case .failure(_):
                                continuation.resume(returning: nil)
                            }
                        }
                    }
                }
            }
        } else {
            return nil
        }
    }
    
    // MARK: - Media Content Operations (Refactored for Announcements)
    func fetchMediaContent() async throws -> [MediaContent] {
        print("🔄 [DataService] Starting fetchMediaContent (announcements only)...")
        
        // Fetch announcements from Firestore (free for all users)
        let announcements: [MediaContent] = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[MediaContent], Error>) in
            firestoreService.fetchAnnouncements { result in
                switch result {
                case .success(let content):
                    print("✅ [DataService] Successfully fetched \(content.count) announcements from Firestore")
                    continuation.resume(returning: content)
                case .failure(let error):
                    print("❌ [DataService] Error fetching announcements: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
        
        print("✅ [DataService] Returning \(announcements.count) announcements")
        return announcements
    }
    
    // MARK: - Test Data Creation
    func createTestAnnouncement() async throws {
        try await createTestAnnouncementInFirestore()
    }
    
    func createTestAnnouncementInFirestore() async throws {
        print("🔄 [DataService] Creating test announcement in Firestore...")
        
        let testAnnouncement = MediaContent(
            id: "test_announcement_\(UUID().uuidString)",
            title: "Welcome to SA Kung Fu Journal! 🥋",
            description: "This is a test announcement to verify that the announcement system is working properly. You should see this announcement in your feed as it's free marketing content for all users.",
            type: MediaContentType.announcement,
            mediaUrl: "",
            thumbnailUrl: nil,
            publishedDate: Date(),
            author: "SA Kung Fu Academy",
            tags: ["welcome", "test", "important", "marketing"],
            accessLevel: .freePublic, // Free for all users
            dataStore: .firestore,
            subscriptionRequired: .none, // No subscription required
            mediaStorageLocation: .appPublic,
            isUserGenerated: false,
            targeting: ContentTargeting(
                audience: .everyone, // Everyone can see it
                programs: nil,
                roles: nil,
                studios: nil,
                regions: nil,
                subscriptionTypes: nil, // No subscription targeting
                userAgeRange: nil,
                trialStatus: nil,
                userBehaviors: nil,
                targetRanks: nil,
                targetTechniques: nil,
                customFilters: nil
            )
        )
        
        print("📝 [DataService] Test announcement details:")
        print("  - ID: \(testAnnouncement.id)")
        print("  - Title: \(testAnnouncement.title)")
        print("  - Target Audience: \(testAnnouncement.targeting.audience)")
        print("  - Access Level: \(testAnnouncement.accessLevel)")
        print("  - Subscription Required: \(testAnnouncement.subscriptionRequired?.displayName ?? "none")")
        
        // Save to Firestore announcements collection
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            firestoreService.saveAnnouncement(testAnnouncement) { error in
                if let error = error {
                    print("❌ [DataService] Error saving test announcement to Firestore: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    print("✅ [DataService] Test announcement saved to Firestore successfully")
                    continuation.resume()
                }
            }
        }
    }
    
    func setupCloudKitSchema() async {
        await cloudKitService.setupCloudKitSchema()
    }
    
    // MARK: - Media Upload Operations
    func uploadUserMedia(image: UIImage, userId: String) async throws -> String {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            mediaStorageService.uploadUserMedia(image: image, userId: userId) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func uploadFreeContentMedia(image: UIImage, contentId: String) async throws -> String {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            mediaStorageService.uploadFreeContentMedia(image: image, contentId: contentId) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func uploadSubscriptionContentMedia(image: UIImage, contentId: String) async throws -> String {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            mediaStorageService.uploadSubscriptionContentMedia(image: image, contentId: contentId) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Media Download Operations
    func downloadMedia(from url: String, storageLocation: MediaStorageLocation) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
            mediaStorageService.downloadMedia(from: url, storageLocation: storageLocation) { result in
                switch result {
                case .success(let image):
                    continuation.resume(returning: image)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Media Delete Operations
    func deleteUserMedia(url: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            mediaStorageService.deleteUserMedia(url: url) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func deleteFreeContentMedia(url: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            mediaStorageService.deleteFreeContentMedia(url: url) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func deleteSubscriptionContentMedia(url: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            mediaStorageService.deleteSubscriptionContentMedia(url: url) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Subscription Operations (Firestore)
    func saveUserSubscription(_ subscription: UserSubscription) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            firestoreService.saveUserSubscription(subscription) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    DispatchQueue.main.async {
                        self.userSubscription = subscription
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    func saveStudioMembership(_ membership: StudioMembership) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            firestoreService.saveStudioMembership(membership) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    DispatchQueue.main.async {
                        self.studioMembership = membership
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Access Control
    func canAccessContent(_ content: Program) -> Bool {
        print("🔍 [DataService] canAccessContent called for program: \(content.name)")
        print("🔍 [DataService] Program access level: \(content.accessLevel)")
        print("🔍 [DataService] User subscription active: \(userSubscription?.isActive ?? false)")
        print("🔍 [DataService] Studio membership active: \(studioMembership?.isActive ?? false)")
        
        let canAccess: Bool
        switch content.accessLevel {
        case .userPrivate:
            canAccess = false
        case .freePublic:
            canAccess = true
        case .subscriptionRequired:
            canAccess = userSubscription?.isActive == true
        case .studioMemberDiscount:
            canAccess = userSubscription?.isActive == true && studioMembership?.isActive == true
        }
        
        print("🔍 [DataService] Access result for '\(content.name)': \(canAccess)")
        return canAccess
    }
    
    func canAccessContent(_ content: MediaContent) -> Bool {
        switch content.accessLevel {
        case DataAccessLevel.userPrivate:
            return false
        case DataAccessLevel.freePublic:
            return true
        case DataAccessLevel.subscriptionRequired:
            return userSubscription?.isActive == true
        case DataAccessLevel.studioMemberDiscount:
            return userSubscription?.isActive == true && studioMembership?.isActive == true
        default:
            return false
        }
    }
    
    // MARK: - User Profile Operations (CloudKit)
    func saveUserProfile(_ profile: UserProfile) async throws {
        try await cloudKitService.saveUserProfile(profile)
        await MainActor.run {
            self.currentUser = profile
        }
    }
    
    // MARK: - Utility Methods
    func refreshUserData() {
        loadUserData()
    }
    
    func syncFirestoreData() async {
        guard let profile = currentUser else {
            print("❌ [DataService] No current user profile to sync")
            return
        }
        
        guard let userId = cloudKitService.currentUserID else {
            print("❌ [DataService] No current user ID")
            return
        }
        
        await syncFirestoreDataWithProfile(userId: userId, profile: profile)
    }
    
    func signOut() {
        currentUser = nil
        userSubscription = nil
        studioMembership = nil
    }
    
    // MARK: - Migration Methods
    func associateFirebaseUserWithExistingMember(firebaseUid: String, existingUid: String) async {
        print("🔗 [DataService] Associating Firebase user with existing member")
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            firestoreService.associateFirebaseUserWithExistingMember(firebaseUid: firebaseUid, existingUid: existingUid) { error in
                if let error = error {
                    print("❌ [DataService] Error associating Firebase user: \(error)")
                } else {
                    print("✅ [DataService] Successfully associated Firebase user with existing member")
                }
                continuation.resume()
            }
        }
    }
    
    // MARK: - Journal Content Reference Operations
    func createContentReference(from content: Any, type: ContentType) -> ContentReference? {
        switch type {
        case .program:
            if let program = content as? Program {
                return ContentReference(
                    id: program.id,
                    type: .program,
                    cachedName: program.name,
                    cachedRank: nil, // Programs don't have a single required rank
                    cachedDescription: program.description,
                    isSubscriptionRequired: program.accessLevel == .subscriptionRequired,
                    referencedAt: Date()
                )
            }
        case .technique:
            if let technique = content as? Technique {
                return ContentReference(
                    id: technique.id,
                    type: .technique,
                    cachedName: technique.name,
                    cachedRank: technique.requiredRankId,
                    cachedDescription: technique.description,
                    isSubscriptionRequired: false,
                    referencedAt: Date()
                )
            }
        case .form:
            if let form = content as? Form {
                return ContentReference(
                    id: form.id,
                    type: .form,
                    cachedName: form.name,
                    cachedRank: nil,
                    cachedDescription: form.description,
                    isSubscriptionRequired: false,
                    referencedAt: Date()
                )
            }
        case .announcement:
            if let announcement = content as? MediaContent {
                return ContentReference(
                    id: announcement.id,
                    type: .announcement,
                    cachedName: announcement.title,
                    cachedRank: nil,
                    cachedDescription: announcement.description,
                    isSubscriptionRequired: announcement.accessLevel == .subscriptionRequired,
                    referencedAt: Date()
                )
            }
        }
        
        return nil
    }
    
    func canAccessReferencedContent(_ reference: ContentReference) -> Bool {
        if !reference.isSubscriptionRequired {
            return true
        }
        
        // Check subscription status
        return userSubscription?.isActive == true
    }
    
    func getContentWithFallback(id: String, type: ContentType) -> ContentDisplay {
        // Try to get full content
        if let content = getFullContent(id: id, type: type) {
            return ContentDisplay(content: content, isAccessible: true)
        } else {
            // Return fallback
            return ContentDisplay(fallback: ContentFallback(
                id: id,
                type: type,
                name: "Content Not Available",
                description: nil,
                message: "Content requires active subscription"
            ))
        }
    }
    
    private func getFullContent(id: String, type: ContentType) -> Any? {
        // This would need to be implemented based on your content storage
        // For now, return nil to trigger fallback
        return nil
    }
    
    // MARK: - Analytics Tracking (CloudKit)
    func trackContentReference(contentId: String, type: ContentType) async {
        print("📊 [DataService] Tracking content reference: \(type.displayName) (\(contentId))")
        
        // Track analytics in CloudKit (user's private database)
        do {
            try await cloudKitService.trackContentReference(contentId: contentId, type: type)
            print("✅ [DataService] Analytics tracked in CloudKit for \(type.displayName) (\(contentId))")
        } catch {
            print("❌ [DataService] Error tracking analytics in CloudKit: \(error)")
            // Don't fail the journal entry creation if analytics tracking fails
        }
    }
    
    func trackContentView(contentId: String, type: ContentType) async {
        print("👁️ [DataService] Tracking content view: \(type.displayName) (\(contentId))")
        
        // Track view count in CloudKit (user's private database)
        do {
            try await cloudKitService.trackContentView(contentId: contentId, type: type)
            print("✅ [DataService] View count tracked in CloudKit for \(type.displayName) (\(contentId))")
        } catch {
            print("❌ [DataService] Error tracking view count in CloudKit: \(error)")
            // Don't fail the content viewing if analytics tracking fails
        }
    }
    
    // MARK: - Helper Methods
    private func getCurrentUserId() async -> String? {
        // For Firestore operations, prioritize Firebase user ID since that's where the data is stored
        guard let firebaseUser = Auth.auth().currentUser else {
            print("❌ [DataService] No Firebase user available")
            return nil
        }
        
        let firebaseUserId = firebaseUser.uid
        print("✅ [DataService] Using Firebase user ID for Firestore operations: \(firebaseUserId)")
        return firebaseUserId
    }
    
    // MARK: - Tag Management (CloudKit)
    func fetchUserTags(userId: String) async throws -> [Tag] {
        return try await cloudKitService.fetchUserTags(userId: userId)
    }
    
    func saveUserTag(_ tag: Tag) async throws {
        try await cloudKitService.saveUserTag(tag)
    }
    
    func updateTagUsage(_ tagId: String, userId: String) async throws {
        try await cloudKitService.updateTagUsage(tagId, userId: userId)
    }
    
    func deleteUserTag(_ tagId: String, userId: String) async throws {
        try await cloudKitService.deleteUserTag(tagId, userId: userId)
    }
    
    // MARK: - Member Status Updates
    func checkForMemberStatusUpdate() async {
        print("🔄 [DataService] Checking for member status updates...")
        
        guard let currentProfile = currentUser else {
            print("❌ [DataService] No current user profile to check")
            return
        }
        
        // Only check if user is currently a public user
        guard currentProfile.roles.contains("public") else {
            print("ℹ️ [DataService] User is not a public user, skipping member status check")
            return
        }
        
        // Check if this email now exists in Firestore as a member
        let updatedProfile: UserProfile? = await withCheckedContinuation { (continuation: CheckedContinuation<UserProfile?, Never>) in
            firestoreService.checkExistingMember(email: currentProfile.email) { result in
                switch result {
                case .success(let existingProfile):
                    if let profile = existingProfile {
                        print("✅ [DataService] Found existing member for public user: \(profile.name)")
                        print("✅ [DataService] Member roles: \(profile.roles)")
                        
                        // Create updated profile with member data
                        let updatedProfile = UserProfile(
                            uid: currentProfile.uid,
                            firebaseUid: currentProfile.firebaseUid,
                            name: profile.name, // Use member name
                            email: profile.email, // Use member email
                            roles: profile.roles, // Use member roles
                            profilePhotoUrl: profile.profilePhotoUrl, // Use member photo
                            programs: profile.programs, // Use member programs
                            subscription: profile.subscription, // Use member subscription
                            studioMembership: profile.studioMembership, // Use member studio membership
                            dataStore: .iCloud,
                            accessLevel: .userPrivate
                        )
                        continuation.resume(returning: updatedProfile)
                    } else {
                        print("ℹ️ [DataService] No member found for public user email")
                        continuation.resume(returning: nil)
                    }
                case .failure(let error):
                    print("❌ [DataService] Error checking member status: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
        
        if let updatedProfile = updatedProfile {
            print("🔄 [DataService] Updating public user to member status")
            
            // Save updated profile to iCloud
            do {
                try await saveUserProfile(updatedProfile)
                print("✅ [DataService] Successfully updated profile to member status: \(updatedProfile.name)")
                
                await MainActor.run {
                    self.currentUser = updatedProfile
                    print("✅ [DataService] Updated currentUser to member status: \(self.currentUser?.name ?? "None")")
                }
            } catch {
                print("❌ [DataService] Error updating profile to member status: \(error)")
                
                // Fallback: update without saving to iCloud
                await MainActor.run {
                    self.currentUser = updatedProfile
                    print("✅ [DataService] Updated currentUser to member status (iCloud save failed): \(self.currentUser?.name ?? "None")")
                }
            }
        }
    }
    
    // MARK: - Periodic Member Status Check
    func startMemberStatusMonitoring() {
        print("🔄 [DataService] Starting member status monitoring...")
        
        // Check for member status updates every 5 minutes when app is active
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task {
                await self.checkForMemberStatusUpdate()
            }
        }
    }
    
    // MARK: - Public Methods for User Interface
    func manuallyCheckMemberStatus() async {
        print("🔄 [DataService] Manual member status check requested by user")
        await checkForMemberStatusUpdate()
    }
    
    func getMemberStatusMessage() -> String? {
        guard let currentProfile = currentUser else { return nil }
        
        if currentProfile.roles.contains("public") {
            return "You are currently a public user. If you've recently joined the studio, your membership status will be updated automatically."
        } else if currentProfile.roles.contains("student") {
            return "You are a studio member with access to curriculum and programs."
        } else {
            return "You have special access to the app."
        }
    }
    
    // MARK: - Media URL Cleanup
    
    func cleanupInvalidMediaUrls() async {
        print("🧹 [DataService] Starting media URL cleanup...")
        
        do {
            let entries = try await fetchJournalEntries(for: currentUserId)
            var hasChanges = false
            
            for entry in entries {
                let validUrls = await validateMediaUrls(entry.mediaUrls)
                if validUrls.count != entry.mediaUrls.count {
                    // Create updated entry with only valid URLs
                    let updatedEntry = JournalEntry(
                        id: entry.id,
                        uid: entry.uid,
                        timestamp: entry.timestamp,
                        title: entry.title,
                        content: entry.content,
                        referencedContent: entry.referencedContent,
                        personalNotes: entry.personalNotes,
                        practiceNotes: entry.practiceNotes,
                        difficultyRating: entry.difficultyRating,
                        needsPractice: entry.needsPractice,
                        mediaUrls: validUrls,
                        tags: entry.tags,
                        linkedPrograms: entry.linkedPrograms,
                        linkedTechniques: entry.linkedTechniques
                    )
                    
                    // Save the updated entry
                    try await saveJournalEntry(updatedEntry)
                    hasChanges = true
                    print("🧹 [DataService] Cleaned up entry \(entry.id): removed \(entry.mediaUrls.count - validUrls.count) invalid URLs")
                }
            }
            
            if hasChanges {
                print("✅ [DataService] Media URL cleanup completed")
            } else {
                print("✅ [DataService] No invalid media URLs found")
            }
        } catch {
            print("❌ [DataService] Failed to cleanup media URLs: \(error)")
        }
    }
    
    private func validateMediaUrls(_ urls: [String]) async -> [String] {
        var validUrls: [String] = []
        
        for url in urls {
            if await isMediaUrlValid(url) {
                validUrls.append(url)
            } else {
                print("🗑️ [DataService] Invalid media URL found: \(url)")
            }
        }
        
        return validUrls
    }
    
    private func isMediaUrlValid(_ url: String) async -> Bool {
        // Check if URL has valid format
        guard !url.isEmpty else { return false }
        
        // Filter out placeholder URLs
        if url.hasPrefix("placeholder_url_") {
            print("🗑️ [DataService] Removing placeholder URL: \(url)")
            return false
        }
        
        let validPrefixes = ["icloud://user_private/", "icloud://app_public/"]
        guard validPrefixes.contains(where: { url.hasPrefix($0) }) else { return false }
        
        // Extract record name and try to fetch it
        let components = url.components(separatedBy: "/")
        guard let recordName = components.last, !recordName.isEmpty else { return false }
        
        // Try to fetch the record to see if it exists
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let recordID = CKRecord.ID(recordName: recordName)
            
            // Determine which database to use
            let database: CKDatabase
            if url.contains("icloud://user_private") {
                database = cloudKitService.privateDatabase
            } else {
                database = cloudKitService.publicDatabase
            }
            
            database.fetch(withRecordID: recordID) { record, error in
                if let error = error as? CKError, error.code == .unknownItem {
                    continuation.resume(returning: false)
                } else if record != nil {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    func addPracticeSession(_ session: PracticeSession) {
        guard var user = currentUser else { return }
        user.practiceSessions.append(session)
        currentUser = user
        Task {
            do {
                try await CloudKitService.shared.saveUserProfile(user)
            } catch {
                print("❌ [DataService] Failed to save user profile with new session: \(error)")
            }
        }
    }

    func getPracticeSessions() -> [PracticeSession] {
        return currentUser?.practiceSessions ?? []
    }
} 
