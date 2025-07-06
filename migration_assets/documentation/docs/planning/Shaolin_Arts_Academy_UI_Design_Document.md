# Shaolin Arts Academy - User Interface Design Document

## Layout Structure

### Adaptive Dashboard System
- **Role-Based Layouts**: Different dashboard configurations for students, parents, instructors, and free users
- **Modular Widget System**: Customizable dashboard with draggable widgets for personalized experience
- **Context-Aware Navigation**: Smart navigation that highlights relevant features based on user type and current activity
- **Multi-Panel Interface**: Expandable panels for complex tasks like technique comparison and progress analysis

### Primary Navigation Structure
- **Bottom Tab Bar**: 5 main sections (Dashboard, Learn, Practice, Journal, Profile) with role-specific content
- **Floating Action Menu**: Context-sensitive quick actions that adapt to current screen and user type
- **Side Panel Navigation**: Detailed navigation drawer for comprehensive feature access
- **Smart Breadcrumbs**: Contextual navigation path showing current location and quick return options

### Screen Hierarchy
- **Dashboard**: Adaptive home screen with personalized widgets and content
- **Learn Section**: Curriculum browser with rank-based progression and technique library
- **Practice Section**: AI-powered practice sessions, challenges, and workout tracking
- **Journal Section**: Timeline-based journaling with rich media support
- **Profile Section**: User settings, progress visualization, and account management

## Core Components

### Adaptive Dashboard Widgets
- **Progress Overview**: Visual rank progression with next milestone indicators
- **Recent Activity**: Timeline of recent practice sessions, achievements, and journal entries
- **Quick Actions**: Context-sensitive action buttons for common tasks
- **Content Recommendations**: AI-curated suggestions for techniques and practice sessions
- **Achievement Showcase**: Recent badges and unlockable content preview
- **Communication Center**: Messages, announcements, and instructor communications

### Smart Content Components
- **Technique Cards**: Expandable cards showing technique details, progress, and related content
- **Progress Visualizations**: Interactive charts and graphs for learning analytics
- **Media Players**: Optimized video players with offline support and quality controls
- **Journal Entry Editor**: Rich text editor with photo/video integration and technique tagging
- **Practice Session Interface**: Step-by-step guidance with timing cues and progress tracking

### Role-Specific Components
- **Student Components**: Learning path visualization, practice tracking, achievement system
- **Parent Components**: Child progress monitoring, instructor communication, practice support tools
- **Instructor Components**: Student management, grading interface, analytics dashboard
- **Free User Components**: Custom program creation, basic tracking, upgrade prompts

## Interaction Patterns

### Adaptive Interactions
- **Smart Gestures**: Context-aware swipe and tap gestures that adapt to current content
- **Voice Commands**: Hands-free interaction for journaling and practice session control
- **Haptic Feedback**: Tactile responses for achievements, completions, and important actions
- **Progressive Disclosure**: Information revealed progressively based on user interaction level

### Navigation Patterns
- **Breadcrumb Navigation**: Clear path indication with quick return options
- **Deep Linking**: Direct access to specific techniques, journal entries, or practice sessions
- **Smart Search**: Intelligent search with filters, suggestions, and recent searches
- **Contextual Shortcuts**: Shortcuts that appear based on usage patterns and current activity

### Content Interaction
- **Drag and Drop**: Widget customization and content organization
- **Long Press Actions**: Context menus for additional options and quick actions
- **Pull to Refresh**: Content updates with visual feedback
- **Swipe Actions**: Quick actions like mark complete, favorite, or share

## Visual Design Elements & Color Scheme

