import Foundation

actor FeedRepository {
    private let fixtures: FixtureStore
    private let apiClient: VKAPIClient

    init(fixtures: FixtureStore, apiClient: VKAPIClient = VKAPIClient()) {
        self.fixtures = fixtures
        self.apiClient = apiClient
    }

    func fetchFeed(
        dataMode: DataMode,
        capabilities: CapabilityRegistry,
        isNetworkReachable: Bool,
        accessToken: String? = nil
    ) async -> Result<[FeedPost], AppError> {
        if !isNetworkReachable { return .failure(.offline) }

        if capabilities.canUseLiveAPI(.feed) {
            guard let accessToken, !accessToken.isEmpty else {
                return .failure(.notAuthenticated)
            }
            return .failure(.capabilityUnavailable("newsfeed.get mapping pending verification"))
        }

        switch dataMode {
        case .fixtures:
            return .success(fixtures.feed)
        case .live:
            if accessToken == nil || accessToken?.isEmpty == true {
                return .failure(.notAuthenticated)
            }
            return .failure(.capabilityUnavailable("Feed requires verified newsfeed/wall scope"))
        }
    }
}
