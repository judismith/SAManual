import Foundation
import Combine

// MARK: - Auth Service Protocol
public protocol AuthService {
    
    // MARK: - Authentication State
    var isAuthenticated: Bool { get }
    var currentUser: AuthUser? { get }
    var authStatePublisher: AnyPublisher<AuthState, Never> { get }
    
    // MARK: - Email Authentication
    func signIn(email: String, password: String) async throws -> AuthUser
    func signUp(email: String, password: String, profile: UserRegistrationProfile) async throws -> AuthUser
    func signOut() async throws
    func resetPassword(email: String) async throws
    func changePassword(currentPassword: String, newPassword: String) async throws
    func updateEmail(newEmail: String, password: String) async throws -> AuthUser
    
    // MARK: - Social Authentication
    func signInWithGoogle() async throws -> AuthUser
    func signInWithApple() async throws -> AuthUser
    func linkGoogleAccount() async throws -> AuthUser
    func linkAppleAccount() async throws -> AuthUser
    func unlinkSocialAccount(provider: SocialProvider) async throws -> AuthUser
    
    // MARK: - Account Verification
    func sendEmailVerification() async throws
    func verifyEmail(code: String) async throws -> AuthUser
    func isEmailVerified() async throws -> Bool
    func sendPhoneVerification(phoneNumber: String) async throws
    func verifyPhone(code: String) async throws -> AuthUser
    
    // MARK: - Multi-Factor Authentication
    func enableMFA() async throws -> MFASetupResult
    func disableMFA(password: String) async throws
    func verifyMFA(code: String) async throws -> AuthUser
    func generateBackupCodes() async throws -> [String]
    func getMFAStatus() async throws -> MFAStatus
    
    // MARK: - Biometric Authentication
    func enableBiometricAuth() async throws -> BiometricAuthResult
    func disableBiometricAuth() async throws
    func authenticateWithBiometrics() async throws -> AuthUser
    func isBiometricAuthAvailable() async throws -> BiometricAvailability
    func getBiometricAuthStatus() async throws -> BiometricAuthStatus
    
    // MARK: - Session Management
    func refreshToken() async throws -> AuthToken
    func validateSession() async throws -> Bool
    func getSessionInfo() async throws -> SessionInfo
    func terminateAllSessions() async throws
    func terminateSession(sessionId: String) async throws
    func getActiveSessions() async throws -> [SessionInfo]
    
    // MARK: - Account Management
    func deleteAccount(password: String) async throws
    func deactivateAccount(password: String) async throws
    func reactivateAccount(email: String, password: String) async throws -> AuthUser
    func exportAccountData() async throws -> AccountExportData
    
    // MARK: - Access Control
    func checkPermission(_ permission: Permission) async throws -> Bool
    func requestPermission(_ permission: Permission) async throws -> PermissionResult
    func getUserRoles() async throws -> [UserRole]
    func updateUserRole(userId: String, role: UserRole) async throws
    
    // MARK: - Security Events
    func getSecurityEvents(limit: Int) async throws -> [SecurityEvent]
    func reportSecurityIssue(_ issue: SecurityIssue) async throws
    func getLoginHistory(limit: Int) async throws -> [LoginEvent]
    
    // MARK: - Device Management
    func registerDevice(_ device: DeviceInfo) async throws -> DeviceRegistration
    func unregisterDevice(deviceId: String) async throws
    func getRegisteredDevices() async throws -> [DeviceRegistration]
    func updateDeviceInfo(_ device: DeviceInfo) async throws -> DeviceRegistration
}

// MARK: - Auth User
public struct AuthUser: Identifiable, Codable {
    public let id: String
    public let email: String
    public let isEmailVerified: Bool
    public let phoneNumber: String?
    public let isPhoneVerified: Bool
    public let displayName: String?
    public let photoURL: String?
    public let createdAt: Date
    public let lastSignInAt: Date?
    public let metadata: AuthUserMetadata
    public let providerData: [AuthProviderData]
    public let customClaims: [String: Any]
    public let accessLevel: AccessLevel
    public let roles: [UserRole]
    public let isActive: Bool
    public let isMFAEnabled: Bool
    public let isBiometricEnabled: Bool
    
