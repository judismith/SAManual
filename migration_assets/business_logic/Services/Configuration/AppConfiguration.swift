import Foundation

// MARK: - App Configuration
public final class AppConfiguration {
    
    // MARK: - Singleton
    public static let shared = AppConfiguration()
    
    // MARK: - Current Configuration
    public static var current: AppConfiguration {
        return shared
    }
    
    // MARK: - Public Properties
    public let environment: AppEnvironment
    public let container: DIContainer
    public let serviceConfiguration: ServiceConfiguration
    public let databaseConfiguration: DatabaseConfiguration
    public let featureFlags: FeatureFlags
    public let logLevel: LogLevel
    
    // MARK: - Private Initialization
    private init() {
        // Detect environment
        self.environment = AppEnvironment.current
        
        // Load configurations based on environment
        self.serviceConfiguration = Self.loadServiceConfiguration(for: environment)
        self.databaseConfiguration = Self.loadDatabaseConfiguration(for: environment)
        self.featureFlags = Self.loadFeatureFlags(for: environment)
        self.logLevel = environment.logLevel
        
        // Initialize DI container
        self.container = DefaultDIContainer()
        
        // Setup dependencies based on environment
        setupDependencies()
        
        // Log initialization
        log("🚀 App initialized with environment: \(environment.displayName)", level: .info)
        if environment.isDebug {
            logConfiguration()
        }
    }
    
    // MARK: - Public Configuration
    public func configure(container: DIContainer) throws {
        // Copy registrations from internal container to the provided container
        // This allows external containers to use our configured services
        try copyServices(from: self.container, to: container)
    }
    
    private func copyServices(from source: DIContainer, to target: DIContainer) throws {
        // Register the same services in the target container
        switch environment {
        case .development:
            try registerDevelopmentServices(in: target)
        case .staging:
            try registerStagingServices(in: target)
        case .production:
            try registerProductionServices(in: target)
        }
        
        // Register ViewModelFactory
        target.registerSingleton(ViewModelFactory.self) { @MainActor in
            ViewModelFactory(container: target)
        }
    }
    
    private func registerDevelopmentServices(in container: DIContainer) throws {
        // Register error handler
        container.registerSingleton(ErrorHandler.self) { @MainActor in
            ErrorHandler(forTesting: true)
        }
        
        // Register mock services for development
        container.registerSingleton(UserService.self) {
            MockUserService()
        }
        
        container.registerSingleton(AuthService.self) {
            MockAuthService()
        }
        
        container.registerSingleton(ProgramService.self) {
            MockProgramService()
        }
        
        container.registerSingleton(MediaService.self) {
            MockMediaService()
        }
        
        container.registerSingleton(JournalService.self) {
            MockJournalService()
        }
        
        container.registerSingleton(SubscriptionService.self) {
            MockSubscriptionService()
        }
    }
    
    private func registerStagingServices(in container: DIContainer) throws {
        // Register error handler
        container.registerSingleton(ErrorHandler.self) { @MainActor in
            ErrorHandler(forTesting: true)
        }
        
        // Register real services for staging
        container.registerSingleton(UserService.self) {
            CloudKitUserService()
        }
        
        container.registerSingleton(AuthService.self) {
            FirebaseAuthService()
        }
        
        container.registerSingleton(ProgramService.self) {
            FirestoreProgramService()
        }
        
        container.registerSingleton(MediaService.self) {
            CloudKitMediaService()
        }
    }
    
    private func registerProductionServices(in container: DIContainer) throws {
        // Register error handler
        container.registerSingleton(ErrorHandler.self) { @MainActor in
            ErrorHandler(forTesting: true)
        }
        
        // Register real services for production
        container.registerSingleton(UserService.self) {
            CloudKitUserService()
        }
        
        container.registerSingleton(AuthService.self) {
            FirebaseAuthService()
        }
        
        container.registerSingleton(ProgramService.self) {
            FirestoreProgramService()
        }
        
        container.registerSingleton(MediaService.self) {
            CloudKitMediaService()
        }
    }
    
    // MARK: - Dependency Setup
    private func setupDependencies() {
        // Register core services
        registerCoreServices()
        
        // Register environment-specific services
        switch environment {
        case .development:
            try? registerDevelopmentServices(in: container)
            if featureFlags.enableBetaFeatures {
                log("🧪 Beta features enabled in development", level: .debug)
            }
        case .staging:
            try? registerStagingServices(in: container)
            log("🔄 Using staging endpoints and configurations", level: .debug)
        case .production:
            try? registerProductionServices(in: container)
            log("🚀 Production services configured", level: .debug)
        }
        
        // Register ViewModelFactory
        container.registerSingleton(ViewModelFactory.self) { @MainActor in
            ViewModelFactory(container: self.container)
        }
    }
    
    
    private func registerCoreServices() {
        // Register AppConfiguration itself
        container.registerInstance(self, for: AppConfiguration.self)
        
        // Register service implementations based on environment
        switch environment {
        case .development:
            registerMockServices()
        case .staging:
            registerStagingServices() 
        case .production:
            registerProductionServices()
        }
        
        log("📦 Core services registered for \(environment.displayName)", level: .debug)
    }
    
