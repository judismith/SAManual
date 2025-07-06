# Unified Practice Feature Specification

## Document Information
**Document Type:** Feature Specification  
**Created:** July 5, 2025  
**Last Updated:** July 5, 2025  
**Status:** Planning Phase  
**Version:** 1.0  

---

## Executive Summary

The Unified Practice Feature transforms the SAKungFuJournal app from a simple curriculum browser into an intelligent practice management system. By combining curriculum viewing with active practice sessions, AI-generated guidance, and personalized scheduling, this feature creates a comprehensive training companion that respects traditional martial arts pedagogy while embracing modern learning tools.

### Key Innovation
Instead of separating "curriculum browsing" from "practice activities," this feature recognizes that students only need to view curriculum content when they're ready to practice it. This unified approach eliminates navigation friction and creates a more natural learning flow.

---

## Business Objectives

### Primary Goals
1. **Increase Student Engagement:** Provide structured, personalized practice guidance
2. **Improve Retention:** Smart scheduling ensures students maintain skills over time
3. **Support Traditional Instruction:** Complement in-person classes, don't replace them
4. **Drive Subscription Revenue:** Premium content access incentivizes upgrades
5. **Enhance Parent Engagement:** Youth program features support family involvement

### Success Metrics
- **Practice Session Completion Rate:** Target 70%+ adherence to scheduled sessions
- **User Engagement:** 4+ sessions per week for active users
- **Subscription Conversion:** 25% of free users upgrade within 3 months
- **Student Progress:** Measurable improvement in rank advancement timing
- **Parent Satisfaction:** 85%+ approval rating for youth program features

---

## User Stories & Personas

### Primary Persona: Adult Student (Sarah, 32, Orange Sash)
**"I want to practice effectively at home between classes"**

**User Stories:**
- As an adult student, I want to see what I should practice today so I can use my limited time effectively
- As a martial artist, I want to review previous techniques so I don't lose skills I've already learned
- As a subscriber, I want access to instructional videos so I can practice correctly at home
- As a test candidate, I want to prepare systematically so I feel confident during rank evaluations

### Secondary Persona: Parent (Mike, 38, parent of 10-year-old student)
**"I want to support my child's martial arts journey"**

**User Stories:**
- As a parent, I want guidance on how to help my child practice so I can be supportive without overstepping
- As a busy parent, I want a structured practice plan so we can make the most of limited practice time
- As a supportive parent, I want to understand what my child is learning so I can celebrate their progress
- As a family, I want practice to be engaging so my child stays motivated

### Tertiary Persona: Instructor (Lisa, 45, Black Sash)
**"I want my students to practice correctly between classes"**

**User Stories:**
- As an instructor, I want full access to all curriculum content so I can prepare lessons and demonstrations
- As a teacher, I want students to practice what I've taught them so they retain material between classes
- As a curriculum designer, I want students to follow proper progression so they don't develop bad habits
- As a martial arts professional, I want to supplement my teaching with quality resources

---

## Functional Requirements

### Core Features

#### 1. Unified Practice Interface
**Description:** Single view that combines curriculum browsing with practice initiation

**Requirements:**
- Replace separate curriculum navigation with integrated practice view
- Display enrolled programs with expandable rank sections
- Show techniques and forms grouped separately under each rank
- Indicate current rank with visual emphasis
- Display progress status for each technique/form (Not Started, Practiced, Mastered)
- Show "Taught in Class" indicators for content covered in instruction

#### 2. Content Access Control
**Description:** Role-based permissions for curriculum content

**Requirements:**
- **Instructors:** Full access to all videos, descriptions, and teaching materials
- **Subscribers:** Access to videos and written descriptions for practice
- **Free Users:** Content structure visible, upgrade prompts for premium content
- **Youth Students:** Same access rules applied through parent account
- Graceful degradation when content is unavailable
- Clear upgrade paths for free users

#### 3. Practice Session Management
**Description:** Structured practice sessions with content tracking

**Requirements:**
- Daily practice sessions with scheduled content
- Manual session creation for custom practice
- Real-time progress tracking during sessions
- Session completion logging with timestamps
- Integration with device calendar for scheduling
- Practice streak tracking and gamification

#### 4. Intelligent Scheduling System
**Description:** AI-driven practice planning with spaced repetition

**Requirements:**
- 4-week cycles with weekly themes (Accuracy, Speed, Flow, Power)
- 5-day or 7-day schedule options based on user preference
- Current form and most recent technique included daily
- Previous material distributed using spaced repetition algorithm
- Content weighting based on recency and mastery level
- Automatic schedule adjustment for rank advancement

#### 5. "Taught in Class" Tracking
**Description:** Student-controlled indicator for content covered in formal instruction

