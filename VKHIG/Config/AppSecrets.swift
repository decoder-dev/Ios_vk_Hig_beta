import Foundation

/// Runtime secrets/config placeholders.
/// Jessica fills real values locally via `Secrets.xcconfig` / environment — never commit secrets.
enum AppSecrets {
    /// Copy `Config/Secrets.example.xcconfig` → `Config/Secrets.xcconfig` (gitignored) and set values.
    static var vkClientID: String {
        string(for: "VK_CLIENT_ID")
    }

    static var vkRedirectScheme: String {
        string(for: "VK_REDIRECT_SCHEME", fallback: "vkhig")
    }

    static var vkAPIVersion: String {
        string(for: "VK_API_VERSION", fallback: "5.199")
    }

    static var hasVKIDCredentials: Bool {
        !vkClientID.isEmpty && vkClientID != "YOUR_VK_ID_CLIENT_ID"
    }

    private static func string(for key: String, fallback: String = "") -> String {
        if let env = ProcessInfo.processInfo.environment[key], !env.isEmpty {
            return env
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: key) as? String, !plist.isEmpty {
            return plist
        }
        return fallback
    }
}