    private func registerMockServices() {
        // Register mock implementations for development/testing
        container.registerSingleton(UserService.self) {
            MockUserService()
        }
        
        container.registerSingleton(ProgramService.self) {
            MockProgramService()
        }
        
        container.registerSingleton(MediaService.self) {
            MockMediaService()
        }
        
        container.registerSingleton(AuthService.self) {
            MockAuthService()
        }
        
        log("🧪 Mock services registered for development", level: .debug)
    }
    
    private func registerStagingServices() {
        // Register real implementations with staging endpoints
        
        // Register CloudKitUserService for staging
        container.registerSingleton(UserService.self) {
            CloudKitUserService()
        }
        
        // Register FirebaseAuthService for staging
        container.registerSingleton(AuthService.self) {
            FirebaseAuthService()
        }
        
        // Register FirestoreProgramService for staging
        container.registerSingleton(ProgramService.self) {
            FirestoreProgramService()
        }
        
        // Register CloudKitMediaService for staging
        container.registerSingleton(MediaService.self) {
            CloudKitMediaService()
        }
        
        log("🔄 Real services registered for staging environment", level: .debug)
    }
    
    private func registerProductionServices() {
        // Register real implementations with production endpoints
        
        // Register CloudKitUserService for production
        container.registerSingleton(UserService.self) {
            CloudKitUserService()
        }
        
        // Register FirebaseAuthService for production
        container.registerSingleton(AuthService.self) {
            FirebaseAuthService()
        }
        
        // Register FirestoreProgramService for production
        container.registerSingleton(ProgramService.self) {
            FirestoreProgramService()
        }
        
        // Register CloudKitMediaService for production
        container.registerSingleton(MediaService.self) {
            CloudKitMediaService()
        }
        
        log("🚀 Real services registered for production environment", level: .debug)
    }
    
    // MARK: - Configuration Loading
    private static func loadServiceConfiguration(for environment: AppEnvironment) -> ServiceConfiguration {
        // Check for custom configuration in app bundle
        if let customConfig = loadCustomServiceConfiguration() {
            return customConfig
        }
        
        // Use default configuration for environment
        return environment.defaultServiceConfiguration
    }
    
    private static func loadDatabaseConfiguration(for environment: AppEnvironment) -> DatabaseConfiguration {
        // Check for custom configuration in app bundle
        if let customConfig = loadCustomDatabaseConfiguration() {
            return customConfig
        }
        
        // Use default configuration for environment
        return environment.defaultDatabaseConfiguration
    }
    
    private static func loadFeatureFlags(for environment: AppEnvironment) -> FeatureFlags {
        // Check for custom feature flags in app bundle
        if let customFlags = loadCustomFeatureFlags() {
            return customFlags
        }
        
        // Use default feature flags for environment
        return environment.defaultFeatureFlags
    }
    
    // MARK: - Custom Configuration Loading
    private static func loadCustomServiceConfiguration() -> ServiceConfiguration? {
        guard let path = Bundle.main.path(forResource: "ServiceConfiguration", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            return nil
        }
        
        guard let baseURL = plist["BaseURL"] as? String else {
            return nil
        }
        
        let apiKey = plist["APIKey"] as? String
        let timeout = plist["Timeout"] as? TimeInterval ?? 30.0
        let retryCount = plist["RetryCount"] as? Int ?? 3
        let enableLogging = plist["EnableLogging"] as? Bool ?? true
        
        return ServiceConfiguration(
            baseURL: baseURL,
            apiKey: apiKey,
            timeout: timeout,
            retryCount: retryCount,
            enableLogging: enableLogging
        )
    }
    
    private static func loadCustomDatabaseConfiguration() -> DatabaseConfiguration? {
        guard let path = Bundle.main.path(forResource: "DatabaseConfiguration", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            return nil
        }
        
        guard let cloudKitContainer = plist["CloudKitContainer"] as? String,
              let firestoreProject = plist["FirestoreProject"] as? String else {
            return nil
        }
        
        let enableCloudKitSync = plist["EnableCloudKitSync"] as? Bool ?? true
        let enableFirestoreOffline = plist["EnableFirestoreOffline"] as? Bool ?? true
        let cacheSize = plist["CacheSize"] as? Int ?? 50
        
        return DatabaseConfiguration(
            cloudKitContainer: cloudKitContainer,
            firestoreProject: firestoreProject,
            enableCloudKitSync: enableCloudKitSync,
            enableFirestoreOffline: enableFirestoreOffline,
            cacheSize: cacheSize
        )
    }
    
