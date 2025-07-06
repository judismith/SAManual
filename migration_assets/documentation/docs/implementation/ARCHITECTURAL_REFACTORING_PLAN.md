# Architectural Refactoring Plan

## Document Information
**Document Type:** Architectural Refactoring Plan  
**Created:** July 5, 2025  
**Last Updated:** July 5, 2025  
**Status:** Planning Phase  
**Version:** 1.0  

---

## Executive Summary

This document outlines a comprehensive architectural refactoring of the SAKungFuJournal codebase to establish a clean, testable, and maintainable foundation before implementing the major Practice Feature. The refactoring will transform the current mixed-pattern architecture into a modern, protocol-based system with proper dependency injection, error handling, and separation of concerns.

### Key Goals
1. **Establish Clean Architecture** - Protocol-based services with clear separation of concerns
2. **Enable Comprehensive Testing** - Dependency injection for mockable components
3. **Improve Maintainability** - Break down massive classes into focused, single-responsibility components
4. **Standardize Patterns** - Consistent error handling, state management, and data flow
5. **Future-Proof Foundation** - Architecture that supports complex features like the Practice system

---

## Current Architecture Analysis

### Critical Issues Identified

#### 1. Service Layer Problems
- **Massive DataService Class:** 1424 lines violating Single Responsibility Principle
- **Tight Coupling:** Hard-coded singleton dependencies preventing testing
- **Mixed Patterns:** Inconsistent service interaction patterns across the app
- **No Abstraction:** Concrete classes instead of protocol-based interfaces

#### 2. Dependency Management Issues
- **Hard-coded Singletons:** `DataService.shared`, `CloudKitService.shared` everywhere
- **No Dependency Injection:** Impossible to inject test doubles or alternative implementations
- **Environment Coupling:** Cannot differentiate between dev/staging/production configurations

#### 3. Error Handling Inconsistencies
- **Multiple Patterns:** Completion handlers, async/await, and optional returns mixed throughout
- **No Domain Errors:** Generic NSError instead of meaningful domain-specific errors
- **Scattered Handling:** No centralized error management or recovery strategies

#### 4. View Architecture Problems
- **Massive View Files:** 2000+ line files mixing UI and business logic
- **Direct Service Dependencies:** Views directly depending on concrete services
- **Inconsistent State Management:** Mixed patterns for loading, error, and success states

---

## Target Architecture Vision

### Clean Architecture Principles

#### 1. Layered Architecture
```
┌─────────────────────────────────────┐
│              UI Layer               │
│    (Views, ViewModels, Components)  │
├─────────────────────────────────────┤
│           Business Layer            │
│     (Services, Use Cases, Logic)    │
├─────────────────────────────────────┤
│             Data Layer              │
│   (Repositories, Data Sources)      │
├─────────────────────────────────────┤
│          Infrastructure             │
│  (CloudKit, Firestore, External)   │
└─────────────────────────────────────┘
```

#### 2. Dependency Flow
- **UI Layer** depends on Business Layer (through protocols)
- **Business Layer** depends on Data Layer (through protocols)
- **Data Layer** implements infrastructure abstractions
- **No circular dependencies** - strict unidirectional flow

#### 3. Protocol-Based Design
- All service interactions through protocols
- Repository pattern for data access
- Dependency injection for all components
- Mockable interfaces for comprehensive testing

---

## Refactoring Strategy

### Phase 1: Foundation (Week 1)
**Goal:** Establish core infrastructure for clean architecture

#### 1.1 Dependency Injection Framework
```swift
protocol DIContainer {
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
    func resolve<T>(_ type: T.Type) -> T
}

class DefaultDIContainer: DIContainer {
    // Thread-safe dependency registration and resolution
}
```

#### 1.2 Environment Configuration
```swift
enum Environment { case development, staging, production }

class AppConfiguration {
    let environment: Environment
    let container: DIContainer
    // Environment-specific service registration
}
```

#### 1.3 Core Error Framework
```swift
enum AppError: Error, LocalizedError {
    case userNotFound(id: String)
    case programNotFound(id: String)
    case networkError(underlying: Error)
    case validationError(field: String, message: String)
    case permissionDenied
    case dataCorruption(details: String)
}

@MainActor
class ErrorHandler: ObservableObject {
    @Published var currentError: AppError?
    @Published var showingError = false
    
    func handle(_ error: Error)
    func clearError()
}
```

### Phase 2: Service Layer Refactoring (Week 2)
**Goal:** Break down DataService and establish clean service boundaries