    public init(id: String,
                email: String,
                isEmailVerified: Bool = false,
                phoneNumber: String? = nil,
                isPhoneVerified: Bool = false,
                displayName: String? = nil,
                photoURL: String? = nil,
                createdAt: Date = Date(),
                lastSignInAt: Date? = nil,
                metadata: AuthUserMetadata = AuthUserMetadata(),
                providerData: [AuthProviderData] = [],
                customClaims: [String: Any] = [:],
                accessLevel: AccessLevel = .free,
                roles: [UserRole] = [],
                isActive: Bool = true,
                isMFAEnabled: Bool = false,
                isBiometricEnabled: Bool = false) {
        self.id = id
        self.email = email
        self.isEmailVerified = isEmailVerified
        self.phoneNumber = phoneNumber
        self.isPhoneVerified = isPhoneVerified
        self.displayName = displayName
        self.photoURL = photoURL
        self.createdAt = createdAt
        self.lastSignInAt = lastSignInAt
        self.metadata = metadata
        self.providerData = providerData
        self.customClaims = customClaims
        self.accessLevel = accessLevel
        self.roles = roles
        self.isActive = isActive
        self.isMFAEnabled = isMFAEnabled
        self.isBiometricEnabled = isBiometricEnabled
    }
    
    // MARK: - Codable Implementation
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        isEmailVerified = try container.decode(Bool.self, forKey: .isEmailVerified)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        isPhoneVerified = try container.decode(Bool.self, forKey: .isPhoneVerified)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        photoURL = try container.decodeIfPresent(String.self, forKey: .photoURL)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastSignInAt = try container.decodeIfPresent(Date.self, forKey: .lastSignInAt)
        metadata = try container.decode(AuthUserMetadata.self, forKey: .metadata)
        providerData = try container.decode([AuthProviderData].self, forKey: .providerData)
        accessLevel = try container.decode(AccessLevel.self, forKey: .accessLevel)
        roles = try container.decode([UserRole].self, forKey: .roles)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        isMFAEnabled = try container.decode(Bool.self, forKey: .isMFAEnabled)
        isBiometricEnabled = try container.decode(Bool.self, forKey: .isBiometricEnabled)
        
        // Handle custom claims dictionary
        if let claimsData = try container.decodeIfPresent(Data.self, forKey: .customClaims) {
            customClaims = try JSONSerialization.jsonObject(with: claimsData) as? [String: Any] ?? [:]
        } else {
            customClaims = [:]
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(isEmailVerified, forKey: .isEmailVerified)
        try container.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
        try container.encode(isPhoneVerified, forKey: .isPhoneVerified)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(photoURL, forKey: .photoURL)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(lastSignInAt, forKey: .lastSignInAt)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(providerData, forKey: .providerData)
        try container.encode(accessLevel, forKey: .accessLevel)
        try container.encode(roles, forKey: .roles)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(isMFAEnabled, forKey: .isMFAEnabled)
        try container.encode(isBiometricEnabled, forKey: .isBiometricEnabled)
        
        // Handle custom claims dictionary
        let claimsData = try JSONSerialization.data(withJSONObject: customClaims)
        try container.encode(claimsData, forKey: .customClaims)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, email, isEmailVerified, phoneNumber, isPhoneVerified
        case displayName, photoURL, createdAt, lastSignInAt, metadata
        case providerData, customClaims, accessLevel, roles, isActive
        case isMFAEnabled, isBiometricEnabled
    }
}

// MARK: - Auth State
public enum AuthState {
    case unauthenticated
    case authenticated(AuthUser)
    case loading
    case error(AuthServiceError)
    
    public var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }
    
    public var user: AuthUser? {
        if case .authenticated(let user) = self {
            return user
        }
        return nil
    }
}

