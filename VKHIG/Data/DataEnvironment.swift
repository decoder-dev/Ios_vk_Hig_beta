import Foundation

/// Controls whether repositories may serve Preview/Test fixtures.
/// Production UI must never present fixtures as a successful live VK session.
enum DataMode: String, Sendable {
    /// Bundled fictitious data for UI development / offline demos.
    case fixtures
    /// Live VK API (requires credentials + verified scopes).
    case live
}

@MainActor
@Observable
final class AppEnvironment {
    /// Mirrored auth flag so SwiftUI Observation invalidates the root reliably.
    private(set) var isAuthenticated = false
    private(set) var isLiveVKSession = false

    var capabilities: CapabilityRegistry
    var dataMode: DataMode
    var isNetworkReachable: Bool

    let session: SessionStore
    let conversationRepository: ConversationRepository
    let feedRepository: FeedRepository
    let profileRepository: ProfileRepository

    init(
        session: SessionStore = SessionStore(),
        capabilities: CapabilityRegistry = CapabilityRegistry(),
        dataMode: DataMode = .fixtures,
        isNetworkReachable: Bool = true
    ) {
        self.session = session
        self.capabilities = capabilities
        self.dataMode = dataMode
        self.isNetworkReachable = isNetworkReachable
        let fixtures = FixtureStore.loadBundledOrEmbedded()
        self.conversationRepository = ConversationRepository(fixtures: fixtures)
        self.feedRepository = FeedRepository(fixtures: fixtures)
        self.profileRepository = ProfileRepository(fixtures: fixtures)
        syncAuthFromSession()
    }

    func enterShellWithoutAuth() {
        session.enterShellWithoutAuth()
        dataMode = .fixtures
        syncAuthFromSession()
    }

    func signInWithVKID() async -> Result<Void, VKIDAuthError> {
        let result = await session.signInWithVKID()
        syncAuthFromSession()
        return result
    }

    func signOut() {
        session.signOut()
        syncAuthFromSession()
    }

    private func syncAuthFromSession() {
        isAuthenticated = session.isAuthenticated
        isLiveVKSession = session.isLiveVKSession
    }
}