#### 2.1 Service Protocol Definitions
```swift
// User Management
protocol UserServiceProtocol {
    func getCurrentUser() async throws -> UserProfile
    func updateUser(_ user: UserProfile) async throws
    func deleteUser(id: String) async throws
}

// Program Management  
protocol ProgramServiceProtocol {
    func getPrograms() async throws -> [Program]
    func getProgram(id: String) async throws -> Program?
    func getUserPrograms(userId: String) async throws -> [Program]
}

// Enrollment Management
protocol EnrollmentServiceProtocol {
    func getEnrollments(userId: String) async throws -> [EnrollmentData]
    func updateEnrollment(_ enrollment: EnrollmentData) async throws
    func createEnrollment(_ enrollment: EnrollmentData) async throws
}

// Media & Content
protocol MediaServiceProtocol {
    func getMediaURL(for contentId: String) async throws -> URL
    func canAccessContent(userId: String, contentId: String) -> Bool
    func downloadContent(contentId: String) async throws -> Data
}

// Authentication & Authorization
protocol AuthServiceProtocol {
    func signIn() async throws -> UserProfile
    func signOut() async throws
    func getCurrentAuthState() -> AuthState
}
```

#### 2.2 Repository Pattern Implementation
```swift
// Data layer abstractions
protocol UserRepositoryProtocol {
    func fetchUser(id: String) async throws -> UserProfile
    func saveUser(_ user: UserProfile) async throws
    func deleteUser(id: String) async throws
}

protocol ProgramRepositoryProtocol {
    func fetchPrograms() async throws -> [Program]
    func fetchProgram(id: String) async throws -> Program?
}

// Concrete implementations
class CloudKitUserRepository: UserRepositoryProtocol { }
class FirestoreUserRepository: UserRepositoryProtocol { }
class CompositeProgramRepository: ProgramRepositoryProtocol {
    // Combines CloudKit and Firestore data
}
```

#### 2.3 Service Implementation
```swift
class UserService: UserServiceProtocol {
    private let cloudKitRepo: UserRepositoryProtocol
    private let firestoreRepo: UserRepositoryProtocol
    private let errorHandler: ErrorHandler
    
    init(
        cloudKitRepo: UserRepositoryProtocol,
        firestoreRepo: UserRepositoryProtocol,
        errorHandler: ErrorHandler
    ) {
        self.cloudKitRepo = cloudKitRepo
        self.firestoreRepo = firestoreRepo
        self.errorHandler = errorHandler
    }
    
    // Clean, focused implementation
}
```

### Phase 3: Repository Implementation (Week 3)
**Goal:** Implement repository pattern for all data sources

#### 3.1 CloudKit Repositories
```swift
class CloudKitUserRepository: UserRepositoryProtocol {
    private let container: CKContainer
    private let database: CKDatabase
    
    func fetchUser(id: String) async throws -> UserProfile {
        // CloudKit-specific implementation with proper error handling
    }
}

class CloudKitEnrollmentRepository: EnrollmentRepositoryProtocol {
    // Handle enrollment data in CloudKit
}
```

#### 3.2 Firestore Repositories
```swift
class FirestoreProgramRepository: ProgramRepositoryProtocol {
    private let db: Firestore
    
    func fetchPrograms() async throws -> [Program] {
        // Firestore-specific implementation with proper error handling
    }
}

class FirestoreMediaRepository: MediaRepositoryProtocol {
    // Handle media metadata and URLs
}
```

#### 3.3 Composite Repositories
```swift
class CompositeUserRepository: UserRepositoryProtocol {
    private let cloudKitRepo: CloudKitUserRepository
    private let firestoreRepo: FirestoreUserRepository
    
    func fetchUser(id: String) async throws -> UserProfile {
        // Intelligent data merging from multiple sources
        // Handle CloudKit primary, Firestore fallback scenarios
    }
}
```

### Phase 4: ViewModel Refactoring (Week 4)
**Goal:** Clean up ViewModels with proper dependency injection

#### 4.1 ViewModel Base Architecture
```swift
@MainActor
protocol ViewModelProtocol: ObservableObject {
    associatedtype State
    var state: State { get set }
    func onAppear()
    func onDisappear()
}

@MainActor
class BaseViewModel<S>: ViewModelProtocol {
    @Published var state: S
    protected let errorHandler: ErrorHandler
    
    init(initialState: S, errorHandler: ErrorHandler) {
        self.state = initialState
        self.errorHandler = errorHandler
    }
}
```

