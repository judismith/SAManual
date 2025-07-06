import Foundation
import Combine
import SwiftUI

// MARK: - Announcements State
struct AnnouncementsState: LoadingState, ErrorState {
    var announcements: [MediaItem] = []
    var accessibleAnnouncements: [MediaItem] = []
    var readAnnouncementIds: Set<String> = []
    var isLoading = false
    var errorMessage: String?
    
    // Computed properties
    var unreadCount: Int {
        return accessibleAnnouncements.filter { !readAnnouncementIds.contains($0.id) }.count
    }
    
    var hasAnnouncements: Bool {
        return !accessibleAnnouncements.isEmpty
    }
    
    var recentAnnouncements: [MediaItem] {
        let calendar = Calendar.current
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        
        return accessibleAnnouncements.filter { announcement in
            announcement.uploadedAt >= twoDaysAgo
        }
    }
}

// MARK: - Announcements ViewModel (New Architecture)
@MainActor
class AnnouncementsViewModel: BaseViewModel<AnnouncementsState> {
    
    // MARK: - Dependencies (Injected)
    private let mediaService: MediaService
    private let userService: UserService
    private let authService: AuthService
    
    // MARK: - Publishers and Timers
    // Note: Using inherited cancellables from BaseViewModel
    private var backgroundRefreshTimer: Timer?
    private var lastRefreshTime: Date = Date.distantPast
    
    // Background refresh configuration
    private let refreshInterval: TimeInterval = 15 * 60 // 15 minutes
    private let minimumRefreshInterval: TimeInterval = 5 * 60 // 5 minutes minimum between refreshes
    
    // MARK: - Initialization
    init(
        mediaService: MediaService,
        userService: UserService,
        authService: AuthService,
        errorHandler: ErrorHandler
    ) {
        self.mediaService = mediaService
        self.userService = userService
        self.authService = authService
        
        let initialState = AnnouncementsState()
        super.init(initialState: initialState, errorHandler: errorHandler)
        
        setupPublishers()
        setupAppStateObservers()
        loadReadAnnouncements()
        startBackgroundRefresh()
    }
    
    deinit {
        backgroundRefreshTimer?.invalidate()
        backgroundRefreshTimer = nil
    }
    
    // MARK: - Public Methods
    
    /// Load announcements from the media service
    func loadAnnouncements() async {
        // Prevent too frequent refreshes
        let now = Date()
        if now.timeIntervalSince(lastRefreshTime) < minimumRefreshInterval && !state.announcements.isEmpty {
            print("⏱️ [AnnouncementsViewModel] Skipping refresh - too soon since last refresh")
            return
        }
        
        await withErrorHandling("Loading announcements") {
            state.isLoading = true
            lastRefreshTime = now
            
            // Search for announcement-type media
            let announcementMedia = try await mediaService.searchMedia(
                query: "announcement",
                filters: MediaSearchFilters()
            )
            
            // Get current user for access filtering
            let currentUser = try await userService.getCurrentUser()
            
            // Filter announcements based on access level
            let accessibleAnnouncements = filterAccessibleAnnouncements(
                announcements: announcementMedia,
                userAccessLevel: currentUser?.accessLevel ?? .free
            )
            
            // Sort by upload date (newest first)
            let sortedAnnouncements = accessibleAnnouncements.sorted { $0.uploadedAt > $1.uploadedAt }
            
            // Update state
            state.announcements = announcementMedia
            state.accessibleAnnouncements = sortedAnnouncements
            state.isLoading = false
            
            print("✅ [AnnouncementsViewModel] Loaded \(sortedAnnouncements.count) accessible announcements")
        }
    }
    
    /// Mark an announcement as read
    func markAsRead(_ announcementId: String) {
        guard !state.readAnnouncementIds.contains(announcementId) else { return }
        
        state.readAnnouncementIds.insert(announcementId)
        saveReadAnnouncements()
        
        // Record media access event
        Task {
            try? await mediaService.recordMediaAccess(
                mediaId: announcementId,
                eventType: .view,
                userId: getCurrentUserId()
            )
        }
    }
    