**Requirements:**
- Boolean flag for each technique and form
- Conservative defaults (nothing marked as taught initially)
- Bulk update capability during onboarding
- Easy modification throughout student journey
- Prevents practice of untaught material
- Respects instructor authority over curriculum progression

#### 6. AI-Generated Daily Guidance
**Description:** Personalized practice prompts and motivation

**Requirements:**
- Context-aware daily focus messages
- Integration of weekly themes with personal progress
- Recognition of practice patterns and achievements
- Adaptive content based on practice history
- Fallback to static content when AI unavailable
- Fresh, non-repetitive messaging

#### 7. Parent Communication Mode
**Description:** Youth program features with parent-facing interface

**Requirements:**
- Detect youth program enrollment automatically
- Parent-focused communication and guidance
- Child-appropriate practice suggestions for parents
- Family engagement activities and tips
- Progress reporting suitable for parental review
- Safety and supervision guidance

### Supporting Features

#### 8. Onboarding Flow
**Description:** Initial setup for new practice users

**Requirements:**
- Schedule preference selection (5-day vs 7-day)
- Session duration preferences
- "Taught in Class" calibration for current rank
- First 4-week schedule generation
- Notification and reminder setup
- Existing user skip logic

#### 9. Journal Integration
**Description:** Connection between practice sessions and reflection

**Requirements:**
- Pre-practice reflection prompts
- Post-practice note capture
- Session linking with journal entries
- Progress insight generation from journal data
- AI learning from reflection patterns
- Private storage in user's iCloud account

#### 10. Advanced Algorithms
**Description:** Intelligent features for optimized learning

**Requirements:**
- Mastery decay detection and mitigation
- Personalized content recommendations
- Test preparation intensification
- Learning pattern recognition
- Practice effectiveness analysis
- Continuous algorithm improvement

---

## Technical Requirements

### Data Architecture

#### Practice Session Model
```swift
struct PracticeSession {
    let id: String
    let userId: String
    let programId: String
    let startTime: Date
    let endTime: Date?
    let scheduledContent: [ContentItem]
    let completedContent: [String] // ContentItem IDs
    let weeklyTheme: WeeklyTheme // Accuracy, Speed, Flow, Power
    let sessionType: SessionType // Scheduled, Manual, Test Prep
    let notes: String?
    let journalEntryId: String?
}
```

#### Practice Schedule Model
```swift
struct PracticeSchedule {
    let id: String
    let userId: String
    let programId: String
    let scheduleType: ScheduleType // FiveDay, SevenDay
    let startDate: Date
    let weeks: [WeeklySchedule] // 4-week cycle
    let generationAlgorithm: String
    let isActive: Bool
}

struct WeeklySchedule {
    let weekNumber: Int
    let theme: WeeklyTheme
    let dailySessions: [DailySession]
}
```

#### User Profile Extensions
```swift
// Add to existing UserProfile
struct TechniqueProgress {
    let techniqueId: String
    let status: PracticeStatus // NotStarted, Practiced, Mastered
    let taughtInClass: Bool
    let lastPracticed: Date?
    let practiceCount: Int
}

struct FormProgress {
    let formId: String
    let status: PracticeStatus
    let taughtInClass: Bool
    let lastPracticed: Date?
    let practiceCount: Int
}
```

### Content Access Management
```swift
protocol ContentAccessManager {
    func canAccessVideo(userId: String, contentId: String) -> Bool
    func canAccessDescription(userId: String, contentId: String) -> Bool
    func getAccessLevel(userId: String) -> AccessLevel
    func getUpgradePrompt(for contentType: ContentType) -> UpgradePrompt?
}
```

### AI Integration
```swift
protocol AIContentGenerator {
    func generateDailyFocus(context: PracticeContext) async -> DailyFocusContent
    func generateParentGuidance(context: YouthPracticeContext) async -> ParentGuidanceContent
    func generateMotivationalPrompt(progressData: ProgressData) async -> String
}
```

### Performance Requirements
- **Session Loading:** < 2 seconds for practice session initialization
- **Video Streaming:** Adaptive bitrate with < 5 second start time
- **AI Content Generation:** < 3 seconds for daily focus creation
- **Offline Capability:** Essential content cached for offline practice
- **Battery Efficiency:** Optimized for extended practice sessions

### Security Requirements
- **Data Privacy:** All practice data stored in user's iCloud account
- **Content Protection:** Video URLs secured with time-limited access tokens
- **Youth Protection:** COPPA compliance for users under 13
- **Subscription Validation:** Server-side verification of premium access
- **Content Filtering:** Age-appropriate content delivery

---

## User Experience Design

### Information Architecture

#### Navigation Flow
```
Home Dashboard
└── Practice (Quick Action or Main Menu)
    ├── Program Selection (if multiple programs)
    ├── Today's Practice Session
    │   ├── Daily Focus Message
    │   ├── Scheduled Content
    │   └── Practice Interface
    ├── Current Rank Content
    │   ├── Forms Section
    │   └── Techniques Section
    ├── Previous Ranks (Collapsible)
    └── Future Ranks (Preview Only)
```

