# Clean Architecture Implementation Guide

## Overview

This document provides detailed implementation guidance for the Shaolin Arts Academy iOS app using Clean Architecture principles. It includes specific code examples, patterns, and best practices to ensure a maintainable, testable, and scalable codebase.

## Architecture Layers

### 1. Domain Layer (Core Business Logic)

The domain layer contains the core business logic and is independent of any external dependencies.

#### Domain Entities

```swift
// MARK: - Core Domain Entities

struct User: Identifiable, Equatable {
    let id: String
    let email: String
    let name: String
    let userType: UserType
    let membershipType: MembershipType?
    let enrolledPrograms: [ProgramEnrollment]
    let accessLevel: DataAccessLevel
    let dataStore: DataStore
    let createdAt: Date
    let updatedAt: Date
    
    // Business logic methods
    func hasEnrolledPrograms() -> Bool {
        return !enrolledPrograms.filter { $0.enrolled }.isEmpty
    }
    
    func canAccessProgram(_ program: Program) -> Bool {
        // Business rule: User can access if enrolled or has general access
        return enrolledPrograms.contains { $0.programId == program.id && $0.enrolled } ||
               accessLevel.canAccessPrograms()
    }
}

struct Program: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let type: ProgramType
    let isActive: Bool
    let instructorIds: [String]
    let ranks: [Rank]
    let curriculum: [CurriculumItem]
    let createdAt: Date
    let updatedAt: Date
    
    // Business logic methods
    func getRankByName(_ name: String) -> Rank? {
        return ranks.first { $0.name == name }
    }
    
    func getNextRank(after currentRank: String) -> Rank? {
        guard let current = getRankByName(currentRank) else { return nil }
        return ranks.first { $0.order > current.order }
    }
}

struct PracticeSession: Identifiable, Equatable {
    let id: String
    let userId: String
    let name: String
    let items: [PracticeItem]
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
    let notes: String?
    
    // Business logic methods
    var isActive: Bool {
        return endTime == nil
    }
    
    var totalEstimatedDuration: TimeInterval {
        return items.reduce(0) { $0 + $1.estimatedDuration }
    }
    
    func addItem(_ item: PracticeItem) -> PracticeSession {
        var newItems = items
        newItems.append(item)
        return PracticeSession(
            id: id,
            userId: userId,
            name: name,
            items: newItems,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            notes: notes
        )
    }
}
```

#### Value Objects

```swift
// MARK: - Value Objects

enum UserType: String, Codable, CaseIterable {
    case freeUser = "free_user"
    case student = "student"
    case parent = "parent"
    case instructor = "instructor"
    case admin = "admin"
    case paidUser = "paid_user"
    
    var displayName: String {
        return rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
    
    var canAccessCurriculum: Bool {
        switch self {
        case .student, .instructor, .admin, .paidUser:
            return true
        case .freeUser, .parent:
            return false
        }
    }
}

enum DataAccessLevel: String, Codable, CaseIterable {
    case freePublic = "free_public"
    case freePrivate = "free_private"
    case userPublic = "user_public"
    case userPrivate = "user_private"
    case instructorPublic = "instructor_public"
    case instructorPrivate = "instructor_private"
    case adminPublic = "admin_public"
    case adminPrivate = "admin_private"
    
    func canAccessPrograms() -> Bool {
        switch self {
        case .userPublic, .userPrivate, .instructorPublic, .instructorPrivate, .adminPublic, .adminPrivate:
            return true
        case .freePublic, .freePrivate:
            return false
        }
    }
}
```

#### Use Cases