    /// Mark all announcements as read
    func markAllAsRead() {
        let allIds = Set(state.accessibleAnnouncements.map { $0.id })
        state.readAnnouncementIds.formUnion(allIds)
        saveReadAnnouncements()
    }
    
    /// Check if an announcement is read
    func isRead(_ announcementId: String) -> Bool {
        return state.readAnnouncementIds.contains(announcementId)
    }
    
    /// Get announcement URL for viewing (handles caching and streaming)
    func getAnnouncementURL(id: String) async -> URL? {
        // Try cached first
        if let cachedURL = mediaService.getCachedMediaURL(id: id) {
            return cachedURL
        }
        
        // Get media item to check type
        guard let mediaItem = await withErrorHandling("Getting media item", block: {
            return try await mediaService.getMediaItem(id: id)
        }) else { return nil }
        
        return await withErrorHandling("Getting announcement URL", block: {
            switch mediaItem.type {
            case .video:
                // Use streaming URL for videos with appropriate quality
                return try await mediaService.getStreamingURL(for: id, quality: .medium)
            case .image, .document, .audio:
                // Use regular URL for non-video content
                return try await mediaService.getMediaURL(id: id)
            }
        })
    }
    
    /// Download announcement for offline viewing (only when explicitly requested)
    func downloadAnnouncementForOffline(id: String) async -> Data? {
        return await withErrorHandling("Downloading announcement for offline", block: {
            return try await mediaService.downloadMedia(id: id)
        })
    }
    
    /// Refresh announcements (forced refresh)
    func refresh() async {
        lastRefreshTime = Date.distantPast // Reset to force refresh
        await loadAnnouncements()
    }
    
    /// Get announcements by priority (if metadata supports it)
    func getHighPriorityAnnouncements() -> [MediaItem] {
        return state.accessibleAnnouncements.filter { announcement in
            // Check if announcement has high priority in metadata
            announcement.metadata.tags?.contains("priority") ?? false ||
            announcement.metadata.tags?.contains("urgent") ?? false
        }
    }
    
    /// Get announcements from last N days
    func getRecentAnnouncements(days: Int = 7) -> [MediaItem] {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        return state.accessibleAnnouncements.filter { announcement in
            announcement.uploadedAt >= cutoffDate
        }
    }
    
    // MARK: - Private Methods
    
    private func setupPublishers() {
        // Listen to media updates for new announcements
        mediaService.mediaUpdatesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedMedia in
                self?.handleMediaUpdate(updatedMedia)
            }
            .store(in: &cancellables)
        