// MARK: - User Registration Profile
public struct UserRegistrationProfile: Codable {
    public let firstName: String
    public let lastName: String
    public let dateOfBirth: Date?
    public let phoneNumber: String?
    public let acceptsTerms: Bool
    public let acceptsPrivacyPolicy: Bool
    public let marketingConsent: Bool
    public let referralCode: String?
    public let emergencyContact: EmergencyContact?
    
    public init(firstName: String,
                lastName: String,
                dateOfBirth: Date? = nil,
                phoneNumber: String? = nil,
                acceptsTerms: Bool,
                acceptsPrivacyPolicy: Bool,
                marketingConsent: Bool = false,
                referralCode: String? = nil,
                emergencyContact: EmergencyContact? = nil) {
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.phoneNumber = phoneNumber
        self.acceptsTerms = acceptsTerms
        self.acceptsPrivacyPolicy = acceptsPrivacyPolicy
        self.marketingConsent = marketingConsent
        self.referralCode = referralCode
        self.emergencyContact = emergencyContact
    }
}

// MARK: - Emergency Contact
public struct EmergencyContact: Codable {
    public let name: String
    public let phoneNumber: String
    public let relationship: String
    public let email: String?
    
    public init(name: String, phoneNumber: String, relationship: String, email: String? = nil) {
        self.name = name
        self.phoneNumber = phoneNumber
        self.relationship = relationship
        self.email = email
    }
}

// MARK: - Social Provider
public enum SocialProvider: String, Codable, CaseIterable {
    case google = "google"
    case apple = "apple"
    case facebook = "facebook"
    case twitter = "twitter"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Auth Provider Data
public struct AuthProviderData: Codable, Equatable {
    public let providerId: String
    public let uid: String
    public let displayName: String?
    public let email: String?
    public let phoneNumber: String?
    public let photoURL: String?
    
    public init(providerId: String,
                uid: String,
                displayName: String? = nil,
                email: String? = nil,
                phoneNumber: String? = nil,
                photoURL: String? = nil) {
        self.providerId = providerId
        self.uid = uid
        self.displayName = displayName
        self.email = email
        self.phoneNumber = phoneNumber
        self.photoURL = photoURL
    }
}

// MARK: - Auth User Metadata
public struct AuthUserMetadata: Codable, Equatable {
    public let creationTime: Date?
    public let lastSignInTime: Date?
    public let lastRefreshTime: Date?
    public let tokenHash: String?
    
    public init(creationTime: Date? = nil,
                lastSignInTime: Date? = nil,
                lastRefreshTime: Date? = nil,
                tokenHash: String? = nil) {
        self.creationTime = creationTime
        self.lastSignInTime = lastSignInTime
        self.lastRefreshTime = lastRefreshTime
        self.tokenHash = tokenHash
    }
}

// MARK: - Auth Token
public struct AuthToken: Codable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let tokenType: String
    public let scope: [String]
    
    public init(accessToken: String,
                refreshToken: String,
                expiresAt: Date,
                tokenType: String = "Bearer",
                scope: [String] = []) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.tokenType = tokenType
        self.scope = scope
    }
    
    public var isExpired: Bool {
        return Date() >= expiresAt
    }
}

// MARK: - MFA Setup Result
public struct MFASetupResult: Codable {
    public let secret: String
    public let qrCodeURL: String
    public let backupCodes: [String]
    public let isEnabled: Bool
    
    public init(secret: String, qrCodeURL: String, backupCodes: [String], isEnabled: Bool) {
        self.secret = secret
        self.qrCodeURL = qrCodeURL
        self.backupCodes = backupCodes
        self.isEnabled = isEnabled
    }
}

// MARK: - MFA Status
public struct MFAStatus: Codable {
    public let isEnabled: Bool
    public let methods: [MFAMethod]
    public let backupCodesRemaining: Int
    public let lastUsed: Date?
    
    public init(isEnabled: Bool, methods: [MFAMethod], backupCodesRemaining: Int, lastUsed: Date? = nil) {
        self.isEnabled = isEnabled
        self.methods = methods
        self.backupCodesRemaining = backupCodesRemaining
        self.lastUsed = lastUsed
    }
}