```swift
// MARK: - Use Cases

protocol UseCase {
    associatedtype Request
    associatedtype Response
    
    func execute(_ request: Request) async throws -> Response
}

// Authentication Use Cases
struct SignInUseCase: UseCase {
    struct Request {
        let email: String
        let password: String
    }
    
    struct Response {
        let user: User
        let isNewUser: Bool
    }
    
    private let authRepository: AuthRepository
    private let userRepository: UserRepository
    
    init(authRepository: AuthRepository, userRepository: UserRepository) {
        self.authRepository = authRepository
        self.userRepository = userRepository
    }
    
    func execute(_ request: Request) async throws -> Response {
        // 1. Authenticate user
        let authResult = try await authRepository.signIn(email: request.email, password: request.password)
        
        // 2. Check if user exists in our system
        let existingUser = try await userRepository.getUserByEmail(request.email)
        
        if let user = existingUser {
            // 3. Update user with latest auth info
            let updatedUser = try await userRepository.updateUser(user.withUpdatedAuth(authResult))
            return Response(user: updatedUser, isNewUser: false)
        } else {
            // 4. Create new user profile
            let newUser = User.createFromAuth(authResult)
            let createdUser = try await userRepository.createUser(newUser)
            return Response(user: createdUser, isNewUser: true)
        }
    }
}

// Practice Session Use Cases
struct CreatePracticeSessionUseCase: UseCase {
    struct Request {
        let userId: String
        let name: String
        let items: [PracticeItem]
        let scheduledDate: Date?
    }
    
    struct Response {
        let session: PracticeSession
    }
    
    private let practiceRepository: PracticeRepository
    private let userRepository: UserRepository
    
    init(practiceRepository: PracticeRepository, userRepository: UserRepository) {
        self.practiceRepository = practiceRepository
        self.userRepository = userRepository
    }
    
    func execute(_ request: Request) async throws -> Response {
        // 1. Validate user exists
        guard let user = try await userRepository.getUser(id: request.userId) else {
            throw DomainError.userNotFound(id: request.userId)
        }
        
        // 2. Validate practice items
        try validatePracticeItems(request.items, for: user)
        
        // 3. Create practice session
        let session = PracticeSession(
            id: UUID().uuidString,
            userId: request.userId,
            name: request.name,
            items: request.items,
            startTime: request.scheduledDate ?? Date(),
            endTime: nil,
            duration: 0,
            notes: nil
        )
        
        // 4. Save session
        let savedSession = try await practiceRepository.createSession(session)
        
        return Response(session: savedSession)
    }
    
    private func validatePracticeItems(_ items: [PracticeItem], for user: User) throws {
        // Business rule: User can only practice items they have access to
        for item in items {
            // Validation logic here
        }
    }
}

struct GeneratePracticeRecommendationsUseCase: UseCase {
    struct Request {
        let userId: String
        let focusArea: PracticeFocusArea?
        let duration: TimeInterval?
    }
    
    struct Response {
        let recommendations: [PracticeSession]
    }
    
    private let practiceRepository: PracticeRepository
    private let userRepository: UserRepository
    private let recommendationEngine: RecommendationEngine
    
    init(practiceRepository: PracticeRepository, 
         userRepository: UserRepository, 
         recommendationEngine: RecommendationEngine) {
        self.practiceRepository = practiceRepository
        self.userRepository = userRepository
        self.recommendationEngine = recommendationEngine
    }
    
    func execute(_ request: Request) async throws -> Response {
        // 1. Get user and their progress
        guard let user = try await userRepository.getUser(id: request.userId) else {
            throw DomainError.userNotFound(id: request.userId)
        }
        
        let recentSessions = try await practiceRepository.getUserSessions(userId: request.userId, limit: 10)
        
        // 2. Generate recommendations using AI engine
        let recommendations = try await recommendationEngine.generateRecommendations(
            for: user,
            recentSessions: recentSessions,
            focusArea: request.focusArea,
            targetDuration: request.duration
        )
        
        return Response(recommendations: recommendations)
    }
}
```

#### Domain Services

```swift
// MARK: - Domain Services

protocol RecommendationEngine {
    func generateRecommendations(
        for user: User,
        recentSessions: [PracticeSession],
        focusArea: PracticeFocusArea?,
        targetDuration: TimeInterval?
    ) async throws -> [PracticeSession]
}

protocol LearningAnalytics {
    func analyzeProgress(for user: User) async throws -> LearningInsights
    func calculateMasteryLevel(for technique: String, userId: String) async throws -> MasteryLevel
    func generateInsights(from sessions: [PracticeSession]) async throws -> [LearningInsight]
}

// Domain Errors
enum DomainError: Error, LocalizedError {
    case userNotFound(id: String)
    case programNotFound(id: String)
    case unauthorizedAccess
    case invalidPracticeSession
    case sessionAlreadyActive
    
    var errorDescription: String? {
        switch self {
        case .userNotFound(let id):
            return "User with ID \(id) not found"
        case .programNotFound(let id):
            return "Program with ID \(id) not found"
        case .unauthorizedAccess:
            return "Unauthorized access to this resource"
        case .invalidPracticeSession:
            return "Invalid practice session configuration"
        case .sessionAlreadyActive:
            return "A practice session is already active"
        }
    }
}
```

