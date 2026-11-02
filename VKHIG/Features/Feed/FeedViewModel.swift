import Foundation
import Observation

@MainActor
@Observable
final class FeedViewModel {
    private let environment: AppEnvironment

    var state: LoadState<[FeedPost]> = .idle
    var isLoadingMore = false
    var reachedEnd = false
    var pageError: String?
    var usesFixtures = false
    var filter = "Для вас"

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func load() async {
        reachedEnd = false
        pageError = nil
        state = .loading
        usesFixtures = environment.dataMode == .fixtures && !environment.isLiveVKSession

        let token = await environment.liveAPIGate.accessTokenIfLiveReady()
        let result = await environment.feedRepository.fetchFeed(
            dataMode: environment.dataMode,
            capabilities: environment.capabilities,
            isNetworkReachable: environment.isNetworkReachable,
            accessToken: token
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
    func loadMore() async {
        guard !isLoadingMore, !reachedEnd, case .loaded(let current) = state else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let token = await environment.liveAPIGate.accessTokenIfLiveReady()
        let result = await environment.feedRepository.fetchFeed(dataMode:environment.dataMode, capabilities:environment.capabilities, isNetworkReachable:environment.isNetworkReachable, accessToken:token, reset:false)
        switch result {
        case .success(let page):
            var seen = Set(current.map(\.id))
            let new = page.filter { seen.insert($0.id).inserted }
            reachedEnd = new.isEmpty
            state = .loaded(current + new)
        case .failure(let error): pageError = error.localizedDescription
        }
    }

}
