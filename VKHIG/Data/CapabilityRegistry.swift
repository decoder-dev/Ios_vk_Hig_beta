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
    case unavailable
    case blocked
}

struct CapabilityRegistry: Sendable {
    /// Until Jessica supplies VK ID credentials + verified scopes, live calls stay gated.
    var hasVKIDCredentials: Bool = false
    var hasAccessToken: Bool = false
    /// Explicit allow-list after docs/scope verification. Empty = nothing live.
    var verifiedLiveFeatures: Set<FeatureCapability> = []

    func status(for feature: FeatureCapability) -> CapabilityStatus {
        switch feature {
        case .vkIDSignIn:
            return hasVKIDCredentials ? .needsConfig : .needsConfig
        case .music:
            return .unavailable
        case .video:
            return .needsScopeCheck
        case .inbox, .conversation, .sendMessage, .feed, .profile, .friends, .communities, .photos, .notifications:
            if verifiedLiveFeatures.contains(feature), hasAccessToken {
                return .enabled
            }
            if !hasVKIDCredentials {
                return .needsConfig
            }
            return .needsScopeCheck
        }
    }

    func canUseLiveAPI(_ feature: FeatureCapability) -> Bool {
        status(for: feature) == .enabled
    }
}
