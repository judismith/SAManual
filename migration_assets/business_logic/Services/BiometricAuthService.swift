import Foundation
import LocalAuthentication
import Security

class BiometricAuthService: ObservableObject {
    static let shared = BiometricAuthService()
    
    private let context = LAContext()
    private let keychainService = "com.pjsengineering.samanual.biometric"
    private let keychainAccount = "userCredentials"
    
    @Published var biometricType: LABiometryType = .none
    @Published var isBiometricAvailable = false
    @Published var hasStoredCredentials = false
    
    // Flag to prevent automatic authentication
    private var isAuthenticating = false
    
    private init() {
        print("🔐 [BiometricAuthService] Initializing BiometricAuthService...")
        checkBiometricAvailability()
        checkStoredCredentials()
        print("🔐 [BiometricAuthService] BiometricAuthService initialization complete")
    }
    
    private func checkBiometricAvailability() {
        print("🔐 [BiometricAuthService] Checking biometric availability...")
        
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
            isBiometricAvailable = true
            print("✅ [BiometricAuthService] Biometric authentication available: \(biometricType.description)")
            print("✅ [BiometricAuthService] Biometric type: \(biometricType)")
        } else {
            biometricType = .none
            isBiometricAvailable = false
            print("❌ [BiometricAuthService] Biometric authentication not available")
            print("❌ [BiometricAuthService] Error: \(error?.localizedDescription ?? "Unknown error")")
            print("❌ [BiometricAuthService] Error code: \(error?.code ?? -1)")
        }
    }
    
    private func checkStoredCredentials() {
        hasStoredCredentials = checkForStoredCredentialsWithoutAuth()
        print("🔐 [BiometricAuthService] Has stored credentials: \(hasStoredCredentials)")
    }
    
    // Check for stored credentials without triggering biometric authentication
    private func checkForStoredCredentialsWithoutAuth() -> Bool {
        print("🔐 [BiometricAuthService] Checking for stored credentials without auth...")
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: false, // Don't return the actual data
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock // Use this to avoid biometric prompts
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        let exists = status == errSecSuccess
        print("🔐 [BiometricAuthService] Credentials exist check: \(exists) (status: \(status))")
        return exists
    }
    
    // Public method to refresh stored credentials status
    func refreshStoredCredentialsStatus() {
        print("🔐 [BiometricAuthService] Refreshing stored credentials status...")
        let oldStatus = hasStoredCredentials
        checkStoredCredentials()
        print("🔐 [BiometricAuthService] Stored credentials status changed from \(oldStatus) to \(hasStoredCredentials)")
    }
    
    func authenticateWithBiometrics(completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔐 [BiometricAuthService] authenticateWithBiometrics called")
        print("🔐 [BiometricAuthService] Stack trace: \(Thread.callStackSymbols.prefix(10))")
        
        // Prevent multiple simultaneous authentication attempts
        guard !isAuthenticating else {
            print("❌ [BiometricAuthService] Authentication already in progress")
            completion(.failure(NSError(domain: "BiometricAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication already in progress"])))
            return
        }
        
        isAuthenticating = true
        
        // Create a fresh context for each authentication
        let authContext = LAContext()
        let reason = "Sign in to your account"
        
        authContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                self.isAuthenticating = false
                if success {
                    print("✅ [BiometricAuthService] Biometric authentication successful")
                    completion(.success(()))
                } else {
                    print("❌ [BiometricAuthService] Biometric authentication failed: \(error?.localizedDescription ?? "Unknown error")")
                    completion(.failure(error ?? NSError(domain: "BiometricAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Biometric authentication failed"])))
                }
            }
        }
    }
    
    func saveCredentials(email: String, password: String) -> Bool {
        print("🔐 [BiometricAuthService] Saving credentials to keychain")
        
        // Create a secure credential string (in production, consider hashing)
        let credentials = "\(email):\(password)"
        guard let data = credentials.data(using: .utf8) else {
            print("❌ [BiometricAuthService] Failed to encode credentials")
            return false
        }
        
        // Don't use biometric protection on the keychain item itself
        // We'll use biometric authentication only when retrieving credentials
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock // No biometric protection
        ]
        
        // Delete any existing credentials first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            print("✅ [BiometricAuthService] Credentials saved to keychain without biometric protection")
            DispatchQueue.main.async {
                self.hasStoredCredentials = true
            }
            return true
        } else {
            print("❌ [BiometricAuthService] Failed to save credentials: \(status)")
            return false
        }
    }
    
    func retrieveCredentials() -> (email: String, password: String)? {
        print("🔐 [BiometricAuthService] retrieveCredentials called")
        print("🔐 [BiometricAuthService] Stack trace: \(Thread.callStackSymbols.prefix(5))")
        
        // First check if credentials exist without auth
        guard checkForStoredCredentialsWithoutAuth() else {
            print("❌ [BiometricAuthService] No stored credentials found")
            return nil
        }
        
        // Now retrieve the credentials - this will require biometric authentication
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let credentials = String(data: data, encoding: .utf8) {
            let components = credentials.split(separator: ":", maxSplits: 1)
            if components.count == 2 {
                let email = String(components[0])
                let password = String(components[1])
                print("✅ [BiometricAuthService] Credentials retrieved successfully")
                return (email: email, password: password)
            }
        }
        
        print("❌ [BiometricAuthService] Failed to retrieve credentials: \(status)")
        return nil
    }
    
    func clearCredentials() {
        print("🔐 [BiometricAuthService] Clearing credentials from keychain")
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock // Use this to avoid biometric prompts
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess {
            print("✅ [BiometricAuthService] Credentials cleared from keychain")
            DispatchQueue.main.async {
                self.hasStoredCredentials = false
            }
        } else {
            print("❌ [BiometricAuthService] Failed to clear credentials: \(status)")
        }
    }
    
    func checkForStoredCredentials() -> Bool {
        return hasStoredCredentials
    }
    
    // Check if biometric setup has changed
    func checkBiometricSetupChanged() -> Bool {
        let newContext = LAContext()
        var error: NSError?
        
        if newContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return newContext.biometryType != biometricType
        }
        
        return true // Assume changed if can't evaluate
    }
}

// Extension to provide readable descriptions for biometric types
extension LABiometryType {
    var description: String {
        switch self {
        case .none:
            return "None"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        @unknown default:
            return "Unknown"
        }
    }
} 