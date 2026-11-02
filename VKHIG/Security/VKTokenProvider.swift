import Foundation

/// Supplies access tokens once VK ID completes. Empty until a real session exists.
protocol VKTokenProviding: Sendable {
    func accessToken() async -> String?
}

struct KeychainVKTokenProvider: VKTokenProviding {
    private let store: KeychainTokenStore

    init(store: KeychainTokenStore = KeychainTokenStore()) {
        self.store = store
    }

    func accessToken() async -> String? {
        store.load()
    }
}