### 2. Data Layer (Infrastructure)

The data layer implements the repository interfaces and handles data persistence.

#### Repository Interfaces

```swift
// MARK: - Repository Interfaces

protocol UserRepository {
    func createUser(_ user: User) async throws -> User
    func getUser(id: String) async throws -> User?
    func getUserByEmail(_ email: String) async throws -> User?
    func updateUser(_ user: User) async throws -> User
    func deleteUser(id: String) async throws
    func getUsersByType(_ type: UserType) async throws -> [User]
}

protocol PracticeRepository {
    func createSession(_ session: PracticeSession) async throws -> PracticeSession
    func getSession(id: String) async throws -> PracticeSession?
    func updateSession(_ session: PracticeSession) async throws -> PracticeSession
    func deleteSession(id: String) async throws
    func getUserSessions(userId: String, limit: Int?) async throws -> [PracticeSession]
    func getActiveSession(userId: String) async throws -> PracticeSession?
}

protocol ProgramRepository {
    func getProgram(id: String) async throws -> Program?
    func getAllPrograms() async throws -> [Program]
    func getProgramsByType(_ type: ProgramType) async throws -> [Program]
    func searchPrograms(query: String, limit: Int) async throws -> [Program]
    func createEnrollment(_ enrollment: Enrollment) async throws -> Enrollment
    func getEnrollmentForUser(userId: String, programId: String) async throws -> Enrollment?
}
```

#### Repository Implementations

```swift
// MARK: - Repository Implementations

class CloudKitUserRepository: UserRepository {
    private let cloudKitService: CloudKitService
    
    init(cloudKitService: CloudKitService) {
        self.cloudKitService = cloudKitService
    }
    
    func createUser(_ user: User) async throws -> User {
        let userDTO = UserDTO.fromDomain(user)
        let savedDTO = try await cloudKitService.saveUser(userDTO)
        return savedDTO.toDomain()
    }
    
    func getUser(id: String) async throws -> User? {
        let userDTO = try await cloudKitService.getUser(id: id)
        return userDTO?.toDomain()
    }
    
    func getUserByEmail(_ email: String) async throws -> User? {
        let userDTO = try await cloudKitService.getUserByEmail(email)
        return userDTO?.toDomain()
    }
    
    func updateUser(_ user: User) async throws -> User {
        let userDTO = UserDTO.fromDomain(user)
        let updatedDTO = try await cloudKitService.updateUser(userDTO)
        return updatedDTO.toDomain()
    }
    
    func deleteUser(id: String) async throws {
        try await cloudKitService.deleteUser(id: id)
    }
    
    func getUsersByType(_ type: UserType) async throws -> [User] {
        let userDTOs = try await cloudKitService.getUsersByType(type.rawValue)
        return userDTOs.map { $0.toDomain() }
    }
}

class FirebaseProgramRepository: ProgramRepository {
    private let firestoreService: FirestoreService
    
    init(firestoreService: FirestoreService) {
        self.firestoreService = firestoreService
    }
    
    func getProgram(id: String) async throws -> Program? {
        let programDTO = try await firestoreService.getProgram(id: id)
        return programDTO?.toDomain()
    }
    
    func getAllPrograms() async throws -> [Program] {
        let programDTOs = try await firestoreService.getAllPrograms()
        return programDTOs.map { $0.toDomain() }
    }
    
    func getProgramsByType(_ type: ProgramType) async throws -> [Program] {
        let programDTOs = try await firestoreService.getProgramsByType(type.rawValue)
        return programDTOs.map { $0.toDomain() }
    }
    
    func searchPrograms(query: String, limit: Int) async throws -> [Program] {
        let programDTOs = try await firestoreService.searchPrograms(query: query, limit: limit)
        return programDTOs.map { $0.toDomain() }
    }
    
    func createEnrollment(_ enrollment: Enrollment) async throws -> Enrollment {
        let enrollmentDTO = EnrollmentDTO.fromDomain(enrollment)
        let savedDTO = try await firestoreService.createEnrollment(enrollmentDTO)
        return savedDTO.toDomain()
    }
    
    func getEnrollmentForUser(userId: String, programId: String) async throws -> Enrollment? {
        let enrollmentDTO = try await firestoreService.getEnrollmentForUser(userId: userId, programId: programId)
        return enrollmentDTO?.toDomain()
    }
}
```