// MARK: - MFA Method
public enum MFAMethod: String, Codable, CaseIterable {
    case totp = "totp"
    case sms = "sms"
    case email = "email"
    case backupCodes = "backup_codes"
    
    public var displayName: String {
        switch self {
        case .totp: return "Authenticator App"
        case .sms: return "SMS"
        case .email: return "Email"
        case .backupCodes: return "Backup Codes"
        }
    }
}

// MARK: - Biometric Auth Result
public struct BiometricAuthResult: Codable {
    public let isEnabled: Bool
    public let biometricType: BiometricType
    public let deviceSupported: Bool
    public let enrollmentRequired: Bool
    
    public init(isEnabled: Bool, biometricType: BiometricType, deviceSupported: Bool, enrollmentRequired: Bool) {
        self.isEnabled = isEnabled
        self.biometricType = biometricType
        self.deviceSupported = deviceSupported
        self.enrollmentRequired = enrollmentRequired
    }
}

// MARK: - Biometric Type
public enum BiometricType: String, Codable, CaseIterable {
    case none = "none"
    case touchID = "touch_id"
    case faceID = "face_id"
    case fingerprint = "fingerprint"
    
    public var displayName: String {
        switch self {
        case .none: return "None"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        case .fingerprint: return "Fingerprint"
        }
    }
}

// MARK: - Biometric Availability
public struct BiometricAvailability: Codable {
    public let isAvailable: Bool
    public let biometricType: BiometricType
    public let error: String?
    
    public init(isAvailable: Bool, biometricType: BiometricType, error: String? = nil) {
        self.isAvailable = isAvailable
        self.biometricType = biometricType
        self.error = error
    }
}

// MARK: - Biometric Auth Status
public struct BiometricAuthStatus: Codable {
    public let isEnabled: Bool
    public let isAvailable: Bool
    public let biometricType: BiometricType
    public let lastUsed: Date?
    
    public init(isEnabled: Bool, isAvailable: Bool, biometricType: BiometricType, lastUsed: Date? = nil) {
        self.isEnabled = isEnabled
        self.isAvailable = isAvailable
        self.biometricType = biometricType
        self.lastUsed = lastUsed
    }
}

// MARK: - Session Info
public struct SessionInfo: Identifiable, Codable {
    public let id: String
    public let userId: String
    public let deviceInfo: DeviceInfo
    public let ipAddress: String
    public let userAgent: String
    public let location: String?
    public let createdAt: Date
    public let lastActivityAt: Date
    public let expiresAt: Date
    public let isCurrent: Bool
    
    public init(id: String,
                userId: String,
                deviceInfo: DeviceInfo,
                ipAddress: String,
                userAgent: String,
                location: String? = nil,
                createdAt: Date = Date(),
                lastActivityAt: Date = Date(),
                expiresAt: Date,
                isCurrent: Bool = false) {
        self.id = id
        self.userId = userId
        self.deviceInfo = deviceInfo
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.location = location
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
        self.expiresAt = expiresAt
        self.isCurrent = isCurrent
    }
}

// MARK: - Device Info
public struct DeviceInfo: Codable, Equatable {
    public let deviceId: String
    public let name: String
    public let model: String
    public let platform: String
    public let osVersion: String
    public let appVersion: String
    public let isPushEnabled: Bool
    public let timezone: String
    public let locale: String
    
    public init(deviceId: String,
                name: String,
                model: String,
                platform: String,
                osVersion: String,
                appVersion: String,
                isPushEnabled: Bool = false,
                timezone: String = TimeZone.current.identifier,
                locale: String = Locale.current.identifier) {
        self.deviceId = deviceId
        self.name = name
        self.model = model
        self.platform = platform
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.isPushEnabled = isPushEnabled
        self.timezone = timezone
        self.locale = locale
    }
}

