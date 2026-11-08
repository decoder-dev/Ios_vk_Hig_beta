import Foundation

struct VKTokenGrant: Sendable {
    let accessToken: String
    let userId: Int64
    let secret: String?
}

/// Extra parameters for retrying the password grant after a challenge.
struct VKAuthChallengeAnswer: Sendable {
    var code: String?
    var captchaSid: String?
    var captchaKey: String?
}

/// OAuth password grant against oauth.vk.com/token.
struct VKDirectAuthService: Sendable {
    var urlSession: URLSession = .shared

    func login(username: String, password: String, preset: VKClientPreset,
               answer: VKAuthChallengeAnswer = .init()) async throws -> VKTokenGrant {
        guard let url = URL(string: "https://oauth.vk.com/token") else { throw VKAuthError.parsingError }
        var fields: [String: String] = [
            "grant_type": "password",
            "client_id": preset.clientId,
            "client_secret": preset.clientSecret,
            "username": username,
            "password": password,
            "scope": String(VKScopes.fullAccess.rawValue),
            "2fa_supported": "1",
            "v": VKRequestAdapter.apiVersion
        ]
        if let code = answer.code { fields["code"] = code }
        if let sid = answer.captchaSid, let key = answer.captchaKey {
            fields["captcha_sid"] = sid
            fields["captcha_key"] = key
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(preset.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = FormEncoding.data(fields)
        // Never log request or response bodies — they contain credentials and tokens.

        let data: Data
        do { (data, _) = try await urlSession.data(for: request) }
        catch { throw VKAuthError.networkError(error) }
        return try Self.parse(data)
    }

    /// VK answers errors with HTTP 4xx and a JSON body, so the body is parsed regardless of status.
    static func parse(_ data: Data) throws -> VKTokenGrant {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw VKAuthError.parsingError
        }
        func int64(_ v: Any?) -> Int64? {
            if let n = v as? NSNumber { return n.int64Value }
            if let s = v as? String { return Int64(s) }
            return nil
        }
        if let token = json["access_token"] as? String, !token.isEmpty, let uid = int64(json["user_id"]) {
            return VKTokenGrant(accessToken: token, userId: uid, secret: json["secret"] as? String)
        }
        let error = json["error"] as? String
        switch error {
        case "need_validation":
            throw VKAuthError.needValidation(
                validationType: json["validation_type"] as? String ?? "2fa_app",
                phoneMask: json["phone_mask"] as? String,
                redirectUri: json["redirect_uri"] as? String)
        case "need_captcha":
            if let sid = json["captcha_sid"] as? String, let img = json["captcha_img"] as? String {
                throw VKAuthError.needCaptcha(sid: sid, imgUrl: img)
            }
            // VK ID style captcha: only a redirect page is provided (no sid/img). Heuristic.
            if let uri = json["redirect_uri"] as? String {
                throw VKAuthError.needVKIdCaptcha(captchaUrl: uri)
            }
            throw VKAuthError.parsingError
        case "invalid_client", "invalid_request", "invalid_grant", "username_or_password_is_incorrect":
            throw VKAuthError.invalidCredentials
        default:
            if json["error_type"] as? String == "username_or_password_is_incorrect" {
                throw VKAuthError.invalidCredentials
            }
            throw VKAuthError.parsingError
        }
    }
}
