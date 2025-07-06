# Achievement Awards System

## Overview

The Achievement Awards System is a gamification feature designed to motivate students, track progress, and celebrate milestones in their martial arts journey. The system automatically detects when students meet achievement criteria and unlocks awards with visual feedback and notifications.

## 🏆 Achievement Categories

### 1. Practice-Based Achievements
Awards earned through consistent practice habits and dedication.

| Achievement ID | Title | Description | Requirements | Icon | Color |
|----------------|-------|-------------|--------------|------|-------|
| `first_practice` | First Practice | Completed your first practice session | Complete 1 practice session | `figure.martial.arts` | Green (#28A745) |
| `daily_streak_7` | Week Warrior | Practiced for 7 consecutive days | Practice for 7 days in a row | `flame.fill` | Red (#DC3545) |
| `daily_streak_30` | Monthly Master | Practiced for 30 consecutive days | Practice for 30 days in a row | `flame.fill` | Orange (#FF6B35) |
| `total_practice_10h` | Dedicated Student | Completed 10 hours of practice | Accumulate 10 hours of practice time | `clock.fill` | Blue (#007BFF) |

### 2. Progress-Based Achievements
Awards earned through mastering forms and techniques.

#### Form Mastery Achievements
| Achievement ID | Title | Description | Requirements | Icon | Color |
|----------------|-------|-------------|--------------|------|-------|
| `first_form` | First Form Mastered | Completed your first form - a major milestone in your journey! | Complete 1 form | `list.bullet.rectangle.fill` | Purple (#6F42C1) |
| `forms_3` | Form Explorer | Mastered 3 forms | Complete 3 forms | `list.bullet.rectangle` | Purple (#6F42C1) |
| `forms_6` | Form Apprentice | Mastered 6 forms | Complete 6 forms | `list.bullet.rectangle` | Purple (#6F42C1) |
| `forms_10` | Form Expert | Mastered 10 forms | Complete 10 forms | `list.bullet.rectangle.fill` | Purple (#6F42C1) |
| `forms_13` | Form Master | Mastered 13 forms - Black Belt Level | Complete 13 forms | `list.bullet.rectangle.fill` | Purple (#6F42C1) |
| `forms_20` | Form Grandmaster | Mastered all 20 forms - Complete Curriculum | Complete all 20 forms | `list.bullet.rectangle.fill` | Purple (#6F42C1) |

#### Technique Mastery Achievements
| Achievement ID | Title | Description | Requirements | Icon | Color |
|----------------|-------|-------------|--------------|------|-------|
| `first_technique` | First Technique | Mastered your first technique | Complete 1 technique | `star.fill` | Gold (#FFC107) |
| `techniques_10` | Technique Apprentice | Mastered 10 techniques | Complete 10 techniques | `star.fill` | Gold (#FFC107) |
| `techniques_20` | Technique Explorer | Mastered 20 techniques | Complete 20 techniques | `star.fill` | Gold (#FFC107) |
| `techniques_35` | Technique Expert | Mastered 35 techniques | Complete 35 techniques | `star.circle.fill` | Gold (#FFC107) |
| `techniques_50` | Technique Master | Mastered 50 techniques | Complete 50 techniques | `star.circle.fill` | Gold (#FFC107) |
| `techniques_72` | Technique Grandmaster | Mastered all 72 techniques - Black Belt Level | Complete all 72 techniques | `star.circle.fill` | Gold (#FFC107) |

### 3. Rank-Based Achievements
Awards earned through rank progression in each program.

| Achievement ID | Title | Description | Requirements | Icon | Color |
|----------------|-------|-------------|--------------|------|-------|
| `rank_white` | White Belt | Achieved White Belt rank | Earn White Belt in any program | `circle.fill` | White (#FFFFFF) |
| `rank_blue` | Blue Belt | Achieved Blue Belt rank | Earn Blue Belt in any program | `circle.fill` | Blue (#007BFF) |
| `rank_gold` | Gold Belt | Achieved Gold Belt rank | Earn Gold Belt in any program | `circle.fill` | Gold (#FFD700) |
| `rank_red` | Red Belt | Achieved Red Belt rank | Earn Red Belt in any program | `circle.fill` | Red (#DC3545) |
| `rank_black` | Black Belt | Achieved Black Belt rank | Earn Black Belt in any program | `circle.fill` | Black (#000000) |

### 4. Social Achievements (Planned)
Awards earned through community engagement and helping others.

| Achievement ID | Title | Description | Requirements | Icon | Color |
|----------------|-------|-------------|--------------|------|-------|
| `help_others_5` | Mentor | Helped 5 other students | Assist 5 different students | `person.2.fill` | Teal (#20C997) |
| `community_events_3` | Community Builder | Participated in 3 community events | Attend 3 community events | `person.3.fill` | Indigo (#6610F2) |

### 5. Special Achievements (Planned)
Unique awards for exceptional accomplishments.

| Achievement ID | Title | Description | Requirements | Icon | Color |
|----------------|-------|-------------|--------------|------|-------|
| `perfect_practice_week` | Perfect Week | Completed all assigned practices in a week | 100% practice completion in a week | `checkmark.circle.fill` | Green (#28A745) |
| `early_bird_30` | Early Bird | Practiced before 7 AM for 30 days | Morning practice for 30 days | `sunrise.fill` | Orange (#FD7E14) |
| `night_owl_30` | Night Owl | Practiced after 9 PM for 30 days | Evening practice for 30 days | `moon.fill` | Purple (#6F42C1) |

## 🔧 Technical Implementation

### Code Architecture

#### 1. AchievementService.swift
The core service that manages achievement logic and data operations.

**Key Components:**
- `AchievementService`: Main service class
- `AchievementDefinition`: Achievement metadata structure
- `AchievementCategory`: Enumeration of achievement types
- `AchievementDefinitions`: Static definitions of all achievements

**Core Methods:**
```swift
// Check for achievements after practice session
func checkPracticeAchievements(userId: String, practiceSession: PracticeSession)

// Check for achievements after progress update
func checkProgressAchievements(userId: String, progress: RankProgressData)

// Unlock an achievement
private func unlockAchievement(userId: String, achievementId: String)

// Instructor functions
func grantAchievement(userId: String, achievementId: String, grantedBy: String)
func revokeAchievement(userId: String, achievementId: String, revokedBy: String)
```

#### 2. AchievementViewModel.swift
Manages UI state and provides data to achievement views.

**Key Features:**
- Achievement filtering and sorting
- Search functionality
- Category-based organization
- Recent achievements tracking

#### 3. Achievement Views
- `AchievementsView`: Main achievements dashboard
- `AchievementDetailView`: Individual achievement details
- `AchievementCardView`: Achievement card component
- `AchievementUnlockAnimationView`: Unlock celebration animation

### Data Flow Process

#### 1. Achievement Checking Process
```
User Action → Service Check → Achievement Unlock → UI Update → Notification
```

**Step-by-step:**
1. **User Action**: Student completes practice session, form, or technique
2. **Service Check**: `AchievementService` checks if criteria are met
3. **Achievement Unlock**: If criteria met, achievement is unlocked in Firestore
4. **UI Update**: Achievement list is refreshed
5. **Notification**: Unlock animation and notification are shown

#### 2. Achievement Storage
- **Firestore Structure**: `users/{userId}/achievements/{achievementId}`
- **Data Fields**:
  - `id`: Achievement identifier
  - `title`: Display title
  - `description`: Achievement description
  - `icon`: SF Symbol icon name
  - `colorHex`: Achievement color
  - `isUnlocked`: Boolean unlock status
  - `unlockedDate`: Timestamp when unlocked

#### 3. Achievement Definitions
All achievements are defined statically in `AchievementDefinitions.all` array, making it easy to:
- Add new achievements
- Modify existing requirements
- Maintain consistency across the app

### Achievement Checking Logic

#### Practice-Based Checks
```swift
func checkPracticeAchievements(userId: String, practiceSession: PracticeSession) {
    checkDailyStreakAchievement(userId: userId)
    checkWeeklyStreakAchievement(userId: userId)
    checkTotalPracticeTimeAchievement(userId: userId)
    checkFirstPracticeAchievement(userId: userId)
}
```

#### Progress-Based Checks
```swift
func checkProgressAchievements(userId: String, progress: RankProgressData) {
    checkFormsCompletionAchievement(userId: userId, completedForms: progress.completedForms.count)
    checkTechniquesCompletionAchievement(userId: userId, completedTechniques: progress.completedTechniques.count)
    checkRankProgressionAchievement(userId: userId, currentRank: progress.currentRank)
}
```

#### Milestone Checking
```swift
private func checkFormsCompletionAchievement(userId: String, completedForms: Int) {
    // Based on 20 total forms: 13 to black + 7 post-black
    let milestones = [3, 6, 10, 13, 20]
    
    for milestone in milestones {
        if completedForms >= milestone {
            let achievementId = "forms_\(milestone)"
            // Check if already unlocked, then unlock if not
        }
    }
}

private func checkTechniquesCompletionAchievement(userId: String, completedTechniques: Int) {
    // Based on 72 techniques to black belt
    let milestones = [10, 20, 35, 50, 72]
    
    for milestone in milestones {
        if completedTechniques >= milestone {
            let achievementId = "techniques_\(milestone)"
            // Check if already unlocked, then unlock if not
        }
    }
}
```

## 🎯 User Experience

### Achievement Discovery
- **Recent Achievements**: Dashboard shows last 5 unlocked achievements
- **Achievement Gallery**: Complete list with filtering and search
- **Progress Indicators**: Visual cues for upcoming achievements

### Unlock Experience
- **Animation**: Celebratory unlock animation
- **Notification**: Push notification for new achievements
- **Sound**: Audio feedback (optional)
- **Haptic Feedback**: Tactile confirmation

### Achievement Display
- **Cards**: Visual achievement cards with icons and colors
- **Details**: Tap to view full achievement information
- **Progress**: Show progress toward next achievement
- **Sharing**: Option to share achievements on social media

## 🔮 Future Enhancements

### Planned Features
1. **Achievement Badges**: Collectible badge system
2. **Achievement Points**: Point-based reward system
3. **Achievement Leaderboards**: Compare with other students
4. **Custom Achievements**: Instructor-created achievements
5. **Achievement Challenges**: Time-limited special achievements

### Advanced Analytics
1. **Achievement Analytics**: Track achievement unlock rates
2. **Engagement Metrics**: Measure achievement impact on retention
3. **A/B Testing**: Test different achievement criteria
4. **Predictive Analytics**: Suggest achievements based on behavior

## 📊 Achievement Statistics

### Current Implementation Status
- ✅ **Practice Achievements**: 4 implemented
- ✅ **Progress Achievements**: 12 implemented (6 forms + 6 techniques)
- ✅ **Rank Achievements**: 5 implemented
- 🔄 **Social Achievements**: 2 planned
- 🔄 **Special Achievements**: 3 planned

### Total Achievements
- **Implemented**: 21 achievements
- **Planned**: 5 additional achievements
- **Total**: 26 achievements across 5 categories

### Curriculum-Based Achievement Design
The achievement milestones are designed around the actual curriculum:

**Forms (20 total)**:
- 1 form: First form mastery (major milestone)
- 3 forms: Early progress milestone
- 6 forms: Quarter curriculum completion
- 10 forms: Half curriculum completion
- 13 forms: Black belt level achievement
- 20 forms: Complete curriculum mastery

**Techniques (72 to black belt)**:
- 1 technique: First technique mastery
- 10 techniques: Early progress milestone
- 20 techniques: Quarter curriculum completion
- 35 techniques: Half curriculum completion
- 50 techniques: Advanced level achievement
- 72 techniques: Black belt level mastery

## 🛠️ Development Guidelines

### Adding New Achievements
1. **Define Achievement**: Add to `AchievementDefinitions.all`
2. **Implement Check Logic**: Add checking method to `AchievementService`
3. **Update UI**: Add to appropriate achievement views
4. **Test**: Verify unlock conditions and UI display

### Achievement Best Practices
1. **Clear Requirements**: Make achievement criteria obvious
2. **Progressive Difficulty**: Start easy, increase challenge
3. **Meaningful Rewards**: Ensure achievements feel valuable
4. **Regular Updates**: Add new achievements periodically
5. **User Feedback**: Gather input on achievement design

### Performance Considerations
1. **Efficient Checking**: Batch achievement checks when possible
2. **Caching**: Cache achievement data locally
3. **Background Processing**: Check achievements in background
4. **Rate Limiting**: Prevent excessive achievement checking

---

*Last Updated: December 2024*  
*System Status: Phase 1 Implementation - Core Features Complete* 