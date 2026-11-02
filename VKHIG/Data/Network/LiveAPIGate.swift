import Foundation

/// Activates live VKAPIClient calls only when client id is configured and a token exists.
struct LiveAPIGate: Sendable {
    var clientIDConfigured: Bool
    var tokenProvider: any VKTokenProviding

    func accessTokenIfLiveReady() async -> String? {
        guard clientIDConfigured else { return nil }
        return await tokenProvider.accessToken()
    }
}
