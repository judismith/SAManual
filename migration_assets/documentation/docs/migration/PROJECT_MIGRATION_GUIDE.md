# Project Migration Guide - Clean Architecture Implementation

## Overview

This document outlines the systematic approach to migrate from the current legacy codebase to a new Clean Architecture implementation while preserving all valuable assets and insights.

## Phase 1: Asset Inventory & Documentation

### 1.1 Firebase Configuration Inventory

#### Current Firebase Project Details
- **Project ID**: [Extract from GoogleService-Info.plist]
- **Bundle ID**: [Current app bundle identifier]
- **Authentication Methods**: 
  - Sign in with Apple
  - Google Sign-In
  - Email/Password
  - Anonymous Auth

#### Firestore Collections Structure
```
users/
├── {userId}/
│   ├── profile: UserProfile
│   ├── progress: ProgressData
│   ├── achievements: Achievement[]
│   └── preferences: UserPreferences

crm_students/
├── {email}/
│   ├── name: String
│   ├── enrolledPrograms: ProgramEnrollment[]
│   ├── ranks: RankProgress[]
│   ├── enrollmentDate: Date
│   ├── lastUpdated: Date
│   └── status: EnrollmentStatus

curriculum/
├── programs/
│   ├── {programId}/
│   │   ├── metadata: ProgramMetadata
│   │   ├── ranks: Rank[]
│   │   └── techniques: Technique[]
├── techniques/
│   ├── {techniqueId}/
│   │   ├── metadata: TechniqueMetadata
│   │   ├── content: TechniqueContent
│   │   └── media: MediaReference[]

instructors/
├── {instructorId}/
│   ├── profile: InstructorProfile
│   ├── students: StudentReference[]
│   └── analytics: InstructorAnalytics

content/
├── articles/
├── videos/
├── announcements/
└── challenges/
```

#### Firebase Storage Structure
```
media/
├── videos/
│   ├── techniques/
│   ├── forms/
│   └── tutorials/
├── images/
│   ├── thumbnails/
│   ├── profile-photos/
│   └── content-images/
└── documents/
    ├── manuals/
    └── guides/
```

### 1.2 CloudKit Schema Documentation

#### Record Types
```
UserProfile
├── recordID: CKRecord.ID
├── name: String
├── email: String
├── userType: UserType
├── rank: Rank
├── joinDate: Date
└── preferences: Data

JournalEntry
├── recordID: CKRecord.ID
├── title: String
├── content: String
├── mediaURLs: [URL]
├── techniqueTags: [String]
├── practiceDate: Date
├── createdDate: Date
└── modifiedDate: Date

PracticeSession
├── recordID: CKRecord.ID
├── sessionType: SessionType
├── duration: TimeInterval
├── techniques: [String]
├── notes: String
├── metrics: Data
├── startDate: Date
└── endDate: Date

UserProgress
├── recordID: CKRecord.ID
├── techniqueID: String
├── masteryLevel: MasteryLevel
├── practiceCount: Int
├── lastPracticed: Date
└── notes: String
```

#### Custom Indexes
- [Document any custom indexes for performance]

#### Subscriptions
- [Document push notification subscriptions]

### 1.3 UI Design System Documentation

#### Color Palette
```
Primary Colors:
- AppPrimaryColor: #007AFF (Blue)
- AppSecondaryColor: #FF6B35 (Orange)
- BrandAccent: #FFD700 (Gold)

Background Colors:
- Background: #FFFFFF (White)
- Surface: #F8F9FA (Light Gray)
- SurfaceDark: #1C1C1E (Dark Gray)

Text Colors:
- TextPrimary: #000000 (Black)
- TextSecondary: #6C757D (Gray)

Status Colors:
- Success: #28A745 (Green)
- Error: #DC3545 (Red)
- Warning: #FFC107 (Yellow)
```

#### Typography
```
Headings:
- Large Title: 34pt, Bold
- Title 1: 28pt, Bold
- Title 2: 22pt, Bold
- Title 3: 20pt, Bold

Body Text:
- Body: 17pt, Regular
- Callout: 16pt, Regular
- Subheadline: 15pt, Medium
- Footnote: 13pt, Regular
- Caption 1: 12pt, Regular
- Caption 2: 11pt, Regular
```

#### Spacing System
```
- xs: 4pt
- sm: 8pt
- md: 16pt
- lg: 24pt
- xl: 32pt
- xxl: 48pt
```

#### Component Styles
```
Buttons:
- Primary: Blue background, white text, rounded corners
- Secondary: Gray background, dark text, rounded corners
- Destructive: Red background, white text, rounded corners

Cards:
- Background: White
- Shadow: Subtle drop shadow
- Corner Radius: 12pt
- Padding: 16pt

Navigation:
- Tab Bar: Custom martial arts themed icons
- Navigation Bar: Transparent with blur effect
```

### 1.4 Business Logic Documentation

#### Core Domain Entities
```
User
├── id: String
├── email: String
├── name: String
├── userType: UserType (free, student, instructor, admin, parent, paid)
├── membershipType: MembershipType? (student, instructor, assistant)
├── enrolledPrograms: [ProgramEnrollment]
├── accessLevel: DataAccessLevel
├── dataStore: DataStore
├── createdAt: Date
└── updatedAt: Date

Program
├── id: String
├── name: String
├── description: String
├── type: ProgramType (kungFu, youthKungFu, meditation, etc.)
├── isActive: Bool
├── instructorIds: [String]
├── ranks: [Rank]
├── curriculum: [CurriculumItem]
├── createdAt: Date
└── updatedAt: Date

Technique/CurriculumItem
├── id: String
├── programId: String
├── rankId: String
├── name: String
├── description: String
├── type: CurriculumItemType (form, technique, exercise, etc.)
├── order: Int
├── requiredForPromotion: Bool
├── mediaUrls: [String]
├── writtenInstructions: String?
├── estimatedPracticeTime: TimeInterval
├── difficulty: DifficultyLevel
├── prerequisites: [String]
├── tags: [String]
├── createdAt: Date
└── updatedAt: Date
```

