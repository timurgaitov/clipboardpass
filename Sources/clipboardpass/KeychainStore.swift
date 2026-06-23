import Foundation
import Security
import LocalAuthentication

/// Stores secrets as generic-password Keychain items in the login keychain,
/// owned by THIS app (an app-scoped ACL means other apps get a confirmation
/// prompt). Reads are gated behind Touch ID in-app.
///
/// Note: true Secure-Enclave / biometric-bound Keychain items require an
/// `application-identifier` entitlement, which needs a Developer ID signing
/// identity + provisioning profile — not possible with the ad-hoc signature
/// used for Homebrew distribution. The biometric check here is therefore
/// enforced by the app, not by the Secure Enclave.
enum KeychainStore {
    static let service = "com.clipboardpass.passwords"

    /// Returns the labels of all stored entries (no secrets are read here).
    static func list() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else { return [] }
        return items
            .compactMap { $0[kSecAttrAccount as String] as? String }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    @discardableResult
    static func add(label: String, secret: String) -> Bool {
        delete(label: label) // upsert
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: label,
            kSecValueData as String: Data(secret.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func delete(label: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: label,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Authenticates with Touch ID (device-password fallback), then reads the
    /// secret. Completion is delivered on the main thread.
    static func secret(label: String, reason: String, completion: @escaping (String?) -> Void) {
        let context = LAContext()
        context.localizedFallbackTitle = "Enter Password"
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
            guard ok else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: label,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            let secret = status == errSecSuccess
                ? (result as? Data).flatMap { String(data: $0, encoding: .utf8) }
                : nil
            DispatchQueue.main.async { completion(secret) }
        }
    }
}
