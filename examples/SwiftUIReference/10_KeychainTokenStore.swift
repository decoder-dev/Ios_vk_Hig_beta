import Foundation
import Security

/// Keychain example. A real app should coordinate refresh-token rotation,
/// multi-account partitioning and logout cache cleanup at a higher layer.
struct VKKeychainTokenStore {
    let service = "com.example.vknative.auth" // CHANGE to your real bundle namespace
    let account = "vk-access-token"

    func save(_ token: String) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var new = query
        new[kSecValueData as String] = Data(token.utf8)
        new[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(new as CFDictionary, nil)
    }

    func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete() -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let code = SecItemDelete(query as CFDictionary)
        return code == errSecItemNotFound ? errSecSuccess : code
    }
}
