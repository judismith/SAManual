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
    func signInWithApple() async throws -> AuthUser
    func signInWithGoogle() async throws -> AuthUser
    func signOut() async throws
    
    // MARK: - Additional Methods (simplified for now)
    func signUp(email: String, password: String, profile: UserRegistrationProfile) async throws -> AuthUser
    func resetPassword(email: String) async throws
    func changePassword(currentPassword: String, newPassword: String) async throws
    func updateEmail(newEmail: String, password: String) async throws -> AuthUser
    func linkGoogleAccount() async throws -> AuthUser
    func linkAppleAccount() async throws -> AuthUser
    func unlinkSocialAccount(provider: SocialProvider) async throws -> AuthUser
    func sendEmailVerification() async throws
    func verifyEmail(code: String) async throws -> AuthUser
    func isEmailVerified() async throws -> Bool
    func sendPhoneVerification(phoneNumber: String) async throws
    func verifyPhone(code: String) async throws -> AuthUser
    func enableMFA() async throws -> MFASetupResult
    func disableMFA(password: String) async throws
    func verifyMFA(code: String) async throws -> AuthUser
    func generateBackupCodes() async throws -> [String]
    func getMFAStatus() async throws -> MFAStatus
    func enableBiometricAuth() async throws -> BiometricAuthResult
    func disableBiometricAuth() async throws
    func authenticateWithBiometrics() async throws -> AuthUser
    func isBiometricAuthAvailable() async throws -> BiometricAvailability
    func getBiometricAuthStatus() async throws -> BiometricAuthStatus
    func refreshToken() async throws -> AuthToken
    func validateSession() async throws -> Bool
    func getSessionInfo() async throws -> SessionInfo
    func terminateAllSessions() async throws
    func terminateSession(sessionId: String) async throws
    func getActiveSessions() async throws -> [SessionInfo]
    func deleteAccount(password: String) async throws
    func deactivateAccount(password: String) async throws
    func reactivateAccount(email: String, password: String) async throws -> AuthUser
    func exportAccountData() async throws -> AccountExportData
    func checkPermission(_ permission: Permission) async throws -> Bool
    func requestPermission(_ permission: Permission) async throws -> PermissionResult
    func getUserRoles() async throws -> [UserRole]
    func updateUserRole(userId: String, role: UserRole) async throws
    func getSecurityEvents(limit: Int) async throws -> [SecurityEvent]
    func reportSecurityIssue(_ issue: SecurityIssue) async throws
    func getLoginHistory(limit: Int) async throws -> [LoginEvent]
    func registerDevice(_ device: DeviceInfo) async throws -> DeviceRegistration
    func unregisterDevice(deviceId: String) async throws
    func getRegisteredDevices() async throws -> [DeviceRegistration]
    func updateDeviceInfo(_ device: DeviceInfo) async throws -> DeviceRegistration
}

// MARK: - Auth User
public struct AuthUser: Identifiable, Codable {
    public let id: String
    public let email: String
    public let displayName: String?
    
    public init(id: String, email: String, displayName: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
    }
}

// MARK: - Auth State (using domain AuthState)
// AuthState is defined in the domain layer (AuthenticationUseCase.swift)

// MARK: - User Registration Profile
public struct UserRegistrationProfile: Codable {
    public let firstName: String
    public let lastName: String
    
    public init(firstName: String, lastName: String) {
        self.firstName = firstName
        self.lastName = lastName
    }
}

// MARK: - Social Provider
public enum SocialProvider: String, Codable, CaseIterable {
    case google = "google"
    case apple = "apple"
    case facebook = "facebook"
}

// MARK: - Supporting Types (simplified)
public struct MFASetupResult: Codable {
    public let secret: String
    public let qrCodeURL: String
    
    public init(secret: String, qrCodeURL: String) {
        self.secret = secret
        self.qrCodeURL = qrCodeURL
    }
}

public struct MFAStatus: Codable {
    public let isEnabled: Bool
    
    public init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}

public struct BiometricAuthResult: Codable {
    public let isEnabled: Bool
    
    public init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}

public struct BiometricAvailability: Codable {
    public let isAvailable: Bool
    
    public init(isAvailable: Bool) {
        self.isAvailable = isAvailable
    }
}

public struct BiometricAuthStatus: Codable {
    public let isEnabled: Bool
    
    public init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}

public struct AuthToken: Codable {
    public let accessToken: String
    public let refreshToken: String
    
    public init(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

public struct SessionInfo: Codable {
    public let id: String
    public let userId: String
    
    public init(id: String, userId: String) {
        self.id = id
        self.userId = userId
    }
}

public struct AccountExportData: Codable {
    public let userId: String
    public let email: String
    
    public init(userId: String, email: String) {
        self.userId = userId
        self.email = email
    }
}

public struct Permission: Codable {
    public let name: String
    
    public init(name: String) {
        self.name = name
    }
}

public struct PermissionResult: Codable {
    public let granted: Bool
    
    public init(granted: Bool) {
        self.granted = granted
    }
}

public struct UserRole: Codable {
    public let name: String
    
    public init(name: String) {
        self.name = name
    }
}

public struct SecurityEvent: Codable {
    public let id: String
    public let userId: String
    
    public init(id: String, userId: String) {
        self.id = id
        self.userId = userId
    }
}

public struct SecurityIssue: Codable {
    public let description: String
    
    public init(description: String) {
        self.description = description
    }
}

public struct LoginEvent: Codable {
    public let id: String
    public let userId: String
    
    public init(id: String, userId: String) {
        self.id = id
        self.userId = userId
    }
}

public struct DeviceInfo: Codable {
    public let id: String
    public let name: String
    
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct DeviceRegistration: Codable {
    public let id: String
    public let userId: String
    
    public init(id: String, userId: String) {
        self.id = id
        self.userId = userId
    }
}

// MARK: - Auth Service Errors
public enum AuthServiceError: LocalizedError {
    case invalidCredentials
    case userNotFound
    case networkError(underlying: Error)
    case unknown(underlying: Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "User not found"
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .unknown(let underlying):
            return "Unknown error: \(underlying.localizedDescription)"
        }
    }
} 