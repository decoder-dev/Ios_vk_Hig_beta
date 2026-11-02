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
    var grantedScopes: Set<String> = []
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
            let scope: String
            switch feature {
            case .inbox, .conversation, .sendMessage: scope = "messages"
            case .feed: scope = "wall"
            case .friends: scope = "friends"
            case .communities: scope = "groups"
            case .photos: scope = "photos"
            case .notifications: scope = "notifications"
            default: scope = "vkid.personal_info"
            }
            guard grantedScopes.contains(scope) else { return .needsScopeCheck }
            guard hasAccessToken else { return .needsToken }
            return .enabled
        }
    }

    func canUseLiveAPI(_ feature: FeatureCapability) -> Bool {
        status(for: feature) == .enabled
    }
}
