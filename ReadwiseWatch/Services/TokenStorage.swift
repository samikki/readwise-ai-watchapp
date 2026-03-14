import Foundation
import Security

enum TokenStorage {
    private static let service = "fi.pinseri.ReadwiseBriefing.watchkitapp"
    private static let account = "readwise-api-token"

    /// Get the Readwise API token. Checks Keychain first, falls back to Secrets.swift.
    static func getToken() -> String? {
        if let keychainToken = getFromKeychain(), !keychainToken.isEmpty {
            return keychainToken
        }
        let hardcoded = Secrets.readwiseToken
        return hardcoded.isEmpty ? nil : hardcoded
    }

    static func saveToken(_ token: String) {
        deleteFromKeychain()
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static var hasToken: Bool {
        getToken() != nil
    }

    // MARK: - Private

    private static func getFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