#### Business Rules
```
User Access Control:
- Free users: Limited content access, basic journaling
- Students: Full access to enrolled programs
- Instructors: Student management, content creation
- Parents: Child progress monitoring
- Paid users: Premium content access

Practice Session Rules:
- Users can only practice techniques they have access to
- Session duration tracked automatically
- Progress saved after each session
- AI recommendations based on user progress

Content Access Rules:
- Public content: Available to all users
- Program content: Available to enrolled students
- Premium content: Available to paid subscribers
- Instructor content: Available to instructors only
```

### 1.5 Feature Requirements Documentation

#### Core Features
1. **Authentication System**
   - Sign in with Apple
   - Google Sign-In
   - Email/Password
   - Anonymous auth for free tier
   - Biometric authentication

2. **User Management**
   - User profile creation and management
   - User type system with role-based access
   - CRM integration for student data
   - Parent-child account linking

3. **Curriculum Management**
   - Program and technique library
   - Rank progression system
   - Content access control
   - Offline content caching

4. **Practice System**
   - Session creation and management
   - Real-time practice tracking
   - AI-powered recommendations
   - Progress analytics

5. **Journal System**
   - Text, photo, and video journaling
   - Technique tagging
   - Search and filtering
   - Media management

6. **Gamification**
   - Achievement system
   - Progress tracking
   - Streaks and challenges
   - Leaderboards

#### User Stories
[Reference the updated PRD for complete user stories]

## Phase 2: New Project Setup

### 2.1 Project Structure
```
SAKungFuJournal/
├── Domain/
│   ├── Entities/
│   ├── UseCases/
│   ├── ValueObjects/
│   └── Errors/
├── Data/
│   ├── Repositories/
│   ├── DataSources/
│   ├── DTOs/
│   └── Mappers/
├── Presentation/
│   ├── Views/
│   ├── ViewModels/
│   └── Coordinators/
├── Infrastructure/
│   ├── DI/
│   ├── Services/
│   └── Configuration/
├── Resources/
│   ├── Assets.xcassets/
│   ├── Localizable.strings/
│   └── Configuration/
└── Tests/
    ├── DomainTests/
    ├── DataTests/
    └── PresentationTests/
```

### 2.2 Migration Checklist

#### Pre-Migration Tasks
- [ ] Export Firebase configuration
- [ ] Document CloudKit schema
- [ ] Backup UI assets
- [ ] Document business logic
- [ ] Create feature inventory

#### New Project Setup
- [ ] Create new Xcode project
- [ ] Set up folder structure
- [ ] Configure Firebase
- [ ] Set up CloudKit
- [ ] Install dependencies

#### Foundation Implementation
- [ ] Implement domain layer
- [ ] Create repository interfaces
- [ ] Set up dependency injection
- [ ] Implement error handling
- [ ] Create basic services

#### Feature Migration
- [ ] Authentication system
- [ ] User management
- [ ] Curriculum system
- [ ] Practice system
- [ ] Journal system
- [ ] Gamification

## Phase 3: Validation & Testing

### 3.1 Migration Validation
- [ ] Verify Firebase connectivity
- [ ] Test CloudKit operations
- [ ] Validate UI components
- [ ] Confirm business logic
- [ ] Test user flows

### 3.2 Performance Testing
- [ ] App startup time
- [ ] Memory usage
- [ ] Network performance
- [ ] Offline functionality

### 3.3 User Acceptance Testing
- [ ] Core user flows
- [ ] Edge cases
- [ ] Error scenarios
- [ ] Accessibility

## Success Criteria

### Technical Success
- [ ] Clean Architecture properly implemented
- [ ] All features migrated successfully
- [ ] Performance requirements met
- [ ] Test coverage > 80%

### Business Success
- [ ] All user stories implemented
- [ ] User experience maintained or improved
- [ ] No data loss during migration
- [ ] Smooth transition for existing users

## Risk Mitigation

### Technical Risks
- **Data Loss**: Comprehensive backup strategy
- **Performance Issues**: Continuous monitoring
- **Integration Problems**: Thorough testing

### Business Risks
- **User Disruption**: Phased rollout
- **Feature Regression**: Comprehensive testing
- **Timeline Delays**: Buffer time in planning

## Timeline

### Week 1: Asset Documentation
- Complete asset inventory
- Document all configurations
- Create migration plan

### Week 2: New Project Setup
- Create new Xcode project
- Set up Clean Architecture structure
- Configure Firebase and CloudKit

### Week 3-4: Foundation Implementation
- Domain layer implementation
- Repository pattern setup
- Dependency injection

### Week 5-6: Core Features
- Authentication system
- User management
- Basic UI components

### Week 7-8: Feature Migration
- Curriculum system
- Practice system
- Journal system

### Week 9-10: Testing & Polish
- Comprehensive testing
- Performance optimization
- User acceptance testing

## Conclusion

This migration approach ensures we preserve all valuable assets while creating a clean, maintainable, and scalable codebase. The systematic documentation and phased approach minimizes risks while maximizing the benefits of Clean Architecture. 