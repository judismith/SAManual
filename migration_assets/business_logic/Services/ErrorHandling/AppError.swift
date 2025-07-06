import Foundation

// MARK: - App Error
public enum AppError: Error, LocalizedError, Equatable {
    
    // MARK: - User Errors
    case userNotFound(id: String)
    case userAlreadyExists(id: String)
    case userCreationFailed(reason: String)
    case userUpdateFailed(reason: String)
    case userDeletionFailed(reason: String)
    case invalidUserData(field: String, reason: String)
    
    // MARK: - Program Errors
    case programNotFound(id: String)
    case programLoadFailed(reason: String)
    case programAccessDenied(id: String, reason: String)
    case invalidProgramData(field: String, reason: String)
    
    // MARK: - Enrollment Errors
    case enrollmentNotFound(id: String)
    case enrollmentCreationFailed(reason: String)
    case enrollmentUpdateFailed(reason: String)
    case invalidEnrollmentData(field: String, reason: String)
    case enrollmentAccessDenied(reason: String)
    
    // MARK: - Authentication Errors
    case authenticationFailed(reason: String)
    case authorizationFailed(reason: String)
    case tokenExpired
    case accountLocked
    case accountNotVerified
    case invalidCredentials
    
    // MARK: - Network Errors
    case networkUnavailable
    case requestTimeout
    case serverError(code: Int, message: String)
    case networkError(underlying: Error)
    case rateLimitExceeded
    
    // MARK: - Data Errors
    case dataCorruption(details: String)
    case dataValidationFailed(field: String, reason: String)
    case dataSyncFailed(reason: String)
    case cacheError(reason: String)
    case serializationFailed(type: String, reason: String)
    
    // MARK: - CloudKit Errors
    case cloudKitUnavailable
    case cloudKitQuotaExceeded
    case cloudKitSyncFailed(reason: String)
    case cloudKitAccountNotFound
    case cloudKitPermissionDenied
    
    // MARK: - Firestore Errors
    case firestoreUnavailable
    case firestorePermissionDenied
    case firestoreQuotaExceeded
    case firestoreOperationFailed(reason: String)
    
    // MARK: - Media Errors
    case mediaNotFound(id: String)
    case mediaAccessDenied(id: String, reason: String)
    case mediaDownloadFailed(id: String, reason: String)
    case mediaUploadFailed(reason: String)
    case unsupportedMediaFormat(format: String)
    
    // MARK: - Subscription Errors
    case subscriptionRequired(feature: String)
    case subscriptionExpired
    case subscriptionValidationFailed
    case paymentFailed(reason: String)
    
    // MARK: - Feature Errors
    case featureDisabled(feature: String)
    case featureNotAvailable(feature: String, reason: String)
    case practiceSessionFailed(reason: String)
    case aiGenerationFailed(reason: String)
    
    // MARK: - System Errors
    case unknown(underlying: Error)
    case configurationError(reason: String)
    case dependencyResolutionFailed(type: String)
    case operationCancelled
    case operationTimeout
    
