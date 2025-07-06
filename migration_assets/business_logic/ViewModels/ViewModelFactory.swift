import Foundation
import SwiftUI

// MARK: - ViewModel Factory
@MainActor
class ViewModelFactory {
    
    // MARK: - Dependencies
    private let container: DIContainer
    
    // MARK: - Initialization
    init(container: DIContainer) {
        self.container = container
    }
    
    // MARK: - ViewModel Creation Methods
    
    /// Create PracticeTrackingViewModel with injected dependencies
    func makePracticeTrackingViewModel() async throws -> PracticeTrackingViewModel {
        let programService = try container.resolve(ProgramService.self)
        let userService = try container.resolve(UserService.self)
        let mediaService = try container.resolve(MediaService.self)
        let errorHandler = try container.resolve(ErrorHandler.self)
        
        return PracticeTrackingViewModel(
            programService: programService,
            userService: userService,
            mediaService: mediaService,
            errorHandler: errorHandler
        )
    }
    
    /// Create CurriculumViewModel with injected dependencies
    func makeCurriculumViewModel() async throws -> CurriculumViewModel {
        let programService = try container.resolve(ProgramService.self)
        let userService = try container.resolve(UserService.self)
        let authService = try container.resolve(AuthService.self)
        let errorHandler = try container.resolve(ErrorHandler.self)
        
        return CurriculumViewModel(
            programService: programService,
            userService: userService,
            authService: authService,
            errorHandler: errorHandler
        )
    }
    
    /// Create AnnouncementsViewModel with injected dependencies
    func makeAnnouncementsViewModel() async throws -> AnnouncementsViewModel {
        let mediaService = try container.resolve(MediaService.self)
        let userService = try container.resolve(UserService.self)
        let authService = try container.resolve(AuthService.self)
        let errorHandler = try container.resolve(ErrorHandler.self)
        
        return AnnouncementsViewModel(
            mediaService: mediaService,
            userService: userService,
            authService: authService,
            errorHandler: errorHandler
        )
    }
    
    /// Create PracticeSessionViewModel with injected dependencies
    func makePracticeSessionViewModel() async throws -> PracticeSessionViewModel {
        let programService = try container.resolve(ProgramService.self)
        let userService = try container.resolve(UserService.self)
        let mediaService = try container.resolve(MediaService.self)
        let errorHandler = try container.resolve(ErrorHandler.self)
        
        return PracticeSessionViewModel(
            programService: programService,
            userService: userService,
            mediaService: mediaService,
            errorHandler: errorHandler
        )
    }
    
    /// Create AuthViewModel with injected dependencies
    func makeAuthViewModel() async throws -> AuthViewModel {
        let authService = try container.resolve(AuthService.self)
        let userService = try container.resolve(UserService.self)
        let subscriptionService = try container.resolve(SubscriptionService.self)
        let programService = try container.resolve(ProgramService.self)
        let errorHandler = try container.resolve(ErrorHandler.self)
        
        return AuthViewModel(
            authService: authService,
            userService: userService,
            subscriptionService: subscriptionService,
            programService: programService,
            errorHandler: errorHandler
        )
    }
    
    /// Create UserProfileViewModel with injected dependencies
    func makeUserProfileViewModel() async throws -> UserProfileViewModel {
        let userService = try container.resolve(UserService.self)
        let authService = try container.resolve(AuthService.self)
        let errorHandler = try container.resolve(ErrorHandler.self)
        
        return UserProfileViewModel(
            userService: userService,
            authService: authService,
            errorHandler: errorHandler
        )
    }
    
    /// Create JournalViewModel with injected dependencies
    func makeJournalViewModel() async throws -> JournalViewModel {
        let journalService = try container.resolve(JournalService.self)
        let userService = try container.resolve(UserService.self)
        let programService = try container.resolve(ProgramService.self)
        let errorHandler = try container.resolve(ErrorHandler.self)
        
        return JournalViewModel(
            journalService: journalService,
            userService: userService,
            programService: programService,
            errorHandler: errorHandler
        )
    }
    
    /// Create SubscriptionViewModel with injected dependencies
    func makeSubscriptionViewModel() async throws -> SubscriptionViewModel {
        let subscriptionService = try container.resolve(SubscriptionService.self)
        let userService = try container.resolve(UserService.self)
        let errorHandler = try container.resolve(ErrorHandler.self)
        
        return SubscriptionViewModel(
            subscriptionService: subscriptionService,
            userService: userService,
            errorHandler: errorHandler
        )
    }
    
    // MARK: - Service Creation Methods
    
    /// Create AuthService with injected dependencies
    func makeAuthService() -> AuthService {
        do {
            return try container.resolve(AuthService.self)
        } catch {
            fatalError("Failed to resolve AuthService: \(error)")
        }
    }
    
    /// Create UserService with injected dependencies
    func makeUserService() -> UserService {
        do {
            return try container.resolve(UserService.self)
        } catch {
            fatalError("Failed to resolve UserService: \(error)")
        }
    }
    
    /// Create ProgramService with injected dependencies
    func makeProgramService() -> ProgramService {
        do {
            return try container.resolve(ProgramService.self)
        } catch {
            fatalError("Failed to resolve ProgramService: \(error)")
        }
    }
    
    /// Create MediaService with injected dependencies
    func makeMediaService() -> MediaService {
        do {
            return try container.resolve(MediaService.self)
        } catch {
            fatalError("Failed to resolve MediaService: \(error)")
        }
    }
    
    /// Create SubscriptionService with injected dependencies
    func makeSubscriptionService() -> SubscriptionService {
        do {
            return try container.resolve(SubscriptionService.self)
        } catch {
            fatalError("Failed to resolve SubscriptionService: \(error)")
        }
    }
    
    /// Create JournalService with injected dependencies
    func makeJournalService() -> JournalService {
        do {
            return try container.resolve(JournalService.self)
        } catch {
            fatalError("Failed to resolve JournalService: \(error)")
        }
    }
    
    /// Create ErrorHandler with injected dependencies
    func makeErrorHandler() -> ErrorHandler {
        do {
            return try container.resolve(ErrorHandler.self)
        } catch {
            fatalError("Failed to resolve ErrorHandler: \(error)")
        }
    }
}

// MARK: - Environment Key for ViewModelFactory
struct ViewModelFactoryKey: EnvironmentKey {
    static let defaultValue: ViewModelFactory = {
        // This should never be used in production - DI container should be provided
        fatalError("ViewModelFactory must be provided via environment")
    }()
}

// MARK: - Environment Values Extension
extension EnvironmentValues {
    var viewModelFactory: ViewModelFactory {
        get { self[ViewModelFactoryKey.self] }
        set { self[ViewModelFactoryKey.self] = newValue }
    }
}

// MARK: - View Extension for Easy ViewModel Creation
extension View {
    func viewModelFactory(_ factory: ViewModelFactory) -> some View {
        environment(\.viewModelFactory, factory)
    }
}