### Primary Color Palette
- **Forest Green (#22543d)**: Primary brand color representing growth, learning, and tradition
- **Warm Orange (#dd6b20)**: Secondary color for energy, motivation, and achievements
- **Purple (#553c9a)**: Accent color for premium features and special content
- **Charcoal Gray (#2d3748)**: Text and structural elements
- **Light Gray (#e2e8f0)**: Backgrounds and subtle elements

### Dark Mode Color Palette
- **Dark Background (#0f1419)**: Primary dark background for main surfaces
- **Dark Surface (#1a202c)**: Secondary dark background for cards and elevated surfaces
- **Dark Border (#2d3748)**: Subtle borders and dividers in dark mode
- **Light Text (#f7fafc)**: Primary text color for dark mode
- **Muted Text (#a0aec0)**: Secondary text color for less important information
- **Forest Green Dark (#1a4731)**: Darker variant of primary green for dark mode
- **Warm Orange Dark (#c05621)**: Darker variant of orange for dark mode
- **Purple Dark (#44337a)**: Darker variant of purple for dark mode

### Color System Implementation
- **Semantic Color Usage**: Colors assigned to specific UI purposes rather than fixed elements
- **Automatic Adaptation**: Colors automatically switch based on system dark mode preference
- **Manual Override**: User option to override system preference with app-specific setting
- **Consistent Contrast**: All color combinations maintain WCAG AA accessibility standards in both modes

### Visual Elements
- **Subtle Gradients**: Soft gradients for depth and visual interest
- **Rounded Corners**: Consistent 12px border radius for modern, friendly feel
- **Soft Shadows**: Layered shadows for depth and hierarchy
- **Dynamic Patterns**: Subtle background patterns that adapt to user preferences
- **Icon System**: Consistent iconography with martial arts-inspired elements

### Dark Mode Visual Elements
- **Reduced Shadows**: Minimal shadow usage in dark mode to avoid visual noise
- **Subtle Glows**: Soft glows around interactive elements instead of harsh shadows
- **Pattern Adaptation**: Background patterns adjusted for dark mode visibility
- **Icon Contrast**: Icons optimized for dark backgrounds with proper contrast ratios

### State Indicators
- **Progress States**: Visual indicators for incomplete, in-progress, and mastered techniques
- **Achievement States**: Animated badges and unlock sequences
- **Connection States**: Clear indicators for online/offline content availability
- **Loading States**: Smooth loading animations and skeleton screens

### Dark Mode State Indicators
- **Progress States Dark**: Adjusted colors for progress indicators in dark mode
- **Achievement Glow**: Subtle glow effects for achievements in dark mode
- **Connection Indicators**: High-contrast indicators for connection status
- **Loading Skeletons**: Dark mode optimized skeleton screens with proper contrast

## Mobile, Web App, Desktop Considerations

### iOS App (Primary Platform)
- **Native iOS Patterns**: Follow iOS Human Interface Guidelines for familiarity
- **Safe Area Compliance**: Proper handling of notches, dynamic island, and home indicators
- **Gesture Support**: Full support for iOS gestures including back swipe and home indicator
- **Haptic Integration**: Comprehensive haptic feedback for all interactions
- **Background Processing**: Efficient background sync and content updates
- **Dark Mode Support**: Full support for iOS Dark Mode with automatic system preference detection
- **Dynamic Color Adaptation**: Colors automatically adapt to light/dark mode changes
- **Status Bar Adaptation**: Proper status bar styling for both light and dark modes

### Apple Watch Companion
- **Glanceable Interface**: Simplified, quick-access design for small screen
- **Haptic Cues**: Tactile feedback for practice timing and notifications
- **Voice Integration**: Voice commands for hands-free operation
- **Offline Functionality**: Core features available without iPhone connection
- **Battery Optimization**: Efficient power usage for extended training sessions
- **Dark Mode Adaptation**: Watch face and app interface adapt to system dark mode
- **Always-On Display**: Optimized interface for always-on display in both light and dark modes
- **Complication Support**: Dark mode compatible complications for quick access

### Responsive Design Principles
- **Adaptive Layouts**: Flexible layouts that work across all iOS device sizes
- **Content Scaling**: Text and media that scale appropriately for different screens
- **Touch Targets**: Minimum 44pt touch targets for accessibility
- **Orientation Support**: Proper handling of portrait and landscape orientations

## Typography

### Font Hierarchy
- **Primary Font**: SF Pro Display for headings and important text
- **Secondary Font**: SF Pro Text for body text and descriptions
- **Monospace Font**: SF Mono for code, timestamps, and technical content

### Type Scale
- **Large Headings**: 34pt for main section titles
- **Medium Headings**: 28pt for subsection titles
- **Small Headings**: 22pt for card titles and navigation
- **Body Text**: 17pt for primary content
- **Caption Text**: 15pt for secondary information
- **Small Text**: 13pt for metadata and fine details

### Typography Principles
- **Dynamic Type Support**: Full support for iOS Dynamic Type accessibility feature
- **Line Height**: Generous line spacing (1.4x) for readability
- **Contrast Ratios**: WCAG AA compliant contrast ratios for accessibility
- **Text Hierarchy**: Clear visual hierarchy through size, weight, and color

## Accessibility

### Visual Accessibility
- **High Contrast Mode**: Full support for iOS High Contrast mode
- **Reduced Motion**: Respect user preferences for motion sensitivity
- **Color Blind Support**: Color combinations that work for all types of color blindness
- **Large Text Support**: Proper scaling for large accessibility text sizes
- **Dark Mode Accessibility**: All accessibility features work properly in dark mode
- **Contrast Verification**: Automated testing to ensure contrast ratios meet standards in both modes

### Motor Accessibility
- **Voice Control**: Full compatibility with iOS Voice Control
- **Switch Control**: Support for external switch devices
- **Touch Accommodations**: Respect user touch accommodation settings
- **Keyboard Navigation**: Full keyboard navigation support for external keyboards

### Cognitive Accessibility
- **Clear Navigation**: Consistent, predictable navigation patterns
- **Simple Language**: Clear, concise text without jargon
- **Error Prevention**: Smart defaults and confirmation for destructive actions
- **Help System**: Contextual help and guidance throughout the app

### Screen Reader Support
- **VoiceOver Optimization**: Comprehensive VoiceOver support with proper labels
- **Semantic Markup**: Proper semantic structure for screen readers
- **Alternative Text**: Descriptive alt text for all images and media
- **Focus Management**: Logical focus order and clear focus indicators 