// MARK: - Device Registration
public struct DeviceRegistration: Identifiable, Codable {
    public let id: String
    public let userId: String
    public let deviceInfo: DeviceInfo
    public let pushToken: String?
    public let isActive: Bool
    public let registeredAt: Date
    public let lastSeenAt: Date
    
    public init(id: String = UUID().uuidString,
                userId: String,
                deviceInfo: DeviceInfo,
                pushToken: String? = nil,
                isActive: Bool = true,
                registeredAt: Date = Date(),
                lastSeenAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.deviceInfo = deviceInfo
        self.pushToken = pushToken
        self.isActive = isActive
        self.registeredAt = registeredAt
        self.lastSeenAt = lastSeenAt
    }
}

// MARK: - Permission
public enum Permission: String, Codable, CaseIterable {
    case viewPrograms = "view_programs"
    case editPrograms = "edit_programs"
    case manageUsers = "manage_users"
    case accessInstructorContent = "access_instructor_content"
    case uploadMedia = "upload_media"
    case moderateContent = "moderate_content"
    case viewAnalytics = "view_analytics"
    case manageAnnouncements = "manage_announcements"
    case accessPracticeFeature = "access_practice_feature"
    case useAIFeatures = "use_ai_features"
    
    public var displayName: String {
        switch self {
        case .viewPrograms: return "View Programs"
        case .editPrograms: return "Edit Programs"
        case .manageUsers: return "Manage Users"
        case .accessInstructorContent: return "Access Instructor Content"
        case .uploadMedia: return "Upload Media"
        case .moderateContent: return "Moderate Content"
        case .viewAnalytics: return "View Analytics"
        case .manageAnnouncements: return "Manage Announcements"
        case .accessPracticeFeature: return "Access Practice Feature"
        case .useAIFeatures: return "Use AI Features"
        }
    }
    
    public var requiredAccessLevel: AccessLevel {
        switch self {
        case .viewPrograms, .accessPracticeFeature:
            return .free
        case .useAIFeatures:
            return .subscriber
        case .accessInstructorContent, .uploadMedia, .editPrograms, .manageAnnouncements:
            return .instructor
        case .manageUsers, .moderateContent, .viewAnalytics:
            return .instructor
        }
    }
}

// MARK: - Permission Result
public enum PermissionResult: Codable {
    case granted
    case denied(reason: String)
    case requiresUpgrade(toLevel: AccessLevel)
    
    public var isGranted: Bool {
        if case .granted = self {
            return true
        }
        return false
    }
}

// MARK: - User Role
public struct UserRole: Codable, Equatable {
    public let id: String
    public let name: String
    public let permissions: [Permission]
    public let accessLevel: AccessLevel
    public let isSystem: Bool
    
    public init(id: String,
                name: String,
                permissions: [Permission],
                accessLevel: AccessLevel,
                isSystem: Bool = false) {
        self.id = id
        self.name = name
        self.permissions = permissions
        self.accessLevel = accessLevel
        self.isSystem = isSystem
    }
    
    public static let student = UserRole(
        id: "student",
        name: "Student",
        permissions: [.viewPrograms, .accessPracticeFeature],
        accessLevel: .free,
        isSystem: true
    )
    
    public static let subscriber = UserRole(
        id: "subscriber",
        name: "Subscriber",
        permissions: [.viewPrograms, .accessPracticeFeature, .useAIFeatures],
        accessLevel: .subscriber,
        isSystem: true
    )
    
    public static let instructor = UserRole(
        id: "instructor",
        name: "Instructor",
        permissions: Permission.allCases,
        accessLevel: .instructor,
        isSystem: true
    )
}

// MARK: - Security Event
public struct SecurityEvent: Identifiable, Codable {
    public let id = UUID()
    public let userId: String
    public let eventType: SecurityEventType
    public let timestamp: Date
    public let ipAddress: String?
    public let userAgent: String?
    public let location: String?
    public let details: [String: String]
    public let severity: SecuritySeverity
    
