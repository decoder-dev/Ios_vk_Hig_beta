import Foundation
import Combine

@MainActor
protocol AccountManagerProtocol: AnyObject {
    var accounts: CurrentValueSubject<[VKAccount], Never> { get }
    var activeAccount: CurrentValueSubject<VKAccount?, Never> { get }

    /// Fetches the profile (users.get), stores the account and makes it active.
    @discardableResult
    func addAccount(token: String, userId: Int64?, secret: String?, tokenType: TokenType,
                    refreshToken: String?) async throws -> VKAccount
    func switchAccount(to userId: Int64)
    func removeAccount(userId: Int64)
    func updateProfileInfo(for userId: Int64) async
}

@MainActor
final class AccountManager: AccountManagerProtocol {
    static let shared = AccountManager()

    let accounts = CurrentValueSubject<[VKAccount], Never>([])
    let activeAccount = CurrentValueSubject<VKAccount?, Never>(nil)

    /// Extra hooks run on every switch (clear dialog caches, restart LongPoll).
    /// The same event is also posted as `.vkActiveAccountDidChange`.
    var sessionResetHandlers: [() -> Void] = []

    private let storage: AccountStoring
    private let api: VKAPISession
    private var bag = Set<AnyCancellable>()

    init(storage: AccountStoring = KeychainAccountStorage(), api: VKAPISession = .shared) {
        self.storage = storage
        self.api = api
        reloadFromStorage()
        applyToAdapter(activeAccount.value)

        api.onSessionExpired
            .receive(on: DispatchQueue.main)
            .sink { [weak self] token in self?.handleSessionExpired(token: token) }
            .store(in: &bag)
    }

    // MARK: AccountManagerProtocol

    @discardableResult
    func addAccount(token: String, userId: Int64?, secret: String?, tokenType: TokenType,
                    refreshToken: String? = nil) async throws -> VKAccount {
        // Validate the token and load the profile before touching the Keychain.
        let profile = try await api.fetchProfile(credentials: VKCredentials(token: token, tokenType: tokenType))
        if let userId, userId != profile.id { throw VKAuthError.invalidCredentials }

        let account = VKAccount(
            userId: profile.id, token: token, secret: secret, tokenType: tokenType,
            refreshToken: refreshToken, firstName: profile.firstName, lastName: profile.lastName,
            avatarUrl: profile.avatarUrl, isActive: true)
        try storage.save(account)
        reloadFromStorage()
        didChangeActive()
        return account
    }

    func switchAccount(to userId: Int64) {
        guard activeAccount.value?.userId != userId,
              (try? storage.setActive(userId: userId)) != nil else { return }
        reloadFromStorage()
        didChangeActive()
    }

    func removeAccount(userId: Int64) {
        let wasActive = activeAccount.value?.userId == userId
        try? storage.remove(userId: userId)
        if wasActive, let next = (try? storage.accounts())?.first {
            _ = try? storage.setActive(userId: next.userId)
        }
        reloadFromStorage()
        if wasActive { didChangeActive() }
    }

    func updateProfileInfo(for userId: Int64) async {
        guard var account = accounts.value.first(where: { $0.userId == userId }),
              let profile = try? await api.fetchProfile(
                credentials: VKCredentials(token: account.token, tokenType: account.tokenType)) else { return }
        account.firstName = profile.firstName
        account.lastName = profile.lastName
        account.avatarUrl = profile.avatarUrl
        try? storage.save(account)
        reloadFromStorage()
        // Same user, same token: no session reset needed.
    }

    // MARK: Private

    private func reloadFromStorage() {
        let list = (try? storage.accounts()) ?? []
        accounts.send(list)
        activeAccount.send(list.first { $0.isActive })
    }

    private func applyToAdapter(_ account: VKAccount?) {
        api.adapter.setCredentials(account.map { VKCredentials(token: $0.token, tokenType: $0.tokenType) })
    }

    private func didChangeActive() {
        applyToAdapter(activeAccount.value)
        sessionResetHandlers.forEach { $0() }
        NotificationCenter.default.post(name: .vkActiveAccountDidChange, object: activeAccount.value?.userId)
    }

    /// error 5 on the active token: drop that account and fall back to the next one (if any).
    private func handleSessionExpired(token: String) {
        guard let expired = activeAccount.value, expired.token == token else { return }
        removeAccount(userId: expired.userId)
    }
}
