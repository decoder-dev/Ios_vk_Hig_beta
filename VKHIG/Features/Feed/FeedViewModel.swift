import Foundation

@MainActor
@Observable
final class FeedViewModel {
    private let environment: AppEnvironment

    var state: LoadState<[FeedPost]> = .idle
    var usesFixtures = false
    var filter = "Для вас"

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func load() async {
        state = .loading
        usesFixtures = environment.dataMode == .fixtures && !environment.isLiveVKSession

        let result = await environment.feedRepository.fetchFeed(
            dataMode: environment.dataMode,
            capabilities: environment.capabilities,
            isNetworkReachable: environment.isNetworkReachable
        )
        switch result {
        case .success(let items):
            state = items.isEmpty ? .empty : .loaded(items)
        case .failure(.offline):
            state = .offline
        case .failure(let error):
            state = .failed(error)
        }
    }
}