#### Data Transfer Objects (DTOs)

```swift
// MARK: - Data Transfer Objects

struct UserDTO: Codable {
    let id: String
    let email: String
    let name: String
    let userType: String
    let membershipType: String?
    let enrolledPrograms: [ProgramEnrollmentDTO]
    let accessLevel: String
    let dataStore: String
    let createdAt: Date
    let updatedAt: Date
    
    static func fromDomain(_ user: User) -> UserDTO {
        return UserDTO(
            id: user.id,
            email: user.email,
            name: user.name,
            userType: user.userType.rawValue,
            membershipType: user.membershipType?.rawValue,
            enrolledPrograms: user.enrolledPrograms.map { ProgramEnrollmentDTO.fromDomain($0) },
            accessLevel: user.accessLevel.rawValue,
            dataStore: user.dataStore.rawValue,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt
        )
    }
    
    func toDomain() -> User {
        return User(
            id: id,
            email: email,
            name: name,
            userType: UserType(rawValue: userType) ?? .freeUser,
            membershipType: membershipType.flatMap { MembershipType(rawValue: $0) },
            enrolledPrograms: enrolledPrograms.map { $0.toDomain() },
            accessLevel: DataAccessLevel(rawValue: accessLevel) ?? .freePublic,
            dataStore: DataStore(rawValue: dataStore) ?? .iCloud,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
```

### 3. Presentation Layer (UI)

The presentation layer handles UI logic and user interactions.

#### ViewModels

```swift
// MARK: - ViewModels

@MainActor
class PracticeSessionViewModel: ObservableObject {
    @Published var state = PracticeSessionState()
    
    private let createSessionUseCase: CreatePracticeSessionUseCase
    private let generateRecommendationsUseCase: GeneratePracticeRecommendationsUseCase
    private let errorHandler: ErrorHandler
    
    init(createSessionUseCase: CreatePracticeSessionUseCase,
         generateRecommendationsUseCase: GeneratePracticeRecommendationsUseCase,
         errorHandler: ErrorHandler) {
        self.createSessionUseCase = createSessionUseCase
        self.generateRecommendationsUseCase = generateRecommendationsUseCase
        self.errorHandler = errorHandler
    }
    
    func createSession(name: String, items: [PracticeItem]) async {
        state.isLoading = true
        state.errorMessage = nil
        
        do {
            let request = CreatePracticeSessionUseCase.Request(
                userId: state.currentUserId,
                name: name,
                items: items,
                scheduledDate: nil
            )
            
            let response = try await createSessionUseCase.execute(request)
            state.currentSession = response.session
            state.sessions.append(response.session)
            
        } catch {
            await errorHandler.handle(error)
            state.errorMessage = error.localizedDescription
        }
        
        state.isLoading = false
    }
    
    func generateRecommendations(focusArea: PracticeFocusArea? = nil, duration: TimeInterval? = nil) async {
        state.isLoadingRecommendations = true
        
        do {
            let request = GeneratePracticeRecommendationsUseCase.Request(
                userId: state.currentUserId,
                focusArea: focusArea,
                duration: duration
            )
            
            let response = try await generateRecommendationsUseCase.execute(request)
            state.recommendations = response.recommendations
            
        } catch {
            await errorHandler.handle(error)
            state.errorMessage = error.localizedDescription
        }
        
        state.isLoadingRecommendations = false
    }
}

struct PracticeSessionState {
    var currentUserId: String = ""
    var currentSession: PracticeSession?
    var sessions: [PracticeSession] = []
    var recommendations: [PracticeSession] = []
    var isLoading: Bool = false
    var isLoadingRecommendations: Bool = false
    var errorMessage: String?
}
```