    public init(userId: String,
                eventType: SecurityEventType,
                ipAddress: String? = nil,
                userAgent: String? = nil,
                location: String? = nil,
                details: [String: String] = [:],
                severity: SecuritySeverity = .low) {
        self.userId = userId
        self.eventType = eventType
        self.timestamp = Date()
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.location = location
        self.details = details
        self.severity = severity
    }
}

// MARK: - Security Event Type
public enum SecurityEventType: String, Codable, CaseIterable {
    case login = "login"
    case logout = "logout"
    case passwordChange = "password_change"
    case emailChange = "email_change"
    case mfaEnabled = "mfa_enabled"
    case mfaDisabled = "mfa_disabled"
    case biometricEnabled = "biometric_enabled"
    case biometricDisabled = "biometric_disabled"
    case suspiciousLogin = "suspicious_login"
    case accountLocked = "account_locked"
    case passwordReset = "password_reset"
    case deviceRegistered = "device_registered"
    case deviceUnregistered = "device_unregistered"
    case permissionChanged = "permission_changed"
    
    public var displayName: String {
        switch self {
        case .login: return "Login"
        case .logout: return "Logout"
        case .passwordChange: return "Password Change"
        case .emailChange: return "Email Change"
        case .mfaEnabled: return "MFA Enabled"
        case .mfaDisabled: return "MFA Disabled"
        case .biometricEnabled: return "Biometric Enabled"
        case .biometricDisabled: return "Biometric Disabled"
        case .suspiciousLogin: return "Suspicious Login"
        case .accountLocked: return "Account Locked"
        case .passwordReset: return "Password Reset"
        case .deviceRegistered: return "Device Registered"
        case .deviceUnregistered: return "Device Unregistered"
        case .permissionChanged: return "Permission Changed"
        }
    }
}

// MARK: - Security Severity
public enum SecuritySeverity: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - Security Issue
public struct SecurityIssue: Codable {
    public let type: SecurityIssueType
    public let description: String
    public let severity: SecuritySeverity
    public let details: [String: String]
    public let reportedAt: Date
    public let userId: String?
    
    public init(type: SecurityIssueType,
                description: String,
                severity: SecuritySeverity,
                details: [String: String] = [:],
                userId: String? = nil) {
        self.type = type
        self.description = description
        self.severity = severity
        self.details = details
        self.reportedAt = Date()
        self.userId = userId
    }
}

// MARK: - Security Issue Type
public enum SecurityIssueType: String, Codable, CaseIterable {
    case suspiciousActivity = "suspicious_activity"
    case phishingAttempt = "phishing_attempt"
    case dataBreachSuspicion = "data_breach_suspicion"
    case maliciousContent = "malicious_content"
    case privacyViolation = "privacy_violation"
    case other = "other"
    
    public var displayName: String {
        switch self {
        case .suspiciousActivity: return "Suspicious Activity"
        case .phishingAttempt: return "Phishing Attempt"
        case .dataBreachSuspicion: return "Data Breach Suspicion"
        case .maliciousContent: return "Malicious Content"
        case .privacyViolation: return "Privacy Violation"
        case .other: return "Other"
        }
    }
}

// MARK: - Login Event
public struct LoginEvent: Identifiable, Codable {
    public let id = UUID()
    public let userId: String
    public let timestamp: Date
    public let ipAddress: String
    public let userAgent: String
    public let location: String?
    public let deviceInfo: DeviceInfo
    public let success: Bool
    public let failureReason: String?
    
    public init(userId: String,
                ipAddress: String,
                userAgent: String,
                location: String? = nil,
                deviceInfo: DeviceInfo,
                success: Bool,
                failureReason: String? = nil) {
        self.userId = userId
        self.timestamp = Date()
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.location = location
        self.deviceInfo = deviceInfo
        self.success = success
        self.failureReason = failureReason
    }
}

// MARK: - Account Export Data
public struct AccountExportData: Codable {
    public let userId: String
    public let email: String
    public let profile: UserProfile?
    public let authHistory: [SecurityEvent]
    public let loginHistory: [LoginEvent]
    public let deviceRegistrations: [DeviceRegistration]
    public let exportDate: Date
    public let dataVersion: String
    