    // MARK: - Error Properties
    public var errorDescription: String? {
        switch self {
        // User Errors
        case .userNotFound(let id):
            return "User with ID '\(id)' was not found."
        case .userAlreadyExists(let id):
            return "User with ID '\(id)' already exists."
        case .userCreationFailed(let reason):
            return "Failed to create user: \(reason)"
        case .userUpdateFailed(let reason):
            return "Failed to update user: \(reason)"
        case .userDeletionFailed(let reason):
            return "Failed to delete user: \(reason)"
        case .invalidUserData(let field, let reason):
            return "Invalid user data in field '\(field)': \(reason)"
            
        // Program Errors
        case .programNotFound(let id):
            return "Program with ID '\(id)' was not found."
        case .programLoadFailed(let reason):
            return "Failed to load program: \(reason)"
        case .programAccessDenied(let id, let reason):
            return "Access denied to program '\(id)': \(reason)"
        case .invalidProgramData(let field, let reason):
            return "Invalid program data in field '\(field)': \(reason)"
            
        // Enrollment Errors
        case .enrollmentNotFound(let id):
            return "Enrollment with ID '\(id)' was not found."
        case .enrollmentCreationFailed(let reason):
            return "Failed to create enrollment: \(reason)"
        case .enrollmentUpdateFailed(let reason):
            return "Failed to update enrollment: \(reason)"
        case .invalidEnrollmentData(let field, let reason):
            return "Invalid enrollment data in field '\(field)': \(reason)"
        case .enrollmentAccessDenied(let reason):
            return "Enrollment access denied: \(reason)"
            
        // Authentication Errors
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .authorizationFailed(let reason):
            return "Authorization failed: \(reason)"
        case .tokenExpired:
            return "Your session has expired. Please sign in again."
        case .accountLocked:
            return "Your account has been locked. Please contact support."
        case .accountNotVerified:
            return "Your account is not verified. Please check your email."
        case .invalidCredentials:
            return "Invalid email or password."
            
        // Network Errors
        case .networkUnavailable:
            return "Network connection is unavailable. Please check your internet connection."
        case .requestTimeout:
            return "Request timed out. Please try again."
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .rateLimitExceeded:
            return "Too many requests. Please wait and try again."
            
        // Data Errors
        case .dataCorruption(let details):
            return "Data corruption detected: \(details)"
        case .dataValidationFailed(let field, let reason):
            return "Data validation failed for '\(field)': \(reason)"
        case .dataSyncFailed(let reason):
            return "Data synchronization failed: \(reason)"
        case .cacheError(let reason):
            return "Cache error: \(reason)"
        case .serializationFailed(let type, let reason):
            return "Failed to serialize '\(type)': \(reason)"
            
        // CloudKit Errors
        case .cloudKitUnavailable:
            return "iCloud is unavailable. Please check your iCloud settings."
        case .cloudKitQuotaExceeded:
            return "iCloud storage quota exceeded. Please free up space."
        case .cloudKitSyncFailed(let reason):
            return "iCloud sync failed: \(reason)"
        case .cloudKitAccountNotFound:
            return "iCloud account not found. Please sign in to iCloud."
        case .cloudKitPermissionDenied:
            return "Permission denied for iCloud access."
            
        // Firestore Errors
        case .firestoreUnavailable:
            return "Database service is unavailable. Please try again later."
        case .firestorePermissionDenied:
            return "Permission denied for database access."
        case .firestoreQuotaExceeded:
            return "Database quota exceeded. Please contact support."
        case .firestoreOperationFailed(let reason):
            return "Database operation failed: \(reason)"
            
        // Media Errors
        case .mediaNotFound(let id):
            return "Media with ID '\(id)' was not found."
        case .mediaAccessDenied(let id, let reason):
            return "Access denied to media '\(id)': \(reason)"
        case .mediaDownloadFailed(let id, let reason):
            return "Failed to download media '\(id)': \(reason)"
        case .mediaUploadFailed(let reason):
            return "Failed to upload media: \(reason)"
        case .unsupportedMediaFormat(let format):
            return "Unsupported media format: \(format)"
            
        // Subscription Errors
        case .subscriptionRequired(let feature):
            return "A subscription is required to use '\(feature)'. Please upgrade your account."
        case .subscriptionExpired:
            return "Your subscription has expired. Please renew to continue."
        case .subscriptionValidationFailed:
            return "Failed to validate subscription. Please try again."
        case .paymentFailed(let reason):
            return "Payment failed: \(reason)"
            
        // Feature Errors
        case .featureDisabled(let feature):
            return "The '\(feature)' feature is currently disabled."
        case .featureNotAvailable(let feature, let reason):
            return "Feature '\(feature)' is not available: \(reason)"
        case .practiceSessionFailed(let reason):
            return "Practice session failed: \(reason)"
        case .aiGenerationFailed(let reason):
            return "AI content generation failed: \(reason)"
            
        // System Errors
        case .unknown(let underlying):
            return "An unexpected error occurred: \(underlying.localizedDescription)"
        case .configurationError(let reason):
            return "Configuration error: \(reason)"
        case .dependencyResolutionFailed(let type):
            return "Failed to resolve dependency '\(type)'"
        case .operationCancelled:
            return "Operation was cancelled."
        case .operationTimeout:
            return "Operation timed out."
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .userNotFound, .programNotFound, .enrollmentNotFound, .mediaNotFound:
            return "The requested resource could not be found."
        case .networkUnavailable, .cloudKitUnavailable, .firestoreUnavailable:
            return "The service is currently unavailable."
        case .authenticationFailed, .authorizationFailed, .invalidCredentials:
            return "Authentication or authorization failed."
        case .subscriptionRequired, .subscriptionExpired:
            return "A valid subscription is required."
        default:
            return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Check your internet connection and try again."
        case .cloudKitUnavailable:
            return "Check your iCloud settings and try again."
        case .tokenExpired:
            return "Please sign in again."
        case .subscriptionRequired, .subscriptionExpired:
            return "Please upgrade or renew your subscription."
        case .accountNotVerified:
            return "Please check your email for a verification link."
        case .rateLimitExceeded:
            return "Please wait a moment and try again."
        default:
            return "Please try again later or contact support if the problem persists."
        }
    }
}