    private static func loadCustomFeatureFlags() -> FeatureFlags? {
        guard let path = Bundle.main.path(forResource: "FeatureFlags", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            return nil
        }
        
        let enablePracticeFeature = plist["EnablePracticeFeature"] as? Bool ?? false
        let enableAIGeneration = plist["EnableAIGeneration"] as? Bool ?? false
        let enableAnalytics = plist["EnableAnalytics"] as? Bool ?? true
        let enableCrashReporting = plist["EnableCrashReporting"] as? Bool ?? true
        let enableBetaFeatures = plist["EnableBetaFeatures"] as? Bool ?? false
        
        return FeatureFlags(
            enablePracticeFeature: enablePracticeFeature,
            enableAIGeneration: enableAIGeneration,
            enableAnalytics: enableAnalytics,
            enableCrashReporting: enableCrashReporting,
            enableBetaFeatures: enableBetaFeatures
        )
    }
    
    // MARK: - Logging
    private func log(_ message: String, level: LogLevel) {
        guard level.rawValue >= logLevel.rawValue else { return }
        
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        print("\(level.emoji) [\(timestamp)] [CONFIG] \(message)")
    }
    
    private func logConfiguration() {
        log("📋 Configuration Details:", level: .debug)
        log("  Environment: \(environment.displayName)", level: .debug)
        log("  Service Base URL: \(serviceConfiguration.baseURL)", level: .debug)
        log("  CloudKit Container: \(databaseConfiguration.cloudKitContainer)", level: .debug)
        log("  Firestore Project: \(databaseConfiguration.firestoreProject)", level: .debug)
        log("  Practice Feature Enabled: \(featureFlags.enablePracticeFeature)", level: .debug)
        log("  AI Generation Enabled: \(featureFlags.enableAIGeneration)", level: .debug)
        log("  Log Level: \(logLevel.displayName)", level: .debug)
    }
}

// MARK: - Public Configuration Access
extension AppConfiguration {
    /// Check if a feature is enabled
    public func isFeatureEnabled(_ feature: Feature) -> Bool {
        switch feature {
        case .practice:
            return featureFlags.enablePracticeFeature
        case .aiGeneration:
            return featureFlags.enableAIGeneration
        case .analytics:
            return featureFlags.enableAnalytics
        case .crashReporting:
            return featureFlags.enableCrashReporting
        case .betaFeatures:
            return featureFlags.enableBetaFeatures
        }
    }
    
    /// Get service configuration for a specific service
    public func getServiceConfig(for service: ServiceType) -> ServiceConfiguration {
        // For now, return the default service configuration
        // In the future, this could return service-specific configurations
        return serviceConfiguration
    }
    
    /// Update feature flag at runtime (for testing or remote configuration)
    public func updateFeatureFlag(_ feature: Feature, enabled: Bool) {
        // This would require making featureFlags mutable
        // For now, we'll log the request
        log("🔄 Feature flag update requested: \(feature) = \(enabled)", level: .info)
        // TODO: Implement runtime feature flag updates
    }
}

// MARK: - Supporting Enums
public enum Feature {
    case practice
    case aiGeneration
    case analytics
    case crashReporting
    case betaFeatures
}

public enum ServiceType {
    case user
    case program
    case enrollment
    case media
    case auth
    case practice
    case ai
}

// MARK: - Date Formatter Extension
private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Configuration Validation
extension AppConfiguration {
    /// Validate the current configuration
    public func validateConfiguration() -> [ConfigurationError] {
        var errors: [ConfigurationError] = []
        
        // Validate service configuration
        if serviceConfiguration.baseURL.isEmpty {
            errors.append(.invalidServiceConfiguration("Base URL cannot be empty"))
        }
        
        if let url = URL(string: serviceConfiguration.baseURL), !url.isValid {
            errors.append(.invalidServiceConfiguration("Base URL is not a valid URL"))
        } else if URL(string: serviceConfiguration.baseURL) == nil {
            errors.append(.invalidServiceConfiguration("Base URL is not a valid URL"))
        }
        
        // Validate database configuration
        if databaseConfiguration.cloudKitContainer.isEmpty {
            errors.append(.invalidDatabaseConfiguration("CloudKit container cannot be empty"))
        }
        
        if databaseConfiguration.firestoreProject.isEmpty {
            errors.append(.invalidDatabaseConfiguration("Firestore project cannot be empty"))
        }
        
        // Validate feature flag combinations
        if featureFlags.enablePracticeFeature && !featureFlags.enableAnalytics && environment == .production {
            errors.append(.invalidFeatureFlagConfiguration("Practice feature requires analytics in production"))
        }
        
        return errors
    }
}

// MARK: - Configuration Errors
public enum ConfigurationError: Error, LocalizedError {
    case invalidServiceConfiguration(String)
    case invalidDatabaseConfiguration(String)
    case invalidFeatureFlagConfiguration(String)
    case missingRequiredConfiguration(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidServiceConfiguration(let message):
            return "Invalid service configuration: \(message)"
        case .invalidDatabaseConfiguration(let message):
            return "Invalid database configuration: \(message)"
        case .invalidFeatureFlagConfiguration(let message):
            return "Invalid feature flag configuration: \(message)"
        case .missingRequiredConfiguration(let message):
            return "Missing required configuration: \(message)"
        }
    }
}

// MARK: - URL Validation Extension
private extension URL {
    var isValid: Bool {
        return scheme != nil && host != nil
    }
}