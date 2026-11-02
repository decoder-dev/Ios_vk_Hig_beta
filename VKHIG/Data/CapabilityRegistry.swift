import Foundation

/// Gates features by official capability — never unlock private/scraped APIs.
enum FeatureCapability: String, CaseIterable, Sendable {
    case vkIDSignIn
    case profile
    case inbox
    case conversation
    case sendMessage
    case feed
    case friends
    case communities
    case photos
    case video
    case music
    case notifications
}

enum CapabilityStatus: String, Sendable {
    case enabled
    case needsConfig
    case needsScopeCheck
    case needsToken
    case unavailable
    case blocked
}

struct CapabilityRegistry: Sendable {
    var hasVKIDCredentials: Bool
    var hasAccessToken: Bool
    /// Explicit allow-list after docs/scope verification. Empty = nothing live.
    var verifiedLiveFeatures: Set<FeatureCapability>

    init(
        hasVKIDCredentials: Bool = AppSecrets.hasVKIDCredentials,
        hasAccessToken: Bool = false,
        verifiedLiveFeatures: Set<FeatureCapability> = []
    ) {
        self.hasVKIDCredentials = hasVKIDCredentials
        self.hasAccessToken = hasAccessToken
        self.verifiedLiveFeatures = verifiedLiveFeatures
    }

    func status(for feature: FeatureCapability) -> CapabilityStatus {
        switch feature {
        case .vkIDSignIn:
            // SDK still must be linked on Mac; credentials alone are not enough to sign in.
            return hasVKIDCredentials ? .needsConfig : .needsConfig
        case .music:
            return .unavailable
        case .video:
            return .needsScopeCheck
        case .inbox, .conversation, .sendMessage, .feed, .profile, .friends, .communities, .photos, .notifications:
            guard hasVKIDCredentials else { return .needsConfig }
            guard verifiedLiveFeatures.contains(feature) else { return .needsScopeCheck }
            guard hasAccessToken else { return .needsToken }
            return .enabled
        }
    }

    func canUseLiveAPI(_ feature: FeatureCapability) -> Bool {
        status(for: feature) == .enabled
    }
}
