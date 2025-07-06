# Shaolin Arts Academy - Product Requirements Document (Clean Architecture Edition)

## 1. Elevator Pitch

Shaolin Arts Academy is an iOS app with Apple Watch companion designed to revolutionize martial arts learning through structured journaling, digital curriculum management, and AI-powered practice development. The app provides martial arts students with a comprehensive platform to document their training journey, track technique mastery, and access structured learning content enhanced by on-device AI that creates personalized practice sessions based on state-of-the-art educational and training principles. The Apple Watch companion app enables hands-free practice guidance, workout tracking, and real-time feedback during training sessions. By combining traditional note-taking with modern digital tools, intelligent practice recommendations, and wearable technology, students can capture detailed insights about techniques, forms, and principles while receiving tailored guidance to truly master their martial arts. The app serves three distinct user segments: free users creating their own programs, enrolled students accessing the school's structured curriculum, and paid general users purchasing individual courses.

## 2. Architecture Foundation

### Clean Architecture Principles
The app is built following Clean Architecture principles to ensure:
- **Independence of Frameworks**: Core business logic is independent of UI frameworks
- **Testability**: Business rules can be tested without UI, database, or external dependencies
- **Independence of UI**: UI can change easily without changing business logic
- **Independence of Database**: Business rules are not bound to database
- **Independence of External Agencies**: Business rules don't know about external interfaces

### Architecture Layers
1. **Presentation Layer**: SwiftUI Views, ViewModels, and UI logic
2. **Domain Layer**: Business entities, use cases, and business rules
3. **Data Layer**: Repositories, data sources, and external service implementations

### Core Design Patterns
- **Dependency Injection**: Service-based architecture with protocol-oriented design
- **Repository Pattern**: Abstract data access with concrete implementations
- **Use Case Pattern**: Business logic encapsulation in single-responsibility classes
- **Observer Pattern**: Reactive state management with Combine framework
- **Factory Pattern**: Object creation and dependency management

## 3. Who is this app for

### Primary Users:
- **Martial Arts Students**: Individuals actively training in martial arts who want to document their learning journey, track their progress through structured curriculum, and receive AI-powered practice recommendations to accelerate their mastery
- **Martial Arts Instructors**: Teachers at the school who need to monitor student progress, grade techniques, provide feedback on student development, and leverage AI insights to enhance their teaching methods
- **The Martial Arts School**: The institution looking to digitize its curriculum, provide structured learning paths for students, and incorporate AI-driven training methodologies

### User Segments:
1. **Free Users**: Martial artists who want to create and track their own custom training programs without accessing school-specific content, but with access to AI practice recommendations
2. **Enrolled Students**: Current students at the martial arts school who have access to their enrolled programs, can purchase additional premium content, and receive personalized AI practice sessions
3. **Paid General Public**: Non-enrolled martial artists who purchase individual courses to learn specific styles or techniques with AI-enhanced learning support
4. **Parents**: Parents of children enrolled at the school who want to monitor their child's progress, communicate with instructors, and support their child's martial arts journey

## 4. Functional Requirements

### Core Features:
- **Digital Journaling**: Text, photo, and video documentation of training sessions and technique learning
- **Curriculum Management**: Structured learning paths organized by rank and style with technique requirements
- **Progress Tracking**: Mark techniques as learned/mastered with visual progress indicators
- **Offline Access**: Full app functionality without internet connection, with intelligent content caching and download management
- **Content Management**: Access to basic program information and premium content (videos, detailed explanations, instructor notes)

### Unified Practice System (NEW)
The app features a unified practice system that combines all practice-related functionality into a cohesive experience:

#### Practice Session Management
- **Session Creation**: Create practice sessions with custom names, durations, and focus areas
- **Item Selection**: Select forms, techniques, and exercises from curriculum or custom content
- **Session Templates**: Pre-built session templates for different training goals (strength, flexibility, technique, etc.)
- **Session Scheduling**: Schedule practice sessions with reminders and notifications

#### Real-Time Practice Tracking
- **Live Session Monitoring**: Track practice duration, intensity, and technique repetitions in real-time
- **Progress Indicators**: Visual feedback showing completion status of each practice item
- **Session Notes**: Add notes and observations during practice sessions
- **Rating System**: Rate difficulty, confidence, and quality for each practiced item

#### AI-Powered Practice Recommendations
- **Intelligent Session Generation**: AI creates personalized practice sessions based on:
  - User's current rank and progress
  - Recent practice history and performance
  - Learning gaps and areas needing improvement
  - Spaced repetition principles for optimal retention
