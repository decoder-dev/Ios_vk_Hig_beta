import Foundation
import Observation

@MainActor
@Observable
final class InboxViewModel {
    private let environment: AppEnvironment

    var state: LoadState<[Conversation]> = .idle
    var searchText = ""
    var unreadOnly = false
    var isLoadingMore = false
    var reachedEnd = false
    var pageError: String?
    var usesFixtures = false

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    var visibleConversations: [Conversation] {
        guard case .loaded(let items) = state else { return [] }
        return items.filter { item in
            let matchesText = searchText.isEmpty
                || item.displayName.localizedCaseInsensitiveContains(searchText)
                || item.lastMessagePreview.localizedCaseInsensitiveContains(searchText)
            let matchesUnread = !unreadOnly || item.unreadCount > 0
            return matchesText && matchesUnread
        }
    }

    func load() async {
        reachedEnd = false
        pageError = nil
        state = .loading
        usesFixtures = environment.dataMode == .fixtures && !environment.isLiveVKSession

        let token = await environment.liveAPIGate.accessTokenIfLiveReady()
        let result = await environment.conversationRepository.fetchInbox(
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
        let result = await environment.conversationRepository.fetchInbox(dataMode:environment.dataMode, capabilities:environment.capabilities, isNetworkReachable:environment.isNetworkReachable, accessToken:token, offset:current.count)
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
