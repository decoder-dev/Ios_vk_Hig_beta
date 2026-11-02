import Foundation

/// Official VK ID wiring (S01/S02). Prefer OAuth 2.1 + PKCE public client.
/// Docs: https://github.com/VKCOM/vkid-ios-sdk
///
/// Register in VK ID cabinet:
/// - Client id: from gitignored Secrets / GitHub secret `VK_ID_CLIENT_ID`
/// - Redirect URI: `vkhig://vkid` (scheme `vkhig` in Info.plist)
///
/// Do **not** ship `VK_ID_CLIENT_SECRET` inside the iOS binary.
struct VKIDConfiguration: Sendable {
    var clientID: String?
    var redirectURLScheme: String?

    var isConfigured: Bool {
        guard let clientID, !clientID.isEmpty, clientID != "YOUR_VK_ID_CLIENT_ID",
              let redirectURLScheme, !redirectURLScheme.isEmpty else { return false }
        return true
    }

    var redirectURI: String {
        "\(redirectURLScheme ?? "vkhig")://vkid"
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
            return "VK ID client id not configured"
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
        configuration: VKIDConfiguration = VKIDConfiguration(
            clientID: AppSecrets.hasVKIDCredentials ? AppSecrets.vkClientID : nil,
            redirectURLScheme: AppSecrets.vkRedirectScheme
        ),
        tokenStore: KeychainTokenStore = KeychainTokenStore()
    ) {
        self.configuration = configuration
        self.tokenStore = tokenStore
    }

    var isConfigured: Bool { configuration.isConfigured }
    var redirectURI: String { configuration.redirectURI }

    func authorize() async -> Result<Void, VKIDAuthError> {
        guard configuration.isConfigured else {
            return .failure(.missingCredentials)
        }
        // TODO(Mac): Add VKID SPM package; present authorize UI (PKCE).
        // On success, store access token via `tokenStore` — never log it.
        // Client secret must not be used in-app if the app is a public PKCE client.
        return .failure(.sdkNotLinked)
    }

    func restoreSessionIfPossible() -> Bool {
        tokenStore.load() != nil
    }

    func clearSession() {
        tokenStore.delete()
    }
}