- **Adaptive Recommendations**: AI adjusts recommendations based on user performance and feedback
- **Focus Area Targeting**: Sessions target specific areas (technique, form, conditioning, etc.)
- **Difficulty Progression**: Automatic difficulty adjustment based on mastery level

#### Practice Analytics and Insights
- **Session History**: Complete history of all practice sessions with detailed analytics
- **Progress Visualization**: Charts and graphs showing improvement over time
- **Performance Metrics**: Track consistency, duration, and quality of practice
- **Achievement Tracking**: Unlock achievements based on practice milestones
- **Learning Insights**: AI-generated insights about learning patterns and recommendations

#### Apple Watch Integration
- **Hands-Free Guidance**: Voice prompts and haptic feedback during practice
- **Workout Tracking**: Monitor heart rate, duration, and intensity
- **Quick Actions**: Voice commands for session control and note-taking
- **Real-Time Feedback**: Immediate feedback on technique timing and form

### Content & Communication Features:
- **Content Updates**: Regular delivery of one-off articles, videos, and educational content to keep users engaged
- **Marketing Communications**: Targeted delivery of sales pitches, special offers, and promotional content
- **Push Notifications**: Strategic notifications for new content, special offers, practice reminders, and achievement milestones
- **In-App Messaging**: Direct communication channel for important announcements and updates
- **Announcement Management Interface**: Administrative interface for creating, editing, and managing announcements in Firestore
  - **Announcement Creation**: Form-based interface for creating new announcements with title, description, targeting, and scheduling
  - **Content Targeting**: Advanced targeting options including user types, programs, roles, age ranges, and custom filters
  - **Scheduling System**: Ability to schedule announcements for future publication and set expiration dates
  - **Draft Management**: Save announcements as drafts and preview before publishing
  - **Bulk Operations**: Create multiple announcements and manage them in batches
  - **Analytics Integration**: Track announcement engagement, read rates, and user interactions
  - **Access Control**: Role-based permissions for who can create and manage announcements

- **In-App Purchases & Subscription Management**: Complete monetization system for premium content and subscriptions
  - **Subscription Tiers**: Multiple subscription levels (Basic, Premium, Elite) with different content access
  - **One-Time Purchases**: Individual course and content purchases for specific techniques or programs
  - **Trial Management**: Free trial periods for subscriptions with automatic conversion
  - **Purchase Validation**: Server-side receipt validation and subscription status verification
  - **Restore Purchases**: Allow users to restore previous purchases across devices
  - **Subscription Analytics**: Track conversion rates, churn, and revenue metrics
  - **Promotional Offers**: Discount codes, limited-time offers, and promotional pricing
  - **Family Sharing**: Support for Apple Family Sharing for subscription access
  - **Upgrade/Downgrade**: Seamless subscription tier changes with proration
  - **Cancellation Management**: Easy subscription cancellation with retention offers

### Video Content & Offline Strategy:
- **Smart Video Caching**: Automatic download of essential technique videos when connected to WiFi, with user control over which content to download
- **Progressive Download**: Background download of video content based on user's current curriculum level and learning progress
- **Storage Management**: User controls for managing downloaded content, with automatic cleanup of older/unused videos
- **Quality Options**: Multiple video quality settings for download (standard definition for offline, high definition for streaming)
- **Download Queue**: Background download system that prioritizes content based on user's current learning path
- **Offline Indicators**: Clear visual indicators showing which content is available offline vs. requires internet connection
- **Sync Management**: Intelligent sync system that updates downloaded content when connection is restored

### Gamification Features:
- **Achievement System**: Badges, medals, and rewards for completing techniques, maintaining practice streaks, and reaching milestones
- **Progress Levels**: Visual progression system with ranks, belts, or levels that users can advance through
- **Practice Streaks**: Daily/weekly practice tracking with streak counters and rewards for consistency
- **Challenge System**: Weekly/monthly challenges that encourage specific practice goals and technique mastery
- **Leaderboards**: Optional competitive elements for practice consistency and technique mastery (can be school-wide or personal)
- **Experience Points**: XP system for completing training sessions, mastering techniques, and maintaining practice habits
- **Unlockable Content**: Special content, techniques, or features that unlock as users progress and achieve goals

### User Management:
- **Multi-tier Access Control**: Different content access levels based on user type and subscription
- **Instructor Dashboard**: Tools for grading students, viewing progress, providing feedback, and accessing AI-generated insights about student development
- **Parent Portal**: Dedicated interface for parents to monitor child progress, communicate with instructors, and access school announcements
- **Privacy Controls**: User-generated content remains private unless explicitly shared with instructors or parents