#### Content Hierarchy
```
Practice View
├── Daily Session Card
│   ├── Today's Focus (AI-generated)
│   ├── Weekly Theme Context
│   ├── Scheduled Content List
│   └── Start Practice Button
├── Program Overview
│   ├── Progress to Black Sash
│   ├── Current Rank Status
│   └── Content Organization
└── Rank Sections (Expandable)
    ├── Rank Header (Name, Level, Status)
    ├── Forms Subsection
    │   ├── Form List with Status Icons
    │   ├── Media Access (if permitted)
    │   └── Progress Indicators
    └── Techniques Subsection
        ├── Technique List with Status Icons
        ├── Media Access (if permitted)
        └── Progress Indicators
```

### Visual Design Principles

#### Progress Visualization
- **Black Sash Progress Bar:** Primary motivation element
- **Rank Progress Indicators:** Secondary progress for current rank
- **Status Icons:** Clear visual distinction for practice states
- **Access Level Indicators:** Obvious differentiation for content access

#### Content Access Differentiation
- **Available Content:** Full opacity, interactive elements
- **Subscription Required:** Partial opacity with upgrade prompts
- **Not Yet Taught:** Grayed out with instructor guidance message
- **Future Ranks:** Preview styling with lock indicators

#### Youth Program Adaptations
- **Parent-Focused Interface:** Adult-appropriate language and concepts
- **Child Progress Display:** Age-appropriate achievement visualization
- **Family Engagement Cues:** Suggestions for parent participation
- **Safety Emphasis:** Clear supervision and safety reminders

### Interaction Patterns

#### Practice Session Flow
1. **Session Initiation:** Clear call-to-action for daily practice
2. **Content Selection:** Flexibility to modify scheduled content
3. **Practice Interface:** Distraction-free environment with easy media access
4. **Progress Tracking:** Simple status updates during practice
5. **Session Completion:** Satisfaction confirmation and next steps

#### Content Discovery
1. **Expandable Sections:** Progressive disclosure of rank content
2. **Status Filtering:** Option to view only practiced/mastered content
3. **Search Integration:** Quick access to specific techniques or forms
4. **Related Content:** Suggestions based on current practice focus

---

## Business Rules & Logic

### Practice Scheduling Rules

#### Daily Content Selection
1. **Current Form:** Always included in daily practice
2. **Current Technique:** Most recently learned technique always included
3. **Previous Material Distribution:** Evenly distributed across practice days
4. **Recency Weighting:** More recent material appears more frequently
5. **Mastery Consideration:** "Mastered" content included for retention
6. **Time Constraints:** Content adjusted based on session duration preference

#### Weekly Theme Progression
1. **Week 1 - Accuracy:** Focus on precise technique execution
2. **Week 2 - Speed:** Emphasis on tempo and timing
3. **Week 3 - Flow:** Smooth transitions and rhythm
4. **Week 4 - Power:** Force and impact development
5. **Cycle Repetition:** Automatic restart for continuous improvement

#### Schedule Adaptation Rules
1. **Rank Advancement:** Automatic schedule regeneration with new content
2. **Taught Status Changes:** Dynamic content availability updates
3. **Subscription Changes:** Immediate access level adjustments
4. **Attendance Patterns:** Learning from user behavior for optimization

### Content Access Rules

#### Role-Based Permissions
1. **Instructors:** Unlimited access to all content and teaching materials
2. **Premium Subscribers:** Full access to videos and descriptions
3. **Free Users:** Content structure visible, upgrade prompts for media
4. **Youth Students:** Access controlled through parent account settings

#### Progressive Disclosure
1. **Current Rank + Previous:** Full content access for practicing material
2. **Future Ranks:** Rank names and descriptions only, no detailed content
3. **Taught in Class:** Only marked content available for active practice
4. **Subscription Required:** Clear upgrade paths with value demonstration

### Progress Tracking Rules

#### Status Progression
1. **Not Started → Practiced:** Student self-assessment after initial attempt
2. **Practiced → Mastered:** Student confidence in test-ready execution
3. **Mastery Decay:** Automatic downgrade after extended inactivity
4. **Official Advancement:** School-controlled rank progression overrides all

#### Retention Requirements
1. **Previous Material:** Remains accessible for review and practice
2. **Test Preparation:** All previous ranks required for advancement
3. **Skill Maintenance:** Regular review prevents mastery decay
4. **Cumulative Mastery:** Each rank test includes all previous material

---

## Integration Requirements

### Existing System Integration

#### DataService Architecture
- Leverage existing program and enrollment management
- Extend current user profile with practice data
- Maintain clean architecture separation
- Preserve backward compatibility during transition

