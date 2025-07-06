import Foundation

// MARK: - Environment Configuration
public enum AppEnvironment: String, CaseIterable {
    case development = "development"
    case staging = "staging"
    case production = "production"
    
    /// Current environment based on build configuration
    public static var current: AppEnvironment {
        #if DEBUG
        // Check for staging environment variable or configuration
        if let envString = ProcessInfo.processInfo.environment["APP_ENVIRONMENT"],
           let env = AppEnvironment(rawValue: envString.lowercased()) {
            return env
        }
        return .development
        #else
        // Production builds default to production unless overridden
        if let envString = Bundle.main.object(forInfoDictionaryKey: "APP_ENVIRONMENT") as? String,
           let env = AppEnvironment(rawValue: envString.lowercased()) {
            return env
        }
        return .production
        #endif
    }
    
    /// Display name for the environment
    public var displayName: String {
        switch self {
        case .development:
            return "Development"
        case .staging:
            return "Staging"
        case .production:
            return "Production"
        }
    }
    
    /// Whether this is a debug environment
    public var isDebug: Bool {
        switch self {
        case .development, .staging:
            return true
        case .production:
            return false
        }
    }
    
    /// Whether this environment supports mock services
    public var supportsMockServices: Bool {
        switch self {
        case .development:
            return true
        case .staging, .production:
            return false
        }
    }
    
    /// Whether this environment should use real external services
    public var usesRealServices: Bool {
        switch self {
        case .development:
            return false
        case .staging, .production:
            return true
        }
    }
    
    /// Log level for this environment
    public var logLevel: LogLevel {
        switch self {
        case .development:
            return .verbose
        case .staging:
            return .info
        case .production:
            return .warning
        }
    }
}

// MARK: - Log Level Configuration
public enum LogLevel: Int, CaseIterable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case none = 5
    
    public var displayName: String {
        switch self {
        case .verbose: return "Verbose"
        case .debug: return "Debug"
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        case .none: return "None"
        }
    }
    
    public var emoji: String {
        switch self {
        case .verbose: return "💬"
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .none: return ""
        }
    }
}

// MARK: - Service Configuration
public struct ServiceConfiguration {
    public let baseURL: String
    public let apiKey: String?
    public let timeout: TimeInterval
    public let retryCount: Int
    public let enableLogging: Bool
    
    public init(
        baseURL: String,
        apiKey: String? = nil,
        timeout: TimeInterval = 30.0,
        retryCount: Int = 3,
        enableLogging: Bool = true
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.timeout = timeout
        self.retryCount = retryCount
        self.enableLogging = enableLogging
    }
}

// MARK: - Database Configuration
public struct DatabaseConfiguration {
    public let cloudKitContainer: String
    public let firestoreProject: String
    public let enableCloudKitSync: Bool
    public let enableFirestoreOffline: Bool
    public let cacheSize: Int
    
    public init(
        cloudKitContainer: String,
        firestoreProject: String,
        enableCloudKitSync: Bool = true,
        enableFirestoreOffline: Bool = true,
        cacheSize: Int = 50
    ) {
        self.cloudKitContainer = cloudKitContainer
        self.firestoreProject = firestoreProject
        self.enableCloudKitSync = enableCloudKitSync
        self.enableFirestoreOffline = enableFirestoreOffline
        self.cacheSize = cacheSize
    }
}

// MARK: - Feature Flags
public struct FeatureFlags {
    public let enablePracticeFeature: Bool
    public let enableAIGeneration: Bool
    public let enableAnalytics: Bool
    public let enableCrashReporting: Bool
    public let enableBetaFeatures: Bool
    
    public init(
        enablePracticeFeature: Bool = false,
        enableAIGeneration: Bool = false,
        enableAnalytics: Bool = true,
        enableCrashReporting: Bool = true,
        enableBetaFeatures: Bool = false
    ) {
        self.enablePracticeFeature = enablePracticeFeature
        self.enableAIGeneration = enableAIGeneration
        self.enableAnalytics = enableAnalytics
        self.enableCrashReporting = enableCrashReporting
        self.enableBetaFeatures = enableBetaFeatures
    }
}

// MARK: - Environment Extensions
extension AppEnvironment {
    /// Default service configuration for this environment
    public var defaultServiceConfiguration: ServiceConfiguration {
        switch self {
        case .development:
            return ServiceConfiguration(
                baseURL: "https://dev-api.sakungfujournal.com",
                timeout: 60.0,
                retryCount: 1,
                enableLogging: true
            )
        case .staging:
            return ServiceConfiguration(
                baseURL: "https://staging-api.sakungfujournal.com",
                timeout: 45.0,
                retryCount: 2,
                enableLogging: true
            )
        case .production:
            return ServiceConfiguration(
                baseURL: "https://api.sakungfujournal.com",
                timeout: 30.0,
                retryCount: 3,
                enableLogging: false
            )
        }
    }
    
    /// Default database configuration for this environment
    public var defaultDatabaseConfiguration: DatabaseConfiguration {
        switch self {
        case .development:
            return DatabaseConfiguration(
                cloudKitContainer: "iCloud.com.sakungfujournal.dev",
                firestoreProject: "sakungfujournal-dev",
                enableCloudKitSync: true,
                enableFirestoreOffline: true,
                cacheSize: 20
            )
        case .staging:
            return DatabaseConfiguration(
                cloudKitContainer: "iCloud.com.sakungfujournal.staging",
                firestoreProject: "sakungfujournal-staging",
                enableCloudKitSync: true,
                enableFirestoreOffline: true,
                cacheSize: 30
            )
        case .production:
            return DatabaseConfiguration(
                cloudKitContainer: "iCloud.com.sakungfujournal",
                firestoreProject: "sakungfujournal",
                enableCloudKitSync: true,
                enableFirestoreOffline: true,
                cacheSize: 50
            )
        }
    }
    
    /// Default feature flags for this environment
    public var defaultFeatureFlags: FeatureFlags {
        switch self {
        case .development:
            return FeatureFlags(
                enablePracticeFeature: true,
                enableAIGeneration: true,
                enableAnalytics: false,
                enableCrashReporting: false,
                enableBetaFeatures: true
            )
        case .staging:
            return FeatureFlags(
                enablePracticeFeature: true,
                enableAIGeneration: true,
                enableAnalytics: true,
                enableCrashReporting: true,
                enableBetaFeatures: true
            )
        case .production:
            return FeatureFlags(
                enablePracticeFeature: false, // Will be enabled when ready
                enableAIGeneration: false,     // Will be enabled when ready
                enableAnalytics: true,
                enableCrashReporting: true,
                enableBetaFeatures: false
            )
        }
    }
}