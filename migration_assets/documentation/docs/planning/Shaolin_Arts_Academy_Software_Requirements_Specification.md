# Shaolin Arts Academy - Software Requirements Specification (Clean Architecture Edition)

## System Design

### Overall Architecture
- **iOS Native App**: Primary application built with SwiftUI following Clean Architecture principles
- **Apple Watch Companion**: WatchKit app for practice guidance and tracking
- **CloudKit Integration**: User-generated content storage in iCloud
- **Firebase Backend**: Authentication, school content, and analytics
- **CRM Integration**: Student data synchronization from school CRM system
- **Hybrid Data Strategy**: CloudKit for user data, Firebase for school content and CRM data

### Clean Architecture Implementation
The app follows Clean Architecture principles with strict separation of concerns:

#### Architecture Layers
1. **Presentation Layer** (UI Layer)
   - **SwiftUI Views**: Pure UI components with no business logic
   - **ViewModels**: State management and UI logic coordination
   - **Coordinators**: Navigation and flow management
   - **UI Models**: Data structures specific to UI presentation

2. **Domain Layer** (Business Layer)
   - **Entities**: Core business objects (User, Program, Technique, etc.)
   - **Use Cases**: Business logic and application rules
   - **Interfaces**: Abstract contracts for data access and external services
   - **Value Objects**: Immutable objects representing business concepts

3. **Data Layer** (Infrastructure Layer)
   - **Repositories**: Concrete implementations of domain interfaces
   - **Data Sources**: Local storage, network APIs, and external services
   - **Data Models**: Database and API-specific data structures
   - **Mappers**: Convert between domain entities and data models

#### Dependency Rule
- **Inner layers** (Domain) have no knowledge of outer layers
- **Outer layers** (Data, Presentation) depend on inner layers
- **Dependencies point inward** toward the domain layer

### Component Architecture
- **Clean Architecture Pattern**: Strict separation of concerns with dependency inversion
- **Modular Design**: Feature-based modules for maintainability
- **Dependency Injection**: Service-based architecture with protocol-oriented design
- **Reactive Programming**: Combine framework for data binding and state management

### Platform Integration
- **iOS 15+ Support**: Minimum iOS version for modern SwiftUI features
- **watchOS 8+ Support**: Apple Watch companion app
- **iCloud Integration**: Seamless sync across user devices
- **Offline-First**: Core functionality available without internet

## Architecture Pattern

### Clean Architecture with MVVM
- **Views**: SwiftUI views for UI presentation (Presentation Layer)
- **ViewModels**: UI logic and state management (Presentation Layer)
- **Use Cases**: Business logic and application rules (Domain Layer)
- **Entities**: Core business objects (Domain Layer)
- **Repositories**: Data access abstraction (Data Layer)
- **Services**: External dependencies and implementations (Data Layer)

### Service Layer Architecture
- **AuthenticationService**: Firebase Auth, Sign in with Apple, Google Sign-In
- **UserService**: User profile management and CRM integration
- **ProgramService**: Curriculum and program management
- **PracticeService**: Practice session management and tracking
- **JournalService**: Journal entry management and media handling
- **MediaService**: Video and image content management
- **SubscriptionService**: Subscription and purchase management
- **NotificationService**: Push notifications and local notifications
- **AnalyticsService**: User behavior and app performance tracking

### Dependency Management
- **Swift Package Manager**: Primary dependency management
- **Dependency Injection Container**: Centralized service registration and resolution
- **Protocol-Oriented Design**: Interface-based architecture for testability
- **Factory Pattern**: Object creation and dependency management

## State Management

### Combine Framework Integration
- **@Published Properties**: Reactive state management in ViewModels
- **ObservableObject Protocol**: SwiftUI integration for state updates
- **Publishers and Subscribers**: Data flow and event handling
- **State Restoration**: App state persistence across sessions

### App State Management
- **User Session State**: Authentication status and user profile
- **Content State**: Downloaded content and offline availability
- **Practice State**: Current session, progress, and achievements
- **Navigation State**: Current screen and navigation history

### Local State Management
- **@State**: Local view state
- **@StateObject**: ViewModel instances
- **@ObservedObject**: External state observation
- **@EnvironmentObject**: Global app state sharing

## Data Flow

### User Authentication Flow
1. User initiates sign-in (Apple, Google, or email)
2. Firebase Auth processes authentication
3. **CRM Check**: System checks if user email exists in CRM student database
4. **Profile Creation**: 
   - If CRM match found: Create enrolled student profile with CRM data (name, programs, ranks)
   - If no CRM match: Create free user profile
5. App state updated with authenticated user and user type
6. Content access granted based on user type and enrolled programs

### Unified Practice System Flow
1. **Session Creation**: User creates or AI generates practice session
2. **Item Selection**: User selects forms, techniques, and exercises
3. **Session Execution**: Real-time tracking of practice performance
4. **Progress Recording**: Save session data and performance ratings
5. **Analytics Update**: Update learning insights and recommendations
6. **Achievement Check**: Unlock achievements based on performance

### Content Synchronization Flow
1. App checks for internet connectivity
2. Firebase content downloaded and cached locally
3. CloudKit user data synced across devices
4. Offline content marked as available
5. Sync status displayed to user

### CRM Synchronization Flow
1. **CRM Data Push**: School CRM system pushes student data to Firebase
2. **Data Validation**: System validates incoming CRM data format and completeness
3. **Profile Matching**: Match CRM data with existing app users by email
4. **Profile Updates**: Update existing user profiles with latest CRM data
5. **Content Access**: Grant/revoke access based on current enrollment status
6. **Notification**: Notify users of profile updates and new content access