#### 4.2 Specific ViewModel Implementations
```swift
@MainActor
class PracticeTrackingViewModel: BaseViewModel<PracticeTrackingState> {
    private let programService: ProgramServiceProtocol
    private let enrollmentService: EnrollmentServiceProtocol
    
    init(
        programService: ProgramServiceProtocol,
        enrollmentService: EnrollmentServiceProtocol,
        errorHandler: ErrorHandler
    ) {
        self.programService = programService
        self.enrollmentService = enrollmentService
        super.init(initialState: .loading, errorHandler: errorHandler)
    }
    
    func loadPrograms(for userId: String) async {
        // Clean, focused business logic
    }
}

enum PracticeTrackingState {
    case loading
    case loaded(programs: [Program], enrollments: [EnrollmentData])
    case error(AppError)
}
```

### Phase 5: View Layer Refactoring (Week 5)
**Goal:** Break down massive views and establish clean UI patterns

#### 5.1 View Component Architecture
```swift
// Break down large views into focused components
struct PracticeView: View {
    @StateObject private var viewModel: PracticeTrackingViewModel
    
    init(container: DIContainer) {
        _viewModel = StateObject(wrappedValue: 
            container.resolve(PracticeTrackingViewModel.self)
        )
    }
    
    var body: some View {
        NavigationView {
            content
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }
    
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            LoadingView()
        case .loaded(let programs, let enrollments):
            PracticeContentView(programs: programs, enrollments: enrollments)
        case .error(let error):
            ErrorView(error: error) { 
                Task { await viewModel.retry() }
            }
        }
    }
}

struct PracticeContentView: View {
    let programs: [Program]
    let enrollments: [EnrollmentData]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(programs) { program in
                    ProgramSectionView(
                        program: program,
                        enrollment: enrollments.first { $0.programId == program.id }
                    )
                }
            }
        }
    }
}
```

#### 5.2 Reusable UI Components
```swift
// Create focused, reusable components
struct LoadingView: View { }
struct ErrorView: View { }
struct ProgramSectionView: View { }
struct RankProgressView: View { }
struct TechniqueListView: View { }
struct FormListView: View { }
```

### Phase 6: Testing Infrastructure (Week 6)
**Goal:** Establish comprehensive testing framework

#### 6.1 Mock Implementations
```swift
class MockUserService: UserServiceProtocol {
    var shouldThrowError = false
    var mockUsers: [UserProfile] = []
    
    func getCurrentUser() async throws -> UserProfile {
        if shouldThrowError {
            throw AppError.userNotFound(id: "test")
        }
        return mockUsers.first!
    }
}

class MockProgramService: ProgramServiceProtocol {
    var mockPrograms: [Program] = []
    
    func getPrograms() async throws -> [Program] {
        return mockPrograms
    }
}
```

#### 6.2 Test Container Configuration
```swift
class TestDIContainer: DIContainer {
    func setupTestDependencies() {
        register(UserServiceProtocol.self) { MockUserService() }
        register(ProgramServiceProtocol.self) { MockProgramService() }
        register(ErrorHandler.self) { ErrorHandler() }
    }
}
```

#### 6.3 Unit Tests
```swift
class UserServiceTests: XCTestCase {
    var userService: UserServiceProtocol!
    var mockRepository: MockUserRepository!
    
    override func setUp() {
        mockRepository = MockUserRepository()
        userService = UserService(
            cloudKitRepo: mockRepository,
            firestoreRepo: mockRepository,
            errorHandler: ErrorHandler()
        )
    }
    
    func testGetCurrentUser_Success() async throws {
        // Test implementation
    }
    
    func testGetCurrentUser_UserNotFound() async {
        // Test error handling
    }
}
```

---

## Implementation Timeline

### Week 1: Foundation
**Monday-Tuesday:**
- Set up dependency injection container
- Create environment configuration system
- Implement core error handling framework

**Wednesday-Thursday:**
- Create service protocol definitions
- Set up testing infrastructure basics
- Create mock implementations

**Friday:**
- Integration testing of DI container
- Documentation and code review

### Week 2: Service Layer
**Monday-Tuesday:**
- Break down DataService into UserService
- Implement ProgramService and EnrollmentService
- Create MediaService and AuthService

**Wednesday-Thursday:**
- Update app initialization with DI container
- Migrate existing features to new services
- Test service integrations

**Friday:**
- Performance testing and optimization
- Error handling integration testing

### Week 3: Repository Pattern
**Monday-Tuesday:**
- Implement CloudKit repositories
- Create Firestore repositories
- Build composite repository logic

**Wednesday-Thursday:**
- Update services to use repositories
- Data migration and validation
- Repository integration testing

**Friday:**
- Performance optimization
- Data consistency verification

### Week 4: ViewModel Refactoring
**Monday-Tuesday:**
- Create base ViewModel architecture
- Refactor PracticeTrackingViewModel
- Update AnnouncementsViewModel and others