    public init(userId: String,
                email: String,
                profile: UserProfile? = nil,
                authHistory: [SecurityEvent] = [],
                loginHistory: [LoginEvent] = [],
                deviceRegistrations: [DeviceRegistration] = []) {
        self.userId = userId
        self.email = email
        self.profile = profile
        self.authHistory = authHistory
        self.loginHistory = loginHistory
        self.deviceRegistrations = deviceRegistrations
        self.exportDate = Date()
        self.dataVersion = "1.0"
    }
}

// MARK: - Auth Service Errors
public enum AuthServiceError: LocalizedError, Equatable {
    case invalidCredentials
    case userNotFound
    case userDisabled
    case emailAlreadyInUse
    case weakPassword
    case emailNotVerified
    case phoneNotVerified
    case mfaRequired
    case invalidMFACode
    case biometricNotAvailable
    case biometricNotEnrolled
    case biometricAuthFailed
    case sessionExpired
    case sessionInvalid
    case permissionDenied(permission: Permission)
    case accountLocked(until: Date?)
    case tooManyAttempts(retryAfter: Date)
    case networkError(underlying: Error)
    case providerError(provider: SocialProvider, underlying: Error)
    case unknown(underlying: Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "User not found"
        case .userDisabled:
            return "User account has been disabled"
        case .emailAlreadyInUse:
            return "Email address is already in use"
        case .weakPassword:
            return "Password is too weak"
        case .emailNotVerified:
            return "Email address not verified"
        case .phoneNotVerified:
            return "Phone number not verified"
        case .mfaRequired:
            return "Multi-factor authentication required"
        case .invalidMFACode:
            return "Invalid MFA code"
        case .biometricNotAvailable:
            return "Biometric authentication not available"
        case .biometricNotEnrolled:
            return "Biometric authentication not enrolled"
        case .biometricAuthFailed:
            return "Biometric authentication failed"
        case .sessionExpired:
            return "Session has expired"
        case .sessionInvalid:
            return "Session is invalid"
        case .permissionDenied(let permission):
            return "Permission denied: \(permission.displayName)"
        case .accountLocked(let until):
            if let until = until {
                return "Account locked until \(until)"
            } else {
                return "Account is locked"
            }
        case .tooManyAttempts(let retryAfter):
            return "Too many attempts. Try again after \(retryAfter)"
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .providerError(let provider, let underlying):
            return "\(provider.displayName) error: \(underlying.localizedDescription)"
        case .unknown(let underlying):
            return "Unknown error: \(underlying.localizedDescription)"
        }
    }
    
    public static func == (lhs: AuthServiceError, rhs: AuthServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidCredentials, .invalidCredentials),
             (.userNotFound, .userNotFound),
             (.userDisabled, .userDisabled),
             (.emailAlreadyInUse, .emailAlreadyInUse),
             (.weakPassword, .weakPassword),
             (.emailNotVerified, .emailNotVerified),
             (.phoneNotVerified, .phoneNotVerified),
             (.mfaRequired, .mfaRequired),
             (.invalidMFACode, .invalidMFACode),
             (.biometricNotAvailable, .biometricNotAvailable),
             (.biometricNotEnrolled, .biometricNotEnrolled),
             (.biometricAuthFailed, .biometricAuthFailed),
             (.sessionExpired, .sessionExpired),
             (.sessionInvalid, .sessionInvalid):
            return true
        case (.permissionDenied(let lhsPermission), .permissionDenied(let rhsPermission)):
            return lhsPermission == rhsPermission
        case (.accountLocked(let lhsUntil), .accountLocked(let rhsUntil)):
            return lhsUntil == rhsUntil
        case (.tooManyAttempts(let lhsRetryAfter), .tooManyAttempts(let rhsRetryAfter)):
            return lhsRetryAfter == rhsRetryAfter
        case (.providerError(let lhsProvider, _), .providerError(let rhsProvider, _)):
            return lhsProvider == rhsProvider
        default:
            return false
        }
    }
}