// MARK: - Equatable Implementation
extension AppError {
    public static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        // User Errors
        case (.userNotFound(let lhsId), .userNotFound(let rhsId)):
            return lhsId == rhsId
        case (.userAlreadyExists(let lhsId), .userAlreadyExists(let rhsId)):
            return lhsId == rhsId
        case (.userCreationFailed(let lhsReason), .userCreationFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.userUpdateFailed(let lhsReason), .userUpdateFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.userDeletionFailed(let lhsReason), .userDeletionFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.invalidUserData(let lhsField, let lhsReason), .invalidUserData(let rhsField, let rhsReason)):
            return lhsField == rhsField && lhsReason == rhsReason
            
        // Program Errors
        case (.programNotFound(let lhsId), .programNotFound(let rhsId)):
            return lhsId == rhsId
        case (.programLoadFailed(let lhsReason), .programLoadFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.programAccessDenied(let lhsId, let lhsReason), .programAccessDenied(let rhsId, let rhsReason)):
            return lhsId == rhsId && lhsReason == rhsReason
        case (.invalidProgramData(let lhsField, let lhsReason), .invalidProgramData(let rhsField, let rhsReason)):
            return lhsField == rhsField && lhsReason == rhsReason
            
        // Enrollment Errors
        case (.enrollmentNotFound(let lhsId), .enrollmentNotFound(let rhsId)):
            return lhsId == rhsId
        case (.enrollmentCreationFailed(let lhsReason), .enrollmentCreationFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.enrollmentUpdateFailed(let lhsReason), .enrollmentUpdateFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.invalidEnrollmentData(let lhsField, let lhsReason), .invalidEnrollmentData(let rhsField, let rhsReason)):
            return lhsField == rhsField && lhsReason == rhsReason
        case (.enrollmentAccessDenied(let lhsReason), .enrollmentAccessDenied(let rhsReason)):
            return lhsReason == rhsReason
            
        // Authentication Errors
        case (.authenticationFailed(let lhsReason), .authenticationFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.authorizationFailed(let lhsReason), .authorizationFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.tokenExpired, .tokenExpired):
            return true
        case (.accountLocked, .accountLocked):
            return true
        case (.accountNotVerified, .accountNotVerified):
            return true
        case (.invalidCredentials, .invalidCredentials):
            return true
            
        // Network Errors
        case (.networkUnavailable, .networkUnavailable):
            return true
        case (.requestTimeout, .requestTimeout):
            return true
        case (.serverError(let lhsCode, let lhsMessage), .serverError(let rhsCode, let rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.rateLimitExceeded, .rateLimitExceeded):
            return true
            
        // Data Errors
        case (.dataCorruption(let lhsDetails), .dataCorruption(let rhsDetails)):
            return lhsDetails == rhsDetails
        case (.dataValidationFailed(let lhsField, let lhsReason), .dataValidationFailed(let rhsField, let rhsReason)):
            return lhsField == rhsField && lhsReason == rhsReason
        case (.dataSyncFailed(let lhsReason), .dataSyncFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.cacheError(let lhsReason), .cacheError(let rhsReason)):
            return lhsReason == rhsReason
        case (.serializationFailed(let lhsType, let lhsReason), .serializationFailed(let rhsType, let rhsReason)):
            return lhsType == rhsType && lhsReason == rhsReason
            
        // CloudKit Errors
        case (.cloudKitUnavailable, .cloudKitUnavailable):
            return true
        case (.cloudKitQuotaExceeded, .cloudKitQuotaExceeded):
            return true
        case (.cloudKitSyncFailed(let lhsReason), .cloudKitSyncFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.cloudKitAccountNotFound, .cloudKitAccountNotFound):
            return true
        case (.cloudKitPermissionDenied, .cloudKitPermissionDenied):
            return true
            
        // Firestore Errors
        case (.firestoreUnavailable, .firestoreUnavailable):
            return true
        case (.firestorePermissionDenied, .firestorePermissionDenied):
            return true
        case (.firestoreQuotaExceeded, .firestoreQuotaExceeded):
            return true
        case (.firestoreOperationFailed(let lhsReason), .firestoreOperationFailed(let rhsReason)):
            return lhsReason == rhsReason
            
        // Media Errors
        case (.mediaNotFound(let lhsId), .mediaNotFound(let rhsId)):
            return lhsId == rhsId
        case (.mediaAccessDenied(let lhsId, let lhsReason), .mediaAccessDenied(let rhsId, let rhsReason)):
            return lhsId == rhsId && lhsReason == rhsReason
        case (.mediaDownloadFailed(let lhsId, let lhsReason), .mediaDownloadFailed(let rhsId, let rhsReason)):
            return lhsId == rhsId && lhsReason == rhsReason
        case (.mediaUploadFailed(let lhsReason), .mediaUploadFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.unsupportedMediaFormat(let lhsFormat), .unsupportedMediaFormat(let rhsFormat)):
            return lhsFormat == rhsFormat
            
        // Subscription Errors
        case (.subscriptionRequired(let lhsFeature), .subscriptionRequired(let rhsFeature)):
            return lhsFeature == rhsFeature
        case (.subscriptionExpired, .subscriptionExpired):
            return true
        case (.subscriptionValidationFailed, .subscriptionValidationFailed):
            return true
        case (.paymentFailed(let lhsReason), .paymentFailed(let rhsReason)):
            return lhsReason == rhsReason
            
        // Feature Errors
        case (.featureDisabled(let lhsFeature), .featureDisabled(let rhsFeature)):
            return lhsFeature == rhsFeature
        case (.featureNotAvailable(let lhsFeature, let lhsReason), .featureNotAvailable(let rhsFeature, let rhsReason)):
            return lhsFeature == rhsFeature && lhsReason == rhsReason
        case (.practiceSessionFailed(let lhsReason), .practiceSessionFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.aiGenerationFailed(let lhsReason), .aiGenerationFailed(let rhsReason)):
            return lhsReason == rhsReason
            
        // System Errors
        case (.unknown(let lhsError), .unknown(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.configurationError(let lhsReason), .configurationError(let rhsReason)):
            return lhsReason == rhsReason
        case (.dependencyResolutionFailed(let lhsType), .dependencyResolutionFailed(let rhsType)):
            return lhsType == rhsType
        case (.operationCancelled, .operationCancelled):
            return true
        case (.operationTimeout, .operationTimeout):
            return true
            
        // Different cases are not equal
        default:
            return false
        }
    }
}