### Content Delivery:
- **Subscription Management**: Both subscription tiers and one-time course purchases
- **Media Support**: Video and image content delivery for technique demonstrations
- **Data Synchronization**: Cloud-based backup and cross-device syncing

## 5. User Stories

### For Students:
- As a martial arts student, I want to journal about my training sessions so I can reflect on what I learned and track my progress over time
- As a student, I want to add photos and videos of my practice so I can review my form and technique later
- As a student, I want to see what techniques I need to learn for my next rank so I can focus my training appropriately
- As a student, I want to mark techniques as learned or mastered so I can visualize my progress through the curriculum
- As a student, I want to access training content offline so I can study and practice anywhere
- As a student, I want to purchase additional course content so I can deepen my understanding of specific techniques
- As a student, I want AI-generated practice sessions so I can optimize my training time and accelerate my skill development
- As a student, I want personalized learning recommendations so I can focus on areas where I need the most improvement
- As a student, I want AI insights about my learning patterns so I can understand my strengths and areas for growth
- As a student, I want to earn achievements and badges so I can feel motivated and rewarded for my progress
- As a student, I want to track my practice streaks so I can maintain consistency and build good habits
- As a student, I want to participate in challenges so I can push myself to improve specific skills
- As a student, I want to unlock special content as I progress so I have additional motivation to continue learning
- As a student, I want to receive updates about new content and special offers so I can stay informed about opportunities to enhance my training
- As a student, I want to download technique videos for offline viewing so I can practice without internet connection
- As a student, I want to control which videos are downloaded so I can manage my device storage effectively
- As a student, I want to see which content is available offline so I can plan my practice sessions accordingly
- As a student, I want automatic download of videos for my current curriculum level so I don't have to manually manage downloads
- As a student, I want hands-free practice guidance on my Apple Watch so I can focus on technique without checking my phone
- As a student, I want haptic feedback for technique timing so I can maintain proper rhythm and flow during practice
- As a student, I want to track my workout metrics during practice so I can monitor my training intensity and duration
- As a student, I want voice commands to start sessions and mark techniques complete so I can keep my hands free during training
- As a student, I want quick voice journaling on my watch so I can capture insights immediately after practice
- As a student, I want real-time progress notifications on my watch so I can stay motivated during training sessions
- As a student, I want emergency features on my watch so I can quickly access help if needed during practice

### Unified Practice System User Stories:
- As a student, I want to create custom practice sessions so I can focus on specific techniques or training goals
- As a student, I want AI to recommend practice sessions based on my progress so I can optimize my training time
- As a student, I want to track my practice performance in real-time so I can monitor my improvement
- As a student, I want to rate my performance on each technique so I can identify areas needing more work
- As a student, I want to see my practice history and analytics so I can understand my learning patterns
- As a student, I want to schedule practice sessions with reminders so I can maintain consistency
- As a student, I want to use practice session templates so I can quickly start focused training
- As a student, I want to add notes during practice so I can capture insights while they're fresh
- As a student, I want to see my practice streaks and achievements so I can stay motivated
- As a student, I want AI insights about my practice patterns so I can improve my training approach

### For Instructors:
- As an instructor, I want to view my students' progress so I can provide targeted guidance and feedback
- As an instructor, I want to grade students on technique mastery so I can track their development
- As an instructor, I want to access student journal entries (when shared) so I can understand their learning journey
- As an instructor, I want to see which students are struggling with specific techniques so I can provide additional support
- As an instructor, I want AI-generated insights about student learning patterns so I can adapt my teaching methods
- As an instructor, I want to see AI practice recommendations for my students so I can understand their training needs
- As an instructor, I want to leverage AI analytics to identify common learning challenges across my student base
- As an instructor, I want to send announcements and updates to my students so I can communicate important information
- As an instructor, I want to create challenges for my students so I can encourage specific training goals
- As an instructor, I want to view student achievement data so I can recognize and reward progress

### For Free Users:
- As a free user, I want to create my own training programs so I can track my learning without being tied to a specific school
- As a free user, I want to document my martial arts journey so I can maintain a personal training record
- As a free user, I want AI practice recommendations so I can optimize my self-directed training
- As a free user, I want to earn achievements and track my progress so I can stay motivated in my training
- As a free user, I want to receive updates about premium content and special offers so I can consider upgrading my experience
- As a free user, I want to try premium features through a free trial so I can evaluate the value before subscribing
- As a free user, I want to purchase individual courses so I can learn specific techniques without a full subscription
- As a free user, I want to see clear pricing and feature comparisons so I can make informed purchase decisions
- As a free user, I want to restore my purchases if I change devices so I don't lose access to content I've bought

