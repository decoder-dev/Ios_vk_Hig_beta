import Foundation
protocol VKTokenProviding: Sendable {
    func accessToken() async -> String?
}
struct KeychainVKTokenProvider: VKTokenProviding {
    func accessToken() async -> String? { await VKIDAuthCoordinator.shared.freshAccessToken() }
}