#### Authentication & Authorization
- Integrate with existing FirebaseAuth system
- Respect current user role and subscription status
- Maintain security standards for content access
- Support parent/child account relationships

#### Media & Content Delivery
- Utilize existing Vimeo integration for video content
- Maintain current content organization structure
- Respect existing access control mechanisms
- Optimize for mobile streaming performance

### External Service Integration

#### AI Content Generation
- **Primary:** OpenAI API for dynamic content creation
- **Fallback:** Static content templates for reliability
- **Privacy:** Process user data according to privacy policy
- **Cost Management:** Implement usage limits and caching

#### Calendar Integration
- **iOS:** EventKit framework for calendar sync
- **Permissions:** Request appropriate calendar access
- **Flexibility:** Optional feature with graceful fallbacks
- **Sync:** Bidirectional updates for schedule changes

#### Push Notifications
- **Practice Reminders:** Configurable timing and frequency
- **Streak Maintenance:** Motivation for consistent practice
- **Achievement Recognition:** Celebrate progress milestones
- **Parent Updates:** Youth program progress notifications

---

## Implementation Strategy

### Development Approach
**Test-Driven Development (TDD)** throughout all phases:
1. Write failing tests that describe desired behavior
2. Implement minimal code to pass tests
3. Refactor for quality while maintaining test coverage
4. Repeat cycle for iterative improvement

### Phased Rollout
1. **Phase 1:** Foundation data models and basic practice view
2. **Phase 2:** Content access control and media integration
3. **Phase 3:** Practice session management and scheduling
4. **Phase 4:** AI content generation and personalization
5. **Phase 5:** Advanced features and optimizations

### Quality Assurance
- **Unit Tests:** 90%+ coverage on business logic
- **Integration Tests:** Critical user workflow validation
- **Performance Tests:** Response time and resource usage benchmarks
- **User Acceptance Testing:** Real-world validation with martial arts students

### Risk Mitigation
- **AI Dependency:** Robust fallback content when API unavailable
- **Performance:** Lazy loading and efficient caching strategies
- **User Adoption:** Gradual rollout with feature flags
- **Content Quality:** Human review of AI-generated guidance

---

## Success Metrics & KPIs

### Engagement Metrics
- **Daily Active Users:** Practice feature usage rate
- **Session Completion Rate:** Percentage of started sessions completed
- **Weekly Practice Frequency:** Average sessions per user per week
- **Content Interaction:** Video views and description access rates

### Learning Effectiveness
- **Practice Consistency:** Adherence to generated schedules
- **Progress Velocity:** Time to complete rank requirements
- **Retention Rates:** Skill maintenance over time
- **Test Preparation:** Readiness assessment accuracy

### Business Impact
- **Subscription Conversion:** Free to premium upgrade rates
- **Revenue Per User:** Increased lifetime value from engaged users
- **Churn Reduction:** Improved retention through practice engagement
- **Parent Satisfaction:** Youth program family engagement scores

### Technical Performance
- **App Performance:** Load times and responsiveness
- **AI Quality:** Relevance and usefulness of generated content
- **System Reliability:** Uptime and error rates
- **User Experience:** Usability testing scores and feedback

---

## Future Enhancements

### Short-Term Opportunities (3-6 months)
- **Social Features:** Practice buddy system and family challenges
- **Advanced Analytics:** Personal practice insights and trend analysis
- **Instructor Dashboard:** Student practice visibility and guidance tools
- **Competition Preparation:** Specialized training for demonstrations and tournaments

### Medium-Term Vision (6-12 months)
- **AR Integration:** Augmented reality for form correction and guidance
- **Motion Tracking:** Camera-based movement analysis and feedback
- **Personalized Coaching:** Machine learning for individualized instruction
- **Community Features:** School-wide challenges and achievement sharing

### Long-Term Innovation (12+ months)
- **Virtual Reality Training:** Immersive practice environments
- **Biometric Integration:** Heart rate and effort monitoring
- **Advanced AI:** Computer vision for technique analysis
- **Global Platform:** Multi-school and style integration

---

## Conclusion

The Unified Practice Feature represents a fundamental evolution in martial arts education technology. By combining traditional pedagogy with modern convenience, this feature creates a practice companion that respects the instructor-student relationship while providing unprecedented support for independent learning.

The key innovation—recognizing that curriculum viewing and practice are the same activity—eliminates artificial barriers and creates a more natural learning flow. Combined with AI-driven personalization and intelligent scheduling, this feature has the potential to significantly improve student outcomes while driving business growth.

Success will be measured not just in technical metrics, but in the real-world impact on student progress, instructor effectiveness, and the preservation and advancement of martial arts traditions in the digital age.

---

*This specification serves as the authoritative reference for the Unified Practice Feature and will be updated as requirements evolve during development.*