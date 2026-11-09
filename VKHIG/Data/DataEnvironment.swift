import Foundation
import Observation
import Combine

/// Controls whether repositories may serve Preview/Test fixtures.
/// Production UI must never present fixtures as a successful live VK session.
enum DataMode: String, Sendable {
    case fixtures
    case live
}

@MainActor
@Observable
final class AppEnvironment {
    private(set) var isAuthenticated = false
    private(set) var isLiveVKSession = false
    private(set) var isSigningOut = false

    var capabilities: CapabilityRegistry
    var dataMode: DataMode
    var isNetworkReachable: Bool

    let catalog = VKCatalogService.shared
    var pendingRoute: AppRoute?
    /// Why the user is back on the sign-in screen (confirmed expired session), shown there once.
    var sessionNotice: String?

    let session: SessionStore
    let conversationRepository: ConversationRepository
    let feedRepository: FeedRepository
    let profileRepository: ProfileRepository
    let apiClient: VKAPIClient
    let tokenProvider: KeychainVKTokenProvider
    let liveAPIGate: LiveAPIGate
    @ObservationIgnored private var accountObserver: AnyCancellable?
    @ObservationIgnored private var expiryObserver: AnyCancellable?

    init(
        session: SessionStore? = nil,
        capabilities: CapabilityRegistry = CapabilityRegistry(),
        dataMode: DataMode = .fixtures,
        isNetworkReachable: Bool = true
    ) {
        let session = session ?? SessionStore()
        self.session = session
        var caps = capabilities
        caps.hasVKIDCredentials = AppSecrets.hasVKIDCredentials
        self.capabilities = caps
        // Prefer fixtures until a Keychain token exists; credentials alone do not force live.
        self.dataMode = session.isLiveVKSession ? .live : dataMode
        self.isNetworkReachable = isNetworkReachable
        let fixtures = FixtureStore.loadBundledOrEmbedded()
        self.conversationRepository = ConversationRepository(fixtures: fixtures)
        self.feedRepository = FeedRepository(fixtures: fixtures)
        self.profileRepository = ProfileRepository(fixtures: fixtures)
        self.apiClient = VKAPIClient()
        let tokens = KeychainVKTokenProvider()
        self.tokenProvider = tokens
        self.liveAPIGate = LiveAPIGate(
            clientIDConfigured: AppSecrets.hasVKIDCredentials,
            tokenProvider: tokens
        )
        syncAuthFromSession()
        Task { await refreshTokenCapability() }
        accountObserver = NotificationCenter.default.publisher(for: .vkActiveAccountDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.activeAccountDidChange() }
        expiryObserver = NotificationCenter.default.publisher(for: .vkSessionDidExpire)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                let name = (note.object as? String).map { "«\($0)» " } ?? ""
                self?.sessionNotice = "Сессия аккаунта \(name)закончилась: VK отозвал токен. Войдите снова."
            }
        VKAPISession.shared.challengeResolver = VKChallengeCenter.shared
    }

    /// Account added / switched / removed / expired: drop per-account caches and rebuild capabilities.
    private func activeAccountDidChange() {
        session.reconcileWithAccounts()
        catalog.clear()
        AudioLibrary.shared.resetRemoteSession()
        capabilities.hasAccessToken = false
        capabilities.grantedScopes = []
        if !session.isLiveVKSession { dataMode = .fixtures }
        syncAuthFromSession()
        Task { await refreshTokenCapability(); syncAuthFromSession() }
    }

    func enterShellWithoutAuth() {
        session.enterShellWithoutAuth()
        dataMode = .fixtures
        syncAuthFromSession()
    }

    func signInWithVKID() async -> Result<Void, VKIDAuthError> {
        let result = await session.signInWithVKID()
        await refreshTokenCapability()
        syncAuthFromSession()
        return result
    }

    func signOut() {
        guard !isSigningOut else {return}
        isSigningOut=true
        Task {
            finishSignOut()
            isSigningOut=false
        }
    }

    private func finishSignOut() {
        let owner = String(VKSession.currentUserID ?? 0)
        for key in UserDefaults.standard.dictionaryRepresentation().keys where (key.hasPrefix("vkhig.draft.\(owner).") || key.hasPrefix("vkhig.comment.draft.\(owner).")) { UserDefaults.standard.removeObject(forKey:key) }
        UserDefaults.standard.removeObject(forKey:"vkhig.post.draft")
        let directory = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("VKOutbox")
        for file in (try? FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil)) ?? [] where file.lastPathComponent.hasPrefix("\(owner)_") { try? FileManager.default.removeItem(at:file) }
        if let account = VKSession.activeAccount {
            // Only this account signs out; remaining accounts (if any) take over via activeAccountDidChange().
            AccountManager.shared.removeAccount(userId: account.userId)
        } else {
            session.signOut()
        }
        dataMode = .fixtures
        catalog.clear()
        AudioLibrary.shared.resetRemoteSession()
        capabilities.hasAccessToken = false
        syncAuthFromSession()
    }

    func refreshTokenCapability() async {
        let token = await tokenProvider.accessToken()
        capabilities.hasAccessToken = !(token ?? "").isEmpty
        capabilities.hasVKIDCredentials = AppSecrets.hasVKIDCredentials || VKSession.activeAccount != nil
        await VKSession.refreshAccountGrants()
        capabilities.grantedScopes = VKSession.grants
        if capabilities.hasAccessToken {
            // Rights come from the actual OAuth response, never from a guessed allow-list.
            dataMode = .live
            AudioLibrary.shared.setAccount(VKSession.currentUserID)
        } else if session.isLiveVKSession {
            AudioLibrary.shared.resetRemoteSession()
            session.signOut()
            dataMode = .fixtures
            syncAuthFromSession()
        }
    }

    private func syncAuthFromSession() {
        isAuthenticated = session.isAuthenticated
        isLiveVKSession = session.isLiveVKSession
    }
}
