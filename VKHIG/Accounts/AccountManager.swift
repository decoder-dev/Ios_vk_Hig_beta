import Foundation
import Combine

@MainActor
protocol AccountManagerProtocol: AnyObject {
    var accounts: CurrentValueSubject<[VKAccount], Never> { get }
    var activeAccount: CurrentValueSubject<VKAccount?, Never> { get }

    /// Fetches the profile (users.get), stores the account and makes it active.
    @discardableResult
    func addAccount(token: String, userId: Int64?, secret: String?, tokenType: TokenType,
                    accountType: VKAccountType?, refreshToken: String?) async throws -> VKAccount
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
    private var verifyingExpiredToken: String?

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
                    accountType: VKAccountType? = nil, refreshToken: String? = nil) async throws -> VKAccount {
        // Validate the token and load the profile before touching the Keychain.
        let creds = VKCredentials(token: token, tokenType: tokenType, secret: secret, accountType: accountType)
        let profile: VKUserProfile?
        do {
            // No captcha sheet here: sign-in already runs inside its own sheet, a second one could not appear.
            profile = try await api.fetchProfile(credentials: creds, allowChallengeRetry: false)
        } catch VKAuthError.tokenRevoked {
            throw VKAuthError.tokenRevoked
        } catch {
            // A fresh grant already names its user; a network blip or captcha on users.get must not throw the
            // token away (the user would have to repeat password + 2FA). Pasted tokens without a user id still
            // have to validate.
            guard userId != nil else { throw error }
            profile = nil
        }
        if let userId, let profile, userId != profile.id { throw VKAuthError.invalidCredentials }
        guard let resolvedID = profile?.id ?? userId else { throw VKAuthError.parsingError }

        let account = VKAccount(
            userId: resolvedID, token: token, secret: secret, tokenType: tokenType, accountType: accountType,
            refreshToken: refreshToken, firstName: profile?.firstName ?? "Аккаунт",
            lastName: profile?.lastName ?? "VK \(resolvedID)",
            avatarUrl: profile?.avatarUrl, isActive: true)
        try storage.save(account)
        reloadFromStorage()
        didChangeActive()
        if profile == nil { Task { await updateProfileInfo(for: resolvedID) } }
        return account
    }

    func switchAccount(to userId: Int64) {
        guard activeAccount.value?.userId != userId,
              (try? storage.setActive(userId: userId)) != nil else { return }
        reloadFromStorage()
        didChangeActive()
    }

    func removeAccount(userId: Int64) {
        VKSession.forgetCachedGrants(userId: userId)
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
                credentials: VKCredentials(token: account.token, tokenType: account.tokenType,
                                           secret: account.secret, accountType: account.accountType)) else { return }
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
        api.adapter.setCredentials(account.map {
            VKCredentials(token: $0.token, tokenType: $0.tokenType, secret: $0.secret, accountType: $0.accountType)
        })
    }

    private func didChangeActive() {
        applyToAdapter(activeAccount.value)
        sessionResetHandlers.forEach { $0() }
        NotificationCenter.default.post(name: .vkActiveAccountDidChange, object: activeAccount.value?.userId)
    }

    /// error 5 on the active token. One method answering 5 is not proof the session is gone, so the token is
    /// re-checked with users.get first; only a confirmed revocation removes the account (network errors keep it).
    private func handleSessionExpired(token: String) {
        guard let expired = activeAccount.value, expired.token == token, verifyingExpiredToken != token else { return }
        verifyingExpiredToken = token
        let creds = VKCredentials(token: expired.token, tokenType: expired.tokenType,
                                  secret: expired.secret, accountType: expired.accountType)
        Task { [weak self] in
            guard let self else { return }
            defer { self.verifyingExpiredToken = nil }
            do {
                _ = try await self.api.fetchProfile(credentials: creds)
            } catch VKAuthError.tokenRevoked {
                guard self.activeAccount.value?.token == token else { return }
                NotificationCenter.default.post(name: .vkSessionDidExpire, object: expired.displayName)
                self.removeAccount(userId: expired.userId)
            } catch {
                // Offline or captcha: keep the account, the next request will tell.
            }
        }
    }
}
