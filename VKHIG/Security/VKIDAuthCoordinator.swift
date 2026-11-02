import Foundation

/// Official VK ID wiring sketch (S01/S02).
/// Docs: https://github.com/VKCOM/vkid-ios-sdk
///
/// Required from Jessica before live auth works:
/// 1. Own VK ID application (client/app id)
/// 2. Redirect URI / custom URL scheme registered in Info.plist + VK ID console
/// 3. SPM/CocoaPods dependency on VKID iOS SDK
///
/// Forbidden: password fields, scraped cookies, Fenrir/Phoenix keys, private APIs.
struct VKIDConfiguration: Sendable {
    /// Placeholder — replace with Jessica's app id; never commit secrets.
    var clientID: String?
    var redirectURLScheme: String?

    var isConfigured: Bool {
        guard let clientID, !clientID.isEmpty,
              let redirectURLScheme, !redirectURLScheme.isEmpty else { return false }
        return true
    }
}

enum VKIDAuthError: Error, LocalizedError, Equatable {
    case missingCredentials
    case sdkNotLinked
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "VK ID client id / redirect URI not configured"
        case .sdkNotLinked:
            return "VKID iOS SDK is not linked yet"
        case .cancelled:
            return "Sign-in cancelled"
        case .failed(let message):
            return message
        }
    }
}

@MainActor
final class VKIDAuthCoordinator {
    private let configuration: VKIDConfiguration
    private let tokenStore: KeychainTokenStore

    init(
        configuration: VKIDConfiguration = VKIDConfiguration(),
        tokenStore: KeychainTokenStore = KeychainTokenStore()
    ) {
        self.configuration = configuration
        self.tokenStore = tokenStore
    }

    var isConfigured: Bool { configuration.isConfigured }

    /// Starts official VK ID authorize flow once SDK + credentials exist.
    func authorize() async -> Result<Void, VKIDAuthError> {
        guard configuration.isConfigured else {
            return .failure(.missingCredentials)
        }
        // TODO(Stage 2 live):
        // 1. Add VKID package product to the Xcode target.
        // 2. Create VKID configuration with clientID + redirect.
        // 3. Present authorize UI from the SDK (OAuth 2.1 + PKCE).
        // 4. On success, store access/refresh tokens via `tokenStore` (never UserDefaults).
        // 5. Handle URL callbacks in the app delegate / onOpenURL.
        return .failure(.sdkNotLinked)
    }

    func restoreSessionIfPossible() -> Bool {
        // Presence of a Keychain token is not enough for messages scopes —
        // CapabilityRegistry still gates each feature.
        tokenStore.load() != nil
    }

    func clearSession() {
        tokenStore.delete()
    }
}
