import Foundation

struct ParsedVKToken: Equatable, Sendable {
    let token: String
    let userId: Int64?
}

/// Extracts a token from: a bare token, JSON `{"token":..., "user_id":...}`, or a redirect URL
/// (`...#access_token=...&user_id=...`).
enum VKTokenParser {
    static func isPlausibleToken(_ s: String) -> Bool {
        s.range(of: #"^vk1\.a\.[A-Za-z0-9_\-\.]{20,}$"#, options: .regularExpression) != nil
            || s.range(of: #"^[0-9a-fA-F]{85}$"#, options: .regularExpression) != nil
    }

    static func parse(_ raw: String) -> ParsedVKToken? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if isPlausibleToken(text) { return ParsedVKToken(token: text, userId: nil) }

        if text.hasPrefix("{"), let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let token = (json["token"] as? String) ?? (json["access_token"] as? String)
            guard let token, isPlausibleToken(token.trimmingCharacters(in: .whitespaces)) else { return nil }
            return ParsedVKToken(token: token.trimmingCharacters(in: .whitespaces), userId: userId(json["user_id"]))
        }

        if let url = URL(string: text), url.scheme != nil {
            return parseURL(url)
        }
        return nil
    }

    /// Parses `#access_token=...&user_id=...` (fragment) or the query string.
    static func parseURL(_ url: URL) -> ParsedVKToken? {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var pairs: [String: String] = [:]
        for item in comps.queryItems ?? [] { pairs[item.name] = item.value }
        if let fragment = comps.fragment {
            var f = URLComponents(); f.query = fragment
            for item in f.queryItems ?? [] { pairs[item.name] = item.value }
        }
        guard let token = pairs["access_token"], isPlausibleToken(token) else { return nil }
        return ParsedVKToken(token: token, userId: pairs["user_id"].flatMap { Int64($0) })
    }

    private static func userId(_ v: Any?) -> Int64? {
        if let n = v as? NSNumber { return n.int64Value }
        if let s = v as? String { return Int64(s) }
        return nil
    }
}
