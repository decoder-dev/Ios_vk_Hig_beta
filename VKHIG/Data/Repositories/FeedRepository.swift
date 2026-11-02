import Foundation

actor FeedRepository {
    private let fixtures: FixtureStore

    init(fixtures: FixtureStore) {
        self.fixtures = fixtures
    }

    func fetchFeed(
        dataMode: DataMode,
        capabilities: CapabilityRegistry,
        isNetworkReachable: Bool
    ) async -> Result<[FeedPost], AppError> {
        if !isNetworkReachable { return .failure(.offline) }

        if capabilities.canUseLiveAPI(.feed) {
            return .failure(.capabilityUnavailable("newsfeed.get"))
        }

        switch dataMode {
        case .fixtures:
            return .success(fixtures.feed)
        case .live:
            return .failure(.capabilityUnavailable("Feed requires verified newsfeed/wall scope"))
        }
    }
}
