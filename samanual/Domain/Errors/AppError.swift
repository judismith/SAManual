import Foundation

// MARK: - Domain Error Types
public enum AppError: Error, LocalizedError {
    // MARK: - User Domain Errors
    case userNotFound(id: String)
    case userAlreadyExists(email: String)
    case invalidUserData(field: String, message: String)
    case userAccessDenied(userId: String, requiredLevel: String)
    
    // MARK: - Program Domain Errors
    case programNotFound(id: String)
    case programNotActive(id: String)
    case enrollmentFailed(userId: String, programId: String, reason: String)
    case curriculumItemNotFound(id: String)
    
    // MARK: - Practice Domain Errors
    case practiceSessionNotFound(id: String)
    case sessionAlreadyActive(userId: String)
    case invalidSessionData(field: String, message: String)
    case techniqueNotAccessible(techniqueId: String, userId: String)
    
    // MARK: - Journal Domain Errors
    case journalEntryNotFound(id: String)
    case mediaUploadFailed(entryId: String, reason: String)
    case invalidJournalData(field: String, message: String)
    
    // MARK: - Authentication Errors
    case authenticationFailed(reason: String)
    case userNotAuthenticated
    case invalidCredentials
    case accountLocked(userId: String)
    
    // MARK: - Data Access Errors
    case dataNotFound(entity: String, id: String)
    case dataCorruption(entity: String, details: String)
    case dataValidationFailed(entity: String, field: String, message: String)
    case userCreationFailed(reason: String)
    case userUpdateFailed(reason: String)
    case userDeletionFailed(reason: String)
    case storageQuotaExceeded
    case serviceUnavailable
    case rateLimitExceeded
    
    // MARK: - Network Errors
    case networkError(underlying: Error)
    case serverError(statusCode: Int, message: String)
    case timeoutError(operation: String)
    case offlineError
    
    // MARK: - Permission Errors
    case permissionDenied(operation: String, requiredPermission: String)
    case insufficientPrivileges(userId: String, operation: String)
    
    // MARK: - Business Logic Errors
    case businessRuleViolation(rule: String, details: String)
    case invalidOperation(operation: String, reason: String)
    case quotaExceeded(resource: String, limit: Int)
    
    // MARK: - System Errors
    case systemError(component: String, details: String)
    case configurationError(setting: String, value: String)
    case unknownError(underlying: Error?)
    
    // MARK: - LocalizedError Implementation
    public var errorDescription: String? {
        switch self {
        // User Domain Errors
        case .userNotFound(let id):
            return "User with ID '\(id)' not found"
        case .userAlreadyExists(let email):
            return "User with email '\(email)' already exists"
        case .invalidUserData(let field, let message):
            return "Invalid user data for field '\(field)': \(message)"
        case .userAccessDenied(let userId, let requiredLevel):
            return "User '\(userId)' does not have required access level: \(requiredLevel)"
            
        // Program Domain Errors
        case .programNotFound(let id):
            return "Program with ID '\(id)' not found"
        case .programNotActive(let id):
            return "Program with ID '\(id)' is not active"
        case .enrollmentFailed(let userId, let programId, let reason):
            return "Failed to enroll user '\(userId)' in program '\(programId)': \(reason)"
        case .curriculumItemNotFound(let id):
            return "Curriculum item with ID '\(id)' not found"
            
        // Practice Domain Errors
        case .practiceSessionNotFound(let id):
            return "Practice session with ID '\(id)' not found"
        case .sessionAlreadyActive(let userId):
            return "User '\(userId)' already has an active practice session"
        case .invalidSessionData(let field, let message):
            return "Invalid session data for field '\(field)': \(message)"
        case .techniqueNotAccessible(let techniqueId, let userId):
            return "Technique '\(techniqueId)' is not accessible to user '\(userId)'"
            
        // Journal Domain Errors
        case .journalEntryNotFound(let id):
            return "Journal entry with ID '\(id)' not found"
        case .mediaUploadFailed(let entryId, let reason):
            return "Failed to upload media for entry '\(entryId)': \(reason)"
        case .invalidJournalData(let field, let message):
            return "Invalid journal data for field '\(field)': \(message)"
            
        // Authentication Errors
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .userNotAuthenticated:
            return "User is not authenticated"
        case .invalidCredentials:
            return "Invalid credentials provided"
        case .accountLocked(let userId):
            return "Account for user '\(userId)' is locked"
            
        // Data Access Errors
        case .dataNotFound(let entity, let id):
            return "\(entity) with ID '\(id)' not found"
        case .dataCorruption(let entity, let details):
            return "Data corruption detected for \(entity): \(details)"
        case .dataValidationFailed(let entity, let field, let message):
            return "Data validation failed for \(entity) field '\(field)': \(message)"
        case .userCreationFailed(let reason):
            return "Failed to create user: \(reason)"
        case .userUpdateFailed(let reason):
            return "Failed to update user: \(reason)"
        case .userDeletionFailed(let reason):
            return "Failed to delete user: \(reason)"
        case .storageQuotaExceeded:
            return "Storage quota exceeded"
        case .serviceUnavailable:
            return "Service is currently unavailable"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
            
        // Network Errors
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .timeoutError(let operation):
            return "Operation '\(operation)' timed out"
        case .offlineError:
            return "Device is offline"
            
        // Permission Errors
        case .permissionDenied(let operation, let requiredPermission):
            return "Permission denied for operation '\(operation)'. Required: \(requiredPermission)"
        case .insufficientPrivileges(let userId, let operation):
            return "User '\(userId)' has insufficient privileges for operation '\(operation)'"
            
        // Business Logic Errors
        case .businessRuleViolation(let rule, let details):
            return "Business rule violation: \(rule) - \(details)"
        case .invalidOperation(let operation, let reason):
            return "Invalid operation '\(operation)': \(reason)"
        case .quotaExceeded(let resource, let limit):
            return "Quota exceeded for \(resource). Limit: \(limit)"
            
        // System Errors
        case .systemError(let component, let details):
            return "System error in \(component): \(details)"
        case .configurationError(let setting, let value):
            return "Configuration error for setting '\(setting)' with value '\(value)'"
        case .unknownError(let underlying):
            if let underlying = underlying {
                return "Unknown error: \(underlying.localizedDescription)"
            } else {
                return "Unknown error occurred"
            }
        }
    }
    
