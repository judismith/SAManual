import Foundation
import Combine

class DataMigrationService: ObservableObject {
    static let shared = DataMigrationService()
    
    private let firestoreService = FirestoreService.shared
    private let cloudKitService = CloudKitService.shared
    private let dataService = DataService.shared
    
    @Published var migrationProgress: Double = 0.0
    @Published var migrationStatus: MigrationStatus = .idle
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    enum MigrationStatus {
        case idle
        case inProgress
        case completed
        case failed
    }
    
    // MARK: - Migration Methods
    
    func migrateUserData(userId: String) async {
        await MainActor.run {
            migrationStatus = .inProgress
            migrationProgress = 0.0
            errorMessage = nil
        }
        
        do {
            // Step 1: Migrate user profile (50%)
            try await migrateUserProfile(userId: userId)
            await updateProgress(0.5)
            
            // Step 2: Verify migration (100%)
            try await verifyMigration(userId: userId)
            await updateProgress(1.0)
            
            await MainActor.run {
                migrationStatus = .completed
            }
            
        } catch {
            await MainActor.run {
                migrationStatus = .failed
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Individual Migration Methods
    
    private func migrateUserProfile(userId: String) async throws {
        // Fetch user profile from Firestore
        let profile: UserProfile? = try await withCheckedThrowingContinuation { continuation in
            self.firestoreService.fetchProfileByUid(uid: userId) { profile, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: profile)
                }
            }
        }
        
        guard let profile = profile else {
            throw MigrationError.userProfileNotFound
        }
        
        // Save to CloudKit
        try await self.cloudKitService.saveUserProfile(profile)
    }
    
    private func verifyMigration(userId: String) async throws {
        // Verify that data was migrated correctly
        let cloudKitProfile = try await self.cloudKitService.fetchUserProfile(uid: userId)
        guard cloudKitProfile != nil else {
            throw MigrationError.verificationFailed
        }
        
        // Log migration results
        print("✅ [DataMigrationService] Migration completed successfully")
        print("📊 [DataMigrationService] User profile migrated to CloudKit")
    }
    
    // MARK: - Helper Methods
    
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            self.migrationProgress = progress
        }
    }
    
    func resetMigration() {
        migrationStatus = .idle
        migrationProgress = 0.0
        errorMessage = nil
    }
    
    // MARK: - Migration Status Check
    
    func checkMigrationStatus(userId: String) async -> Bool {
        do {
            let profile = try await self.cloudKitService.fetchUserProfile(uid: userId)
            return profile != nil
        } catch {
            return false
        }
    }
    
    // MARK: - Cleanup Methods (Optional)
    
    func cleanupFirestoreUserData(userId: String) async throws {
        // WARNING: This will permanently delete user data from Firestore
        // Only use after successful migration and verification
        
        // Note: We don't delete the user profile from Firestore as it's needed for subscription data
        // Journal entries and custom content are now stored in CloudKit, not Firestore
        
        print("⚠️ [DataMigrationService] Firestore cleanup not needed")
        print("⚠️ [DataMigrationService] User profile remains in Firestore for subscription data")
        print("⚠️ [DataMigrationService] Journal entries and custom content are now in CloudKit")
    }
}

// MARK: - Migration Errors

enum MigrationError: Error, LocalizedError {
    case userProfileNotFound
    case verificationFailed
    case cloudKitError
    case firestoreError
    
    var errorDescription: String? {
        switch self {
        case .userProfileNotFound:
            return "User profile not found in Firestore"
        case .verificationFailed:
            return "Migration verification failed"
        case .cloudKitError:
            return "CloudKit operation failed"
        case .firestoreError:
            return "Firestore operation failed"
        }
    }
} 