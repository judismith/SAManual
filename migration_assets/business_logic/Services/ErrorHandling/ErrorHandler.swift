import Foundation
import SwiftUI

// MARK: - Error Handler
@MainActor
public final class ErrorHandler: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var currentError: AppError?
    @Published public var showingError = false
    @Published public var errorHistory: [ErrorEvent] = []
    
    // MARK: - Private Properties
    private let maxHistoryCount = 50
    private let retryManager = ErrorRetryManager()
    
    // MARK: - Singleton
    public static let shared = ErrorHandler()
    
    private init() {}
    
    // MARK: - Public Initializer for Testing
    public init(forTesting: Bool) {
        // Allow public initialization for testing purposes
    }
    
    // MARK: - Error Handling
    public func handle(_ error: Error, context: ErrorContext? = nil) {
        let appError = convertToAppError(error)
        let errorEvent = ErrorEvent(
            error: appError,
            context: context,
            timestamp: Date()
        )
        
        // Add to history
        addToHistory(errorEvent)
        
        // Log the error
        logError(errorEvent)
        
        // Update UI state
        currentError = appError
        showingError = true
        
        // Send analytics if enabled
        trackError(errorEvent)
        
        // Handle retry logic
        if appError.isRetryable, let context = context {
            retryManager.scheduleRetry(for: errorEvent, context: context)
        }
    }
    
    public func handleSilently(_ error: Error, context: ErrorContext? = nil) {
        let appError = convertToAppError(error)
        let errorEvent = ErrorEvent(
            error: appError,
            context: context,
            timestamp: Date()
        )
        
        // Add to history but don't show UI
        addToHistory(errorEvent)
        
        // Log the error
        logError(errorEvent)
        
        // Send analytics if enabled
        trackError(errorEvent)
    }
    
    public func clearError() {
        currentError = nil
        showingError = false
    }
    
    public func clearHistory() {
        errorHistory.removeAll()
    }
    
    // MARK: - Error Conversion
    private func convertToAppError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        // Convert common system errors to AppError
        if let nsError = error as NSError? {
            switch nsError.domain {
            case NSURLErrorDomain:
                return convertURLError(nsError)
            case "CKErrorDomain":
                return convertCloudKitError(nsError)
            case "FIRFirestoreErrorDomain":
                return convertFirestoreError(nsError)
            default:
                return .unknown(underlying: error)
            }
        }
        
        return .unknown(underlying: error)
    }
    
    private func convertURLError(_ error: NSError) -> AppError {
        switch error.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            return .networkUnavailable
        case NSURLErrorTimedOut:
            return .requestTimeout
        case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
            return .serverError(code: error.code, message: error.localizedDescription)
        default:
            return .networkError(underlying: error)
        }
    }
    
    private func convertCloudKitError(_ error: NSError) -> AppError {
        switch error.code {
        case 1: // CKErrorInternalError
            return .cloudKitUnavailable
        case 9: // CKErrorNotAuthenticated
            return .cloudKitAccountNotFound
        case 11: // CKErrorPermissionFailure
            return .cloudKitPermissionDenied
        case 25: // CKErrorQuotaExceeded
            return .cloudKitQuotaExceeded
        default:
            return .cloudKitSyncFailed(reason: error.localizedDescription)
        }
    }
    
    private func convertFirestoreError(_ error: NSError) -> AppError {
        switch error.code {
        case 7: // PermissionDenied
            return .firestorePermissionDenied
        case 8: // ResourceExhausted
            return .firestoreQuotaExceeded
        case 14: // Unavailable
            return .firestoreUnavailable
        default:
            return .firestoreOperationFailed(reason: error.localizedDescription)
        }
    }
    
    // MARK: - History Management
    private func addToHistory(_ errorEvent: ErrorEvent) {
        errorHistory.insert(errorEvent, at: 0)
        
        // Trim history if it gets too long
        if errorHistory.count > maxHistoryCount {
            errorHistory = Array(errorHistory.prefix(maxHistoryCount))
        }
    }
    
    // MARK: - Logging
    private func logError(_ errorEvent: ErrorEvent) {
        let config = AppConfiguration.shared
        guard config.environment.isDebug || errorEvent.error.severity.rawValue >= 3 else {
            return
        }
        
        let timestamp = DateFormatter.errorLogFormatter.string(from: errorEvent.timestamp)
        let category = errorEvent.error.category.rawValue
        let severity = errorEvent.error.severity.emoji
        let contextInfo = errorEvent.context?.description ?? "No context"
        
        print("\(severity) [\(timestamp)] [\(category)] \(errorEvent.error.localizedDescription)")
        print("   Context: \(contextInfo)")
        
        if config.environment.isDebug {
            print("   Stack: \(Thread.callStackSymbols.prefix(5).joined(separator: "\n          "))")
        }
    }
    
    // MARK: - Analytics
    private func trackError(_ errorEvent: ErrorEvent) {
        let config = AppConfiguration.shared
        guard config.featureFlags.enableAnalytics else { return }
        
        // TODO: Implement analytics tracking
        // For now, just log that we would track
        if config.environment.isDebug {
            print("📊 [ANALYTICS] Would track error: \(errorEvent.error.category.rawValue)")
        }
    }
    
    // MARK: - Recovery Actions
    public func getRecoveryActions(for error: AppError) -> [ErrorRecoveryAction] {
        var actions: [ErrorRecoveryAction] = []
        
        // Always provide dismiss action
        actions.append(.dismiss)
        
        // Add retry action if error is retryable
        if error.isRetryable {
            actions.append(.retry)
        }
        
        // Add specific actions based on error type
        switch error {
        case .networkUnavailable:
            actions.append(.checkConnection)
        case .tokenExpired, .invalidCredentials:
            actions.append(.signIn)
        case .subscriptionRequired, .subscriptionExpired:
            actions.append(.upgrade)
        case .cloudKitAccountNotFound:
            actions.append(.signIntoiCloud)
        case .accountNotVerified:
            actions.append(.verifyAccount)
        default:
            break
        }
        
        // Add contact support for critical errors
        if error.severity == .critical {
            actions.append(.contactSupport)
        }
        
        return actions
    }
    
    public func executeRecoveryAction(_ action: ErrorRecoveryAction, for error: AppError) {
        switch action {
        case .dismiss:
            clearError()
        case .retry:
            // Retry logic will be handled by RetryManager
            clearError()
        case .checkConnection:
            // Open Settings app to network settings
            if let url = URL(string: "App-Prefs:root=WIFI") {
                UIApplication.shared.open(url)
            }
        case .signIn:
            // Navigate to sign in screen
            // TODO: Implement navigation to sign in
            clearError()
        case .upgrade:
            // Navigate to subscription screen
            // TODO: Implement navigation to subscription
            clearError()
        case .signIntoiCloud:
            // Open Settings app to iCloud settings
            if let url = URL(string: "App-Prefs:root=CASTLE") {
                UIApplication.shared.open(url)
            }
        case .verifyAccount:
            // Navigate to account verification
            // TODO: Implement navigation to verification
            clearError()
        case .contactSupport:
            // Open support contact
            // TODO: Implement support contact
            clearError()
        }
    }
}