### For Paid General Public:
- As a paid user, I want to access premium video content so I can learn advanced techniques with detailed instruction
- As a paid user, I want to download content for offline viewing so I can practice without internet connection
- As a paid user, I want to access exclusive instructor notes and insights so I can deepen my understanding
- As a paid user, I want to participate in premium challenges and competitions so I can test my skills
- As a paid user, I want to upgrade or downgrade my subscription so I can adjust my access level as needed
- As a paid user, I want to manage my subscription settings so I can control billing and access preferences
- As a paid user, I want to access family sharing features so my family members can also use the app
- As a paid user, I want to receive exclusive content and early access to new features so I feel valued as a subscriber
- As a paid user, I want to cancel my subscription easily if needed so I have control over my spending
- As a paid user, I want to restore my purchases across devices so I can access content on any device I own

### For The School:
- As the school, I want to send targeted marketing communications so I can promote courses and special offers
- As the school, I want to publish regular content updates so I can keep students engaged and provide additional value
- As the school, I want to track user engagement and gamification metrics so I can understand what motivates students
- As the school, I want to create challenges and competitions so I can foster a sense of community and motivation
- As the school, I want to use gamification data to identify students who might need additional support or encouragement
- As the school, I want to create and manage announcements through an administrative interface so I can communicate important updates to students and parents
- As the school, I want to target announcements to specific user groups so I can send relevant information to the right audience
- As the school, I want to schedule announcements for future publication so I can plan communications in advance
- As the school, I want to track announcement engagement so I can measure the effectiveness of our communications
- As the school, I want to save announcement drafts so I can work on communications over time before publishing
- As the school, I want to use announcement templates so I can quickly create common types of communications
- As the school, I want to manage multiple announcements in batches so I can efficiently handle bulk communications

### For Parents:
- As a parent, I want to monitor my child's progress so I can support their martial arts development
- As a parent, I want to see what techniques my child is learning so I can help them practice at home
- As a parent, I want to communicate with instructors so I can stay informed about my child's development
- As a parent, I want to receive notifications about my child's achievements so I can celebrate their progress
- As a parent, I want to access school announcements and updates so I can stay informed about events and schedule changes
- As a parent, I want to view my child's practice schedule so I can help them maintain consistency
- As a parent, I want to see my child's gamification progress so I can encourage their engagement and motivation
- As a parent, I want to purchase additional content for my child so I can support their learning beyond regular classes

## 6. User Interface

### Design Principles:
- **Clean, Minimalist Interface**: Focus on content and functionality with martial arts-inspired design elements
- **Intuitive Navigation**: Easy access to journaling, curriculum, progress tracking, and AI practice features
- **Responsive Design**: Optimized for all iOS devices with proper support for different screen sizes
- **Accessibility**: Full support for VoiceOver, Dynamic Type, and other accessibility features

### Key Screens:
- **Dashboard**: Overview of current rank, progress, recent journal entries, upcoming techniques, AI practice recommendations, and gamification elements (achievements, streaks, challenges)
- **Practice Hub**: Centralized practice experience with session creation, AI recommendations, progress tracking, and analytics
- **Learn**: Curriculum browser, technique library, rank progression, and search functionality
- **Journal**: Entry list, editor, media gallery, and search with tags
- **Profile**: User settings, progress analytics, achievements, and subscription management

## 7. Technical Requirements

### Architecture Requirements:
- **Clean Architecture**: Strict separation of concerns with domain, data, and presentation layers
- **Dependency Injection**: Service-based architecture with protocol-oriented design
- **Testability**: All business logic must be unit testable without UI dependencies
- **Modularity**: Feature-based modules for maintainability and scalability
- **Reactive Programming**: Combine framework for state management and data flow

### Performance Requirements:
- **Offline-First**: Core functionality available without internet connection
- **Fast Startup**: App launch time under 2 seconds
- **Smooth Scrolling**: 60fps performance on all list views
- **Efficient Memory Usage**: Proper memory management for video content and large datasets

### Security Requirements:
- **Data Encryption**: End-to-end encryption for sensitive user data
- **Secure Authentication**: Biometric authentication and secure token management
- **Privacy Compliance**: GDPR and CCPA compliance for user data handling
- **Secure Communication**: HTTPS for all network communications

### Quality Requirements:
- **Test Coverage**: Minimum 80% unit test coverage for business logic
- **Code Quality**: SwiftLint compliance and consistent coding standards
- **Documentation**: Comprehensive API documentation and code comments
- **Error Handling**: Graceful error handling with user-friendly messages 