    // MARK: - Error Recovery Suggestions
    public var recoverySuggestion: String? {
        switch self {
        case .userNotFound, .programNotFound, .curriculumItemNotFound, .practiceSessionNotFound, .journalEntryNotFound:
            return "Please verify the ID and try again"
        case .userAlreadyExists:
            return "Try signing in with existing account or use a different email"
        case .userNotAuthenticated:
            return "Please sign in to continue"
        case .invalidCredentials:
            return "Please check your email and password"
        case .networkError, .serverError, .timeoutError:
            return "Please check your internet connection and try again"
        case .offlineError:
            return "Please connect to the internet and try again"
        case .permissionDenied, .insufficientPrivileges:
            return "Please contact your instructor or administrator"
        case .quotaExceeded:
            return "Please upgrade your subscription or contact support"
        case .userCreationFailed, .userUpdateFailed, .userDeletionFailed:
            return "Please try again or contact support if the problem persists"
        case .storageQuotaExceeded:
            return "Please free up storage space or upgrade your plan"
        case .serviceUnavailable:
            return "Please try again later or contact support"
        case .rateLimitExceeded:
            return "Please wait a moment and try again"
        default:
            return "Please try again or contact support if the problem persists"
        }
    }
    
    // MARK: - Error Categories
    public var category: ErrorCategory {
        switch self {
        case .userNotFound, .programNotFound, .curriculumItemNotFound, .practiceSessionNotFound, .journalEntryNotFound:
            return .notFound
        case .userAlreadyExists, .invalidUserData, .invalidSessionData, .invalidJournalData, .dataValidationFailed:
            return .validation
        case .userNotAuthenticated, .authenticationFailed, .invalidCredentials, .accountLocked:
            return .authentication
        case .userAccessDenied, .permissionDenied, .insufficientPrivileges:
            return .authorization
        case .networkError, .serverError, .timeoutError, .offlineError:
            return .network
        case .dataCorruption, .systemError, .configurationError:
            return .system
        case .userCreationFailed, .userUpdateFailed, .userDeletionFailed:
            return .data
        case .storageQuotaExceeded, .serviceUnavailable, .rateLimitExceeded:
            return .system
        case .businessRuleViolation, .invalidOperation, .quotaExceeded:
            return .business
        case .unknownError:
            return .unknown
        case .dataNotFound, .enrollmentFailed, .sessionAlreadyActive, .techniqueNotAccessible, .mediaUploadFailed, .programNotActive:
            return .data
        }
    }
}

// MARK: - Error Category
public enum ErrorCategory: String, CaseIterable {
    case notFound = "not_found"
    case validation = "validation"
    case authentication = "authentication"
    case authorization = "authorization"
    case network = "network"
    case system = "system"
    case data = "data"
    case business = "business"
    case unknown = "unknown"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var isRecoverable: Bool {
        switch self {
        case .notFound, .validation, .authentication, .network, .data:
            return true
        case .authorization, .system, .business, .unknown:
            return false
        }
    }
}

// MARK: - Error Extensions
public extension AppError {
    /// Check if the error is a network-related error
    var isNetworkError: Bool {
        return category == .network
    }
    
    /// Check if the error is recoverable
    var isRecoverable: Bool {
        return category.isRecoverable
    }
    
    /// Get a user-friendly error message
    var userFriendlyMessage: String {
        return errorDescription ?? "An unexpected error occurred"
    }
} 