### Data Persistence Strategy
- **Core Data**: Local database for offline content and caching
- **CloudKit**: User-generated content and preferences
- **Firebase Firestore**: School content and instructor data
- **UserDefaults**: App settings and preferences

## Technical Stack

### Frontend Technologies
- **SwiftUI**: Primary UI framework
- **Combine**: Reactive programming and state management
- **Core Data**: Local data persistence
- **WatchKit**: Apple Watch companion app

### Backend Services
- **Firebase Authentication**: User authentication and management
- **Firebase Firestore**: School content and instructor data
- **Firebase Storage**: Media content (videos, images)
- **CloudKit**: User-generated content and device sync
- **Firebase Analytics**: User behavior tracking

### Development Tools
- **Xcode**: Primary development environment
- **Swift Package Manager**: Dependency management
- **Git**: Version control
- **Firebase Console**: Backend management

### Third-Party Libraries
- **Firebase iOS SDK**: Firebase services integration
- **Google Sign-In SDK**: Google authentication
- **SDWebImage**: Image loading and caching
- **AVFoundation**: Video playback and media handling

## Authentication Process

### Sign-In Options
- **Sign in with Apple**: Primary authentication method
- **Google Sign-In**: Alternative authentication option
- **Email/Password**: Traditional authentication for instructors
- **Anonymous Auth**: Free tier access without account creation

### Authentication Flow
1. **App Launch**: Check for existing authentication
2. **Sign-In Screen**: Present authentication options
3. **Provider Selection**: User chooses authentication method
4. **Authentication**: Firebase processes authentication
5. **Profile Creation**: User profile created in CloudKit
6. **Content Access**: User type determines content access

### User Type Management
- **Free Users**: Anonymous or basic account, limited content
- **Enrolled Students**: Full access to school curriculum
- **Paid Users**: Access to purchased courses
- **Instructors**: Administrative access and student management
- **Parents**: Child progress monitoring access

### Security Considerations
- **Token Management**: Secure token storage in Keychain
- **Biometric Authentication**: Face ID/Touch ID integration
- **Session Management**: Automatic session refresh
- **Data Encryption**: End-to-end encryption for sensitive data

## Route Design

### Navigation Structure
- **Tab-Based Navigation**: 5 main sections (Dashboard, Practice, Learn, Journal, Profile)
- **Stack Navigation**: Detail views and sub-screens
- **Modal Presentation**: Settings, authentication, and content creation
- **Deep Linking**: Direct access to specific content

### Screen Hierarchy
```
Dashboard
├── Progress Overview
├── Recent Activity
├── Quick Actions
└── Content Recommendations

Practice (Unified Practice System)
├── Session Creation
├── AI Recommendations
├── Active Session
├── Session History
├── Analytics & Insights
└── Templates

Learn
├── Curriculum Browser
├── Technique Library
├── Rank Progression
└── Search and Filter

Journal
├── Entry List
├── Entry Editor
├── Media Gallery
└── Search and Tags

Profile
├── User Settings
├── Progress Analytics
├── Achievements
└── Subscription Management
```

## Unified Practice System Architecture

### Core Components
1. **PracticeSession Entity**: Core business object representing a practice session
2. **PracticeUseCase**: Business logic for session management and recommendations
3. **PracticeRepository**: Data access for session persistence and retrieval
4. **PracticeViewModel**: UI logic for practice interface
5. **PracticeView**: SwiftUI interface for practice experience

### AI Integration
1. **RecommendationEngine**: AI-powered session generation
2. **LearningAnalytics**: Performance analysis and insights
3. **AdaptiveLearning**: Dynamic difficulty adjustment
4. **SpacedRepetition**: Optimal retention scheduling

### Data Models
```swift
// Domain Entities
struct PracticeSession {
    let id: String
    let userId: String
    let name: String
    let items: [PracticeItem]
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
    let notes: String?
}

struct PracticeItem {
    let id: String
    let type: PracticeItemType
    let contentId: String
    let order: Int
    let estimatedDuration: TimeInterval
    let rating: SessionRating?
}

struct SessionRating {
    let difficulty: Int
    let confidence: Int
    let quality: Int
    let repetitions: Int
    let timeSpent: TimeInterval
    let needsMorePractice: Bool
    let notes: String?
}
```

### Service Interfaces
```swift
protocol PracticeService {
    func createSession(_ session: PracticeSession) async throws -> PracticeSession
    func getSession(id: String) async throws -> PracticeSession?
    func updateSession(_ session: PracticeSession) async throws -> PracticeSession
    func deleteSession(id: String) async throws
    func getUserSessions(userId: String) async throws -> [PracticeSession]
    func generateRecommendations(for userId: String) async throws -> [PracticeSession]
}
```

## Quality Assurance

### Testing Strategy
- **Unit Tests**: 80% coverage for domain layer and use cases
- **Integration Tests**: Service layer and repository implementations
- **UI Tests**: Critical user flows and navigation
- **Performance Tests**: Memory usage and response times

### Code Quality Standards
- **SwiftLint**: Code style and formatting consistency
- **Documentation**: Comprehensive API documentation
- **Error Handling**: Graceful error handling with user feedback
- **Accessibility**: Full VoiceOver and Dynamic Type support

### Performance Requirements
- **App Launch**: Under 2 seconds cold start
- **UI Responsiveness**: 60fps scrolling and animations
- **Memory Usage**: Efficient handling of video content
- **Offline Performance**: Full functionality without internet

### Security Requirements
- **Data Encryption**: End-to-end encryption for user data
- **Authentication**: Secure token management and biometric integration
- **Privacy**: GDPR and CCPA compliance
- **Network Security**: HTTPS for all communications