// MARK: - Error Event
public struct ErrorEvent: Identifiable, Equatable {
    public let id = UUID()
    public let error: AppError
    public let context: ErrorContext?
    public let timestamp: Date
    
    public static func == (lhs: ErrorEvent, rhs: ErrorEvent) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Error Context
public struct ErrorContext: CustomStringConvertible {
    public let operation: String
    public let userId: String?
    public let additionalInfo: [String: Any]
    
    public init(operation: String, userId: String? = nil, additionalInfo: [String: Any] = [:]) {
        self.operation = operation
        self.userId = userId
        self.additionalInfo = additionalInfo
    }
    
    public var description: String {
        var components = ["Operation: \(operation)"]
        
        if let userId = userId {
            components.append("User: \(userId)")
        }
        
        if !additionalInfo.isEmpty {
            let infoString = additionalInfo.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            components.append("Info: \(infoString)")
        }
        
        return components.joined(separator: " | ")
    }
}

// MARK: - Recovery Actions
public enum ErrorRecoveryAction: CaseIterable {
    case dismiss
    case retry
    case checkConnection
    case signIn
    case upgrade
    case signIntoiCloud
    case verifyAccount
    case contactSupport
    
    public var title: String {
        switch self {
        case .dismiss:
            return "Dismiss"
        case .retry:
            return "Try Again"
        case .checkConnection:
            return "Check Connection"
        case .signIn:
            return "Sign In"
        case .upgrade:
            return "Upgrade"
        case .signIntoiCloud:
            return "Sign into iCloud"
        case .verifyAccount:
            return "Verify Account"
        case .contactSupport:
            return "Contact Support"
        }
    }
    
    public var isDestructive: Bool {
        switch self {
        case .dismiss, .contactSupport:
            return false
        default:
            return false
        }
    }
    
    public var isPrimary: Bool {
        switch self {
        case .retry, .signIn, .upgrade:
            return true
        default:
            return false
        }
    }
}

// MARK: - Error Retry Manager
private class ErrorRetryManager {
    private var retryTimers: [UUID: Timer] = [:]
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 2.0
    
    func scheduleRetry(for errorEvent: ErrorEvent, context: ErrorContext) {
        // Implement exponential backoff retry logic
        // For now, this is a placeholder
        print("🔄 [RETRY] Would schedule retry for: \(errorEvent.error)")
    }
    
    func cancelRetry(for eventId: UUID) {
        retryTimers[eventId]?.invalidate()
        retryTimers.removeValue(forKey: eventId)
    }
}

// MARK: - Date Formatter Extension
private extension DateFormatter {
    static let errorLogFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}