#### Views

```swift
// MARK: - Views

struct PracticeHubView: View {
    @StateObject private var viewModel: PracticeSessionViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(viewModel: PracticeSessionViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Current Session Section
                if let currentSession = viewModel.state.currentSession {
                    CurrentSessionCard(session: currentSession)
                }
                
                // Quick Actions
                QuickActionsSection(viewModel: viewModel)
                
                // AI Recommendations
                RecommendationsSection(viewModel: viewModel)
                
                // Recent Sessions
                RecentSessionsSection(sessions: viewModel.state.sessions)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Practice Hub")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New Session") {
                        // Navigate to session creation
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.state.errorMessage != nil)) {
                Button("OK") {
                    viewModel.state.errorMessage = nil
                }
            } message: {
                Text(viewModel.state.errorMessage ?? "")
            }
        }
        .task {
            await viewModel.generateRecommendations()
        }
    }
}

struct CurrentSessionCard: View {
    let session: PracticeSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Session")
                    .font(.headline)
                Spacer()
                if session.isActive {
                    Text("Active")
                        .foregroundColor(.green)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            Text(session.name)
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack {
                Label("\(session.items.count) items", systemImage: "list.bullet")
                Spacer()
                Label(formatDuration(session.totalEstimatedDuration), systemImage: "clock")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Button("Continue Session") {
                // Navigate to active session
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
}
```

## Dependency Injection

### DI Container

```swift
// MARK: - Dependency Injection Container

protocol DIContainer {
    func resolve<T>() -> T
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
}

class DefaultDIContainer: DIContainer {
    private var factories: [String: () -> Any] = [:]
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
    }
    
    func resolve<T>() -> T {
        let key = String(describing: T.self)
        guard let factory = factories[key] else {
            fatalError("No factory registered for type: \(T.self)")
        }
        
        guard let instance = factory() as? T else {
            fatalError("Factory returned wrong type for: \(T.self)")
        }
        
        return instance
    }
}

// Service Registration
extension DefaultDIContainer {
    func registerServices() {
        // Core Services
        register(CloudKitService.self) { CloudKitService() }
        register(FirestoreService.self) { FirestoreService() }
        register(ErrorHandler.self) { ErrorHandler() }
        
        // Repositories
        register(UserRepository.self) { 
            CloudKitUserRepository(cloudKitService: self.resolve())
        }
        register(ProgramRepository.self) { 
            FirebaseProgramRepository(firestoreService: self.resolve())
        }
        register(PracticeRepository.self) { 
            CloudKitPracticeRepository(cloudKitService: self.resolve())
        }
        
        // Use Cases
        register(SignInUseCase.self) {
            SignInUseCase(
                authRepository: self.resolve(),
                userRepository: self.resolve()
            )
        }
        register(CreatePracticeSessionUseCase.self) {
            CreatePracticeSessionUseCase(
                practiceRepository: self.resolve(),
                userRepository: self.resolve()
            )
        }
        register(GeneratePracticeRecommendationsUseCase.self) {
            GeneratePracticeRecommendationsUseCase(
                practiceRepository: self.resolve(),
                userRepository: self.resolve(),
                recommendationEngine: self.resolve()
            )
        }
        
        // ViewModels
        register(PracticeSessionViewModel.self) {
            PracticeSessionViewModel(
                createSessionUseCase: self.resolve(),
                generateRecommendationsUseCase: self.resolve(),
                errorHandler: self.resolve()
            )
        }
    }
}
```

## Testing Strategy

### Unit Tests

