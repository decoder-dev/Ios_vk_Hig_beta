import Foundation

/// Confirming VK's own "log in by QR code" page (`vk.com/auth_by_code` / the QR shown on a VK
/// login screen) from an already-authenticated device. This is the official `auth.processAuthCode`
/// flow, not the token-in-QR case (`VKTokenParser` already handles a QR that directly encodes a token).
enum VKQRLoginService {
    /// Pulls `auth_hash` out of a scanned VK login QR. VK encodes it either as a query/fragment
    /// parameter on a `vk.com` URL or as the bare hash string.
    static func authHash(from scanned: String) -> String? {
        let text = scanned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let url = URL(string: text), let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            var pairs: [String: String] = [:]
            for item in comps.queryItems ?? [] { pairs[item.name] = item.value }
            if let fragment = comps.fragment {
                var f = URLComponents(); f.query = fragment
                for item in f.queryItems ?? [] { pairs[item.name] = item.value }
            }
            if let hash = pairs["auth_hash"], isPlausibleHash(hash) { return hash }
        }
        return isPlausibleHash(text) ? text : nil
    }

    private static func isPlausibleHash(_ s: String) -> Bool {
        s.range(of: #"^[A-Za-z0-9_\-]{16,}$"#, options: .regularExpression) != nil
    }

    struct DeviceInfo: Sendable {
        let platform: String?
        let location: String?
    }

    /// `action: 0` — ask what device/location this code belongs to, for the confirmation prompt.
    static func describe(hash: String) async throws -> DeviceInfo {
        let data = try await VKAPISession.shared.call(method: "auth.processAuthCode", params: ["auth_hash": hash, "action": "0"])
        let json = try JSONDecoder().decode(VKAPIEnvelope<VKJSON>.self, from: data).response ?? .null
        return DeviceInfo(platform: json["platform"].string.isEmpty ? nil : json["platform"].string,
                          location: json["location"].string.isEmpty ? nil : json["location"].string)
    }

    /// `action: 1` — confirm the sign-in with the currently active account's token.
    static func confirm(hash: String) async throws {
        _ = try await VKAPISession.shared.call(method: "auth.processAuthCode", params: ["auth_hash": hash, "action": "1"])
    }
}