**Wednesday-Thursday:**
- Implement proper state management
- Add ViewModel unit tests
- Integration with new services

**Friday:**
- UI integration testing
- State management validation

### Week 5: View Layer
**Monday-Tuesday:**
- Break down PracticeTrackingView
- Create reusable UI components
- Implement clean view architecture

**Wednesday-Thursday:**
- Update all major views with DI
- Create component library
- UI consistency verification

**Friday:**
- Integration testing
- Performance optimization
- UI/UX validation

### Week 6: Testing & Validation
**Monday-Tuesday:**
- Complete unit test coverage
- Integration test implementation
- Performance benchmarking

**Wednesday-Thursday:**
- End-to-end testing
- Error scenario validation
- Documentation completion

**Friday:**
- Final integration testing
- Deployment preparation
- Architecture review

---

## Migration Strategy

### Data Migration
1. **CloudKit Schema Updates:** Add new fields for enhanced tracking
2. **Firestore Migration:** Update document structures for new models
3. **User Data Preservation:** Ensure no data loss during migration
4. **Rollback Plan:** Ability to revert to previous data structures

### Code Migration
1. **Feature Flags:** Toggle between old and new implementations
2. **Gradual Rollout:** Migrate one feature at a time
3. **Parallel Systems:** Run both architectures during transition
4. **Validation:** Comprehensive testing at each migration step

### Risk Mitigation
1. **Backup Strategy:** Full data backups before any migration
2. **Monitoring:** Real-time monitoring during migration
3. **Rollback Triggers:** Automated rollback on error thresholds
4. **User Communication:** Clear communication about any temporary issues

---

## Quality Assurance

### Testing Strategy
1. **Unit Tests:** 90%+ coverage on business logic
2. **Integration Tests:** Service and repository interactions
3. **UI Tests:** Critical user workflow validation
4. **Performance Tests:** Response time and resource usage benchmarks

### Code Quality
1. **Code Reviews:** All changes reviewed by team leads
2. **Static Analysis:** SwiftLint and other quality tools
3. **Documentation:** Comprehensive API documentation
4. **Best Practices:** Consistent coding standards throughout

### Monitoring
1. **Error Tracking:** Comprehensive error monitoring
2. **Performance Metrics:** App performance and user experience
3. **Usage Analytics:** Feature adoption and user behavior
4. **Crash Reporting:** Real-time crash detection and reporting

---

## Success Metrics

### Technical Metrics
1. **Test Coverage:** >90% unit test coverage
2. **Build Time:** <30 seconds for incremental builds
3. **App Launch Time:** <2 seconds cold start
4. **Memory Usage:** <100MB typical usage

### Architecture Quality
1. **Cyclomatic Complexity:** <10 for all methods
2. **Class Size:** <300 lines per class
3. **Method Length:** <50 lines per method
4. **Dependency Count:** <5 dependencies per class

### Development Velocity
1. **Feature Development:** 50% faster development for new features
2. **Bug Fix Time:** 75% reduction in bug resolution time
3. **Testing Time:** 80% reduction in manual testing effort
4. **Code Review Time:** 60% faster code review process

---

## Post-Refactoring Benefits

### For Practice Feature Development
1. **Clean Foundation:** Protocol-based architecture ready for complex features
2. **Testability:** Comprehensive mocking and testing capabilities
3. **Maintainability:** Clear separation of concerns for practice logic
4. **Scalability:** Easy addition of AI services, scheduling algorithms
5. **Reliability:** Robust error handling for practice session management

### For Future Development
1. **Developer Productivity:** Faster feature development with clean architecture
2. **Code Quality:** Consistent patterns and practices across the codebase
3. **Team Onboarding:** Clear architecture makes onboarding new developers easier
4. **Technical Debt:** Significant reduction in accumulated technical debt

### For Product Success
1. **User Experience:** More reliable and performant application
2. **Feature Velocity:** Faster delivery of new user-facing features
3. **Quality:** Fewer bugs and more stable releases
4. **Scalability:** Architecture that supports future growth and complexity

---

## Conclusion

This comprehensive architectural refactoring will transform the SAKungFuJournal codebase from a mixed-pattern system into a modern, clean architecture that supports robust testing, maintainable code, and rapid feature development. While the investment is significant (6 weeks), the long-term benefits in development velocity, code quality, and feature reliability make this essential before implementing complex features like the Practice system.

The refactoring follows industry best practices including Clean Architecture principles, SOLID design patterns, and comprehensive testing strategies. Upon completion, the codebase will serve as a solid foundation for years of future development while maintaining high quality and developer productivity.

---

*This plan serves as the authoritative guide for the architectural refactoring and will be updated as implementation progresses.*