        // Listen to auth state changes
        authService.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authState in
                self?.handleAuthStateChange(authState)
            }
            .store(in: &cancellables)
        
        // Listen to user updates (for access level changes)
        userService.userUpdatesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedUser in
                self?.handleUserUpdate(updatedUser)
            }
            .store(in: &cancellables)
    }
    
    private func setupAppStateObservers() {
        // Monitor app state changes
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppWillResignActive()
            }
            .store(in: &cancellables)
    }
    
    private func handleAppDidBecomeActive() {
        print("📱 [AnnouncementsViewModel] App became active - checking for new announcements")
        Task {
            await loadAnnouncements()
        }
        startBackgroundRefresh()
    }
    
    private func handleAppWillResignActive() {
        print("📱 [AnnouncementsViewModel] App will resign active - stopping background refresh")
        stopBackgroundRefresh()
    }
    
    private func startBackgroundRefresh() {
        stopBackgroundRefresh() // Stop any existing timer
        
        backgroundRefreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            print("⏰ [AnnouncementsViewModel] Background refresh triggered")
            Task { @MainActor in
                await self?.loadAnnouncements()
            }
        }
        
        print("🔄 [AnnouncementsViewModel] Background refresh started (interval: \(refreshInterval/60) minutes)")
    }
    
    private func stopBackgroundRefresh() {
        backgroundRefreshTimer?.invalidate()
        backgroundRefreshTimer = nil
        print("⏹️ [AnnouncementsViewModel] Background refresh stopped")
    }
    
    private func handleMediaUpdate(_ media: MediaItem) {
        // Check if this is an announcement-type media
        if isAnnouncementMedia(media) {
            // Add or update in announcements list
            if let index = state.announcements.firstIndex(where: { $0.id == media.id }) {
                state.announcements[index] = media
            } else {
                state.announcements.append(media)
            }
            
            // Update accessible announcements
            updateAccessibleAnnouncements()
        }
    }
    
    private func handleAuthStateChange(_ authState: AuthState) {
        switch authState {
        case .unauthenticated:
            // Clear user-specific data but keep public announcements
            state.readAnnouncementIds = []
            updateAccessibleAnnouncements()
            
        case .authenticated:
            // Reload announcements for authenticated user
            Task {
                await loadAnnouncements()
            }
        }
    }
    
    private func handleUserUpdate(_ user: UserProfile) {
        // Update accessible announcements based on new access level
        updateAccessibleAnnouncements()
    }
    
    private func updateAccessibleAnnouncements() {
        let currentUserAccessLevel = getCurrentUserAccessLevel()
        state.accessibleAnnouncements = filterAccessibleAnnouncements(
            announcements: state.announcements,
            userAccessLevel: currentUserAccessLevel
        ).sorted { $0.uploadedAt > $1.uploadedAt }
    }
    
    private func filterAccessibleAnnouncements(announcements: [MediaItem], userAccessLevel: AccessLevel) -> [MediaItem] {
        return announcements.filter { announcement in
            canUserAccessAnnouncement(announcement, userAccessLevel: userAccessLevel)
        }
    }
    
    private func canUserAccessAnnouncement(_ announcement: MediaItem, userAccessLevel: AccessLevel) -> Bool {
        switch announcement.accessLevel {
        case .public:
            return true
        case .authenticated:
            return userAccessLevel != .free // Any authenticated user
        case .restricted:
            return userAccessLevel == .subscriber || userAccessLevel == .instructor || userAccessLevel == .admin
        case .private:
            return userAccessLevel == .instructor || userAccessLevel == .admin
        }
    }
    
    private func isAnnouncementMedia(_ media: MediaItem) -> Bool {
        // Check if media is categorized as announcement
        return media.metadata.category?.lowercased() == "announcement" ||
               media.metadata.tags?.contains("announcement") == true ||
               media.filename.lowercased().contains("announcement")
    }
    
    private func getCurrentUserAccessLevel() -> AccessLevel {
        // This would get from current user or auth service
        // For now, return a default
        return .free
    }
    
    private func getCurrentUserId() -> String {
        // This would get from auth service
        return "current-user-id"
    }
    
    // MARK: - Persistence
    
    private func loadReadAnnouncements() {
        let readIds = UserDefaults.standard.stringArray(forKey: "readAnnouncementIds") ?? []
        state.readAnnouncementIds = Set(readIds)
    }
    
    private func saveReadAnnouncements() {
        let readIds = Array(state.readAnnouncementIds)
        UserDefaults.standard.set(readIds, forKey: "readAnnouncementIds")
    }
    
    // MARK: - Error Handling
    
    private func withErrorHandling<T>(_ operation: String, _ block: () async throws -> T) async -> T? {
        do {
            return try await block()
        } catch {
            await handleError(error, context: operation)
            return nil
        }
    }
    
    private func handleError(_ error: Error, context: String) async {
        let handledError = errorHandler.handle(error, context: context)
        state.errorMessage = handledError.userMessage
        state.isLoading = false
        print("❌ [AnnouncementsViewModel] Error in \(context): \(handledError.userMessage)")
    }
}

// MARK: - Media Service Extension for Access Events
extension MediaService {
    func recordMediaAccess(mediaId: String, eventType: AccessEventType, userId: String) async throws {
        // This would be implemented in the actual MediaService
        // For now, it's a placeholder
    }
}