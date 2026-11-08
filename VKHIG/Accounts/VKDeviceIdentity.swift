import Foundation
import Security
import CryptoKit

/// Stable per-install `device_id` VK expects on every password-grant request so a trusted device
/// isn't asked for 2FA again. Not secret, so UserDefaults is enough; it must simply never change.
enum VKDeviceIdentity {
    private static let key = "vkhig.auth.device_id"

    static var current: String {
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty { return existing }
        let generated = UUID().uuidString.lowercased()
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}

/// `trusted_hash` lets a later login on this device skip the 2FA challenge again. It is scoped to
/// (client, login) and stored separately from `KeychainAccountStorage` so a normal sign-out — which
/// removes the `VKAccount` — does not throw it away and force another SMS/app code next time.
final class TrustedHashStore: @unchecked Sendable {
    static let shared = TrustedHashStore()

    private let service = "com.decoderdev.vkhig.trusted-hash"
    private let lock = NSLock()

    func hash(clientId: String, username: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        var query = baseQuery(account: account(clientId: clientId, username: username))
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func save(_ hash: String, clientId: String, username: String) {
        lock.lock(); defer { lock.unlock() }
        guard !hash.isEmpty else { return }
        let acc = account(clientId: clientId, username: username)
        let data = Data(hash.utf8)
        let query = baseQuery(account: acc)
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    /// Only called from an explicit "forget this device" action — never from ordinary sign-out.
    func forget(clientId: String, username: String) {
        lock.lock(); defer { lock.unlock() }
        SecItemDelete(baseQuery(account: account(clientId: clientId, username: username)) as CFDictionary)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    /// The login is hashed rather than kept as a readable Keychain attribute.
    private func account(clientId: String, username: String) -> String {
        let digest = SHA256.hash(data: Data("\(clientId):\(username.lowercased())".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
