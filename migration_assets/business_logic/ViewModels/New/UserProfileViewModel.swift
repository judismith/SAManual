import Foundation
import Combine
import FirebaseAuth

@MainActor
class UserProfileViewModel: BaseViewModel<UserProfileState> {
    
    // MARK: - Dependencies
    private let userService: UserService
    private let authService: AuthService
    
    // MARK: - Initialization
    init(
        userService: UserService,
        authService: AuthService,
        errorHandler: ErrorHandler
    ) {
        self.userService = userService
        self.authService = authService
        
        super.init(
            initialState: UserProfileState(),
            errorHandler: errorHandler
        )
        
        setupObservers()
    }
    
    // MARK: - Private Methods
    private func setupObservers() {
        // Monitor user service for profile updates
        userService.currentUserPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                self?.state.profile = profile
                self?.state.isLoading = false
                self?.state.errorMessage = nil
            }
            .store(in: &cancellables)
        
        // Monitor auth state changes
        authService.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authState in
                switch authState {
                case .authenticated(let authUser):
                    // Load profile when user authenticates
                    Task {
                        await self?.loadProfileForUser(userId: authUser.id)
                    }
                case .unauthenticated:
                    // Clear profile when user signs out
                    self?.state.profile = nil
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func fetchProfile(uid: String) {
        print("[UserProfileViewModel] fetchProfile called for UID: \(uid)")
        state.isLoading = true
        state.errorMessage = nil
        
        print("🔍 [UserProfileViewModel] Starting profile fetch for UID: \(uid)")
        
        Task {
            await loadProfileForUser(userId: uid)
        }
    }
    
    func updateProfile(_ profile: UserProfile) {
        state.isLoading = true
        state.errorMessage = nil
        
        Task {
            do {
                let updatedProfile = try await userService.updateUserProfile(profile)
                state.profile = updatedProfile
                state.isLoading = false
                state.errorMessage = nil
            } catch {
                await handleError(error)
                state.isLoading = false
            }
        }
    }
    
    func refreshProfile() {
        guard let currentProfile = state.profile else {
            state.errorMessage = "No profile to refresh"
            return
        }
        
        fetchProfile(uid: currentProfile.id)
    }
    
    func createProfile(_ profile: UserProfile) {
        state.isLoading = true
        state.errorMessage = nil
        
        Task {
            do {
                let createdProfile = try await userService.createUser(profile)
                state.profile = createdProfile
                state.isLoading = false
                state.errorMessage = nil
            } catch {
                await handleError(error)
                state.isLoading = false
            }
        }
    }
    
    func deleteProfile() {
        guard let currentProfile = state.profile else {
            state.errorMessage = "No profile to delete"
            return
        }
        
        state.isLoading = true
        state.errorMessage = nil
        
        Task {
            do {
                try await userService.deleteUser(id: currentProfile.id)
                state.profile = nil
                state.isLoading = false
                state.errorMessage = nil
            } catch {
                await handleError(error)
                state.isLoading = false
            }
        }
    }
    
    func getCurrentUser() -> UserProfile? {
        return state.profile
    }
    
    func setProfile(_ profile: UserProfile) {
        state.profile = profile
        state.errorMessage = nil
    }
    
    // MARK: - Private Helper Methods
    private func loadProfileForUser(userId: String) async {
        do {
            let profile = try await userService.getUser(userId: userId)
            state.profile = profile
            state.isLoading = false
            state.errorMessage = nil
        } catch {
            await handleError(error)
            state.isLoading = false
        }
    }
}

// MARK: - User Profile State
struct UserProfileState {
    var profile: UserProfile?
    var errorMessage: String?
    var isLoading: Bool = false
}