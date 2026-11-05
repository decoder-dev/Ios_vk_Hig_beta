import Foundation

/// Reads VK ID **public** client configuration for the app binary.
///
/// - Client id: from env (`VK_ID_CLIENT_ID` / `VK_CLIENT_ID`), Info.plist, or build settings.
/// - Client secret: **never** loaded into the app process for shipping builds.
///   Keep it in gitignored `Secrets.xcconfig` and GitHub Actions `VK_ID_CLIENT_SECRET`
///   for backend/CI only (confidential token exchange). Prefer VK ID OAuth + PKCE.
enum AppSecrets {
    /// Official VK ID application client id (public).
    static var vkClientID: String {
        string(for: "VK_ID_CLIENT_ID")
            .or(string(for: "VK_CLIENT_ID"))
    }

    static var vkRedirectScheme: String {
        string(for: "VK_REDIRECT_SCHEME", fallback: "vkhig")
    }

    static var vkRedirectHost: String {
        string(for: "VK_REDIRECT_HOST", fallback: "vkid")
    }

    static var vkRedirectPath: String {
        string(for: "VK_REDIRECT_PATH")
    }

    /// Must equal the trusted Redirect URL in the VK ID cabinet exactly.
    static var vkRedirectURI: String {
        "\(vkRedirectScheme)://\(vkRedirectHost)\(vkRedirectPath)"
    }

    static var requestedScopes: String { string(for: "VK_REQUESTED_SCOPES", fallback: "vkid.personal_info") }

    static var vkAPIVersion: String {
        string(for: "VK_API_VERSION", fallback: "5.199")
    }

    static var hasVKIDCredentials: Bool {
        let id = vkClientID
        return !id.isEmpty && id != "YOUR_VK_ID_CLIENT_ID"
    }

    private static func string(for key: String, fallback: String = "") -> String {
        if let env = ProcessInfo.processInfo.environment[key], !env.isEmpty {
            return env
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           !plist.isEmpty,
           plist != "$(\(key))" {
            return plist
        }
        return fallback
    }
}

private extension String {
    func or(_ other: String) -> String {
        isEmpty ? other : self
    }
}