```swift
// MARK: - Unit Tests

class CreatePracticeSessionUseCaseTests: XCTestCase {
    var useCase: CreatePracticeSessionUseCase!
    var mockPracticeRepository: MockPracticeRepository!
    var mockUserRepository: MockUserRepository!
    
    override func setUp() {
        super.setUp()
        mockPracticeRepository = MockPracticeRepository()
        mockUserRepository = MockUserRepository()
        useCase = CreatePracticeSessionUseCase(
            practiceRepository: mockPracticeRepository,
            userRepository: mockUserRepository
        )
    }
    
    func testCreateSession_Success() async throws {
        // Given
        let user = User.createTestUser()
        mockUserRepository.mockUser = user
        
        let request = CreatePracticeSessionUseCase.Request(
            userId: user.id,
            name: "Test Session",
            items: [],
            scheduledDate: nil
        )
        
        // When
        let response = try await useCase.execute(request)
        
        // Then
        XCTAssertEqual(response.session.name, "Test Session")
        XCTAssertEqual(response.session.userId, user.id)
        XCTAssertTrue(mockPracticeRepository.createSessionCalled)
    }
    
    func testCreateSession_UserNotFound_ThrowsError() async {
        // Given
        mockUserRepository.mockUser = nil
        
        let request = CreatePracticeSessionUseCase.Request(
            userId: "invalid-id",
            name: "Test Session",
            items: [],
            scheduledDate: nil
        )
        
        // When & Then
        do {
            _ = try await useCase.execute(request)
            XCTFail("Expected error to be thrown")
        } catch DomainError.userNotFound {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

class MockPracticeRepository: PracticeRepository {
    var createSessionCalled = false
    var mockSession: PracticeSession?
    
    func createSession(_ session: PracticeSession) async throws -> PracticeSession {
        createSessionCalled = true
        return mockSession ?? session
    }
    
    // Implement other methods...
}

class MockUserRepository: UserRepository {
    var mockUser: User?
    
    func getUser(id: String) async throws -> User? {
        return mockUser
    }
    
    // Implement other methods...
}
```

## Error Handling

### Error Types

```swift
// MARK: - Error Handling

enum AppError: Error, LocalizedError {
    case networkError(underlying: Error)
    case authenticationError(underlying: Error)
    case dataError(underlying: Error)
    case domainError(DomainError)
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection error. Please check your internet connection."
        case .authenticationError:
            return "Authentication failed. Please sign in again."
        case .dataError:
            return "Data error occurred. Please try again."
        case .domainError(let domainError):
            return domainError.localizedDescription
        case .unknownError:
            return "An unexpected error occurred. Please try again."
        }
    }
}

class ErrorHandler {
    func handle(_ error: Error) async {
        let appError = mapToAppError(error)
        
        // Log error
        print("Error: \(appError.localizedDescription)")
        
        // Send to analytics
        await sendToAnalytics(appError)
        
        // Show user-friendly message
        await showUserMessage(appError.localizedDescription)
    }
    
    private func mapToAppError(_ error: Error) -> AppError {
        switch error {
        case let domainError as DomainError:
            return .domainError(domainError)
        case let networkError as URLError:
            return .networkError(underlying: networkError)
        default:
            return .unknownError(error)
        }
    }
}
```

## Performance Considerations

### Memory Management

```swift
// MARK: - Performance Optimizations

// Use weak references in closures to prevent retain cycles
class PracticeSessionViewModel: ObservableObject {
    private weak var practiceRepository: PracticeRepository?
    
    func loadSessions() async {
        guard let repository = practiceRepository else { return }
        // Use repository
    }
}

// Implement proper cleanup in deinit
deinit {
    cancellables.removeAll()
    sessionTimer?.invalidate()
}
```

### Background Processing

```swift
// MARK: - Background Processing

class BackgroundTaskManager {
    func scheduleSessionSync() {
        Task.detached(priority: .background) {
            await self.syncPracticeSessions()
        }
    }
    
    private func syncPracticeSessions() async {
        // Sync logic here
    }
}
```

## Conclusion

This Clean Architecture implementation provides:

1. **Separation of Concerns**: Clear boundaries between layers
2. **Testability**: Easy unit testing of business logic
3. **Maintainability**: Modular and organized code structure
4. **Scalability**: Easy to add new features and modify existing ones
5. **Dependency Inversion**: Loose coupling between components

The key is to maintain strict adherence to the dependency rule: dependencies point inward toward the domain layer, and the domain layer has no knowledge of external frameworks or implementations. 