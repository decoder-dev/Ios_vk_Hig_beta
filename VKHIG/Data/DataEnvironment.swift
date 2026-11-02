import Foundation

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

    var capabilities: CapabilityRegistry
    var dataMode: DataMode
    var isNetworkReachable: Bool

    let session: SessionStore
    let conversationRepository: ConversationRepository
    let feedRepository: FeedRepository
    let profileRepository: ProfileRepository
    let apiClient: VKAPIClient
    let tokenProvider: KeychainVKTokenProvider
    let liveAPIGate: LiveAPIGate

    init(
        session: SessionStore = SessionStore(),
        capabilities: CapabilityRegistry = CapabilityRegistry(),
        dataMode: DataMode = .fixtures,
        isNetworkReachable: Bool = true
    ) {
        self.session = session
        var caps = capabilities
        caps.hasVKIDCredentials = AppSecrets.hasVKIDCredentials
        self.capabilities = caps
        // Prefer fixtures until a Keychain token exists; credentials alone do not force live.
        self.dataMode = dataMode
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
    }

    func enterShellWithoutAuth() {
        session.enterShellWithoutAuth()
        dataMode = .fixtures
        syncAuthFromSession()
    }

    func signInWithVKID() async -> Result<Void, VKIDAuthError> {
        let result = await session.signInWithVKID()
        syncAuthFromSession()
        await refreshTokenCapability()
        return result
    }

    func signOut() {
        session.signOut()
        dataMode = .fixtures
        capabilities.hasAccessToken = false
        syncAuthFromSession()
    }

    func refreshTokenCapability() async {
        let token = await tokenProvider.accessToken()
        capabilities.hasAccessToken = !(token ?? "").isEmpty
        if capabilities.hasAccessToken {
            // Still require explicit verifiedLiveFeatures before live method calls.
            dataMode = .live
        }
    }

    private func syncAuthFromSession() {
        isAuthenticated = session.isAuthenticated
        isLiveVKSession = session.isLiveVKSession
    }
}
