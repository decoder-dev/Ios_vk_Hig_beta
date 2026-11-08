import Foundation
import Security

struct KeychainStorageError: Error, LocalizedError {
    let status: OSStatus
    var errorDescription: String? { "Keychain error \(status)" }
}

protocol AccountStoring: AnyObject, Sendable {
    func accounts() throws -> [VKAccount]
    func activeAccount() throws -> VKAccount?
    func save(_ account: VKAccount) throws          // upsert; an active account deactivates the others
    func saveAll(_ accounts: [VKAccount]) throws
    func setActive(userId: Int64) throws -> VKAccount?
    func remove(userId: Int64) throws
    func removeAll() throws
}

/// All accounts are stored as one JSON blob in a single generic-password item.
/// Every access is serialized by a lock, so read-modify-write cycles are atomic within the process.
final class KeychainAccountStorage: AccountStoring, @unchecked Sendable {
    private let service: String
    private let account: String
    private let lock = NSLock()

    init(service: String = "com.decoderdev.vkhig.accounts", account: String = "vk-accounts-v1") {
        self.service = service
        self.account = account
    }

    func accounts() throws -> [VKAccount] {
        lock.lock(); defer { lock.unlock() }
        return try readLocked()
    }

    func activeAccount() throws -> VKAccount? {
        try accounts().first { $0.isActive }
    }

    func save(_ account: VKAccount) throws {
        lock.lock(); defer { lock.unlock() }
        var list = try readLocked()
        if account.isActive { list = list.map { var a = $0; a.isActive = false; return a } }
        if let i = list.firstIndex(where: { $0.userId == account.userId }) {
            list[i] = account
        } else {
            list.append(account)
        }
        try writeLocked(normalized(list))
    }

    func saveAll(_ accounts: [VKAccount]) throws {
        lock.lock(); defer { lock.unlock() }
        try writeLocked(normalized(accounts))
    }

    func setActive(userId: Int64) throws -> VKAccount? {
        lock.lock(); defer { lock.unlock() }
        var list = try readLocked()
        guard list.contains(where: { $0.userId == userId }) else { return nil }
        for i in list.indices { list[i].isActive = (list[i].userId == userId) }
        try writeLocked(list)
        return list.first { $0.isActive }
    }

    func remove(userId: Int64) throws {
        lock.lock(); defer { lock.unlock() }
        let list = try readLocked().filter { $0.userId != userId }
        try writeLocked(list)
    }

    func removeAll() throws {
        lock.lock(); defer { lock.unlock() }
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainStorageError(status: status) }
    }

    // MARK: - Private (lock must be held)

    /// At most one active account.
    private func normalized(_ list: [VKAccount]) -> [VKAccount] {
        var seen = false
        return list.map { a in
            var a = a
            if a.isActive { if seen { a.isActive = false } else { seen = true } }
            return a
        }
    }

    private func baseQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    private func readLocked() throws -> [VKAccount] {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainStorageError(status: status) }
        return try JSONDecoder().decode([VKAccount].self, from: data)
    }

    private func writeLocked(_ list: [VKAccount]) throws {
        if list.isEmpty {
            let status = SecItemDelete(baseQuery() as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainStorageError(status: status) }
            return
        }
        let data = try JSONEncoder().encode(list)
        let update = SecItemUpdate(baseQuery() as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw KeychainStorageError(status: update) }
        var item = baseQuery()
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let add = SecItemAdd(item as CFDictionary, nil)
        guard add == errSecSuccess else { throw KeychainStorageError(status: add) }
    }
}