// MARK: - Error Categories
extension AppError {
    public var category: ErrorCategory {
        switch self {
        case .userNotFound, .userAlreadyExists, .userCreationFailed, .userUpdateFailed, .userDeletionFailed, .invalidUserData:
            return .user
        case .programNotFound, .programLoadFailed, .programAccessDenied, .invalidProgramData:
            return .program
        case .enrollmentNotFound, .enrollmentCreationFailed, .enrollmentUpdateFailed, .invalidEnrollmentData, .enrollmentAccessDenied:
            return .enrollment
        case .authenticationFailed, .authorizationFailed, .tokenExpired, .accountLocked, .accountNotVerified, .invalidCredentials:
            return .authentication
        case .networkUnavailable, .requestTimeout, .serverError, .networkError, .rateLimitExceeded:
            return .network
        case .dataCorruption, .dataValidationFailed, .dataSyncFailed, .cacheError, .serializationFailed:
            return .data
        case .cloudKitUnavailable, .cloudKitQuotaExceeded, .cloudKitSyncFailed, .cloudKitAccountNotFound, .cloudKitPermissionDenied:
            return .cloudKit
        case .firestoreUnavailable, .firestorePermissionDenied, .firestoreQuotaExceeded, .firestoreOperationFailed:
            return .firestore
        case .mediaNotFound, .mediaAccessDenied, .mediaDownloadFailed, .mediaUploadFailed, .unsupportedMediaFormat:
            return .media
        case .subscriptionRequired, .subscriptionExpired, .subscriptionValidationFailed, .paymentFailed:
            return .subscription
        case .featureDisabled, .featureNotAvailable, .practiceSessionFailed, .aiGenerationFailed:
            return .feature
        case .unknown, .configurationError, .dependencyResolutionFailed, .operationCancelled, .operationTimeout:
            return .system
        }
    }
    
    public var severity: ErrorSeverity {
        switch self {
        case .dataCorruption, .cloudKitAccountNotFound, .configurationError:
            return .critical
        case .userCreationFailed, .programLoadFailed, .networkUnavailable, .serverError:
            return .high
        case .userNotFound, .programNotFound, .authenticationFailed, .subscriptionRequired:
            return .medium
        case .rateLimitExceeded, .operationCancelled, .requestTimeout:
            return .low
        default:
            return .medium
        }
    }
    
    public var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .requestTimeout, .serverError, .rateLimitExceeded,
             .cloudKitUnavailable, .firestoreUnavailable, .dataSyncFailed, .operationTimeout:
            return true
        case .userNotFound, .programNotFound, .invalidCredentials, .subscriptionRequired,
             .dataCorruption, .configurationError:
            return false
        default:
            return false
        }
    }
}

// MARK: - Error Categories and Severity
public enum ErrorCategory: String, CaseIterable {
    case user = "User"
    case program = "Program"
    case enrollment = "Enrollment"
    case authentication = "Authentication"
    case network = "Network"
    case data = "Data"
    case cloudKit = "CloudKit"
    case firestore = "Firestore"
    case media = "Media"
    case subscription = "Subscription"
    case feature = "Feature"
    case system = "System"
}

public enum ErrorSeverity: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
    
    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    public var emoji: String {
        switch self {
        case .low: return "ℹ️"
        case .medium: return "⚠️"
        case .high: return "🚨"
        case .critical: return "💥"
        }
    }
}