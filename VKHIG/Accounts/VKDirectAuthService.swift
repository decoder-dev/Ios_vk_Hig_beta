import Foundation

struct VKTokenGrant: Sendable {
    let accessToken: String
    let userId: Int64
    let secret: String?
    let trustedHash: String?
}

/// Extra parameters for retrying the password grant after a challenge.
struct VKAuthChallengeAnswer: Sendable {
    var code: String?
    var captchaSid: String?
    var captchaKey: String?
    /// Ask VK to send the 2FA code by SMS instead of a push/app code.
    var forceSms: Bool = false
}

/// OAuth password grant against oauth.vk.com/token, matching every documented success/challenge
/// field (`VKLoginResponseDTO`). Reuses a per-install `device_id` and, once VK has issued one, the
/// (client, login) `trusted_hash` so a device that already passed 2FA isn't challenged again.
struct VKDirectAuthService: Sendable {
    var urlSession: URLSession = .shared

    func login(username: String, password: String, preset: VKClientPreset,
               answer: VKAuthChallengeAnswer = .init()) async throws -> VKTokenGrant {
        guard let url = URL(string: "\(VKApiConstants.oauthBaseURL)/token") else { throw VKAuthError.parsingError }
        var fields: [String: String] = [
            "grant_type": "password",
            "client_id": preset.clientId,
            "client_secret": preset.clientSecret,
            "username": username,
            "password": password,
            "v": VKApiConstants.apiVersion,
            "lang": "ru",
            "scope": String(VKApiConstants.fullScopeBitmask),
            "2fa_supported": "1",
            "device_id": VKDeviceIdentity.current
        ]
        if answer.forceSms { fields["force_sms"] = "1" }
        if let trusted = TrustedHashStore.shared.hash(clientId: preset.clientId, username: username) {
            fields["trusted_hash"] = trusted
        }
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
        let grant = try Self.parse(data)
        if let hash = grant.trustedHash {
            TrustedHashStore.shared.save(hash, clientId: preset.clientId, username: username)
        }
        return grant
    }

    /// If VK reports `need_validation` with a `validation_sid` but hasn't pushed the SMS yet,
    /// nudges it to send one. Best-effort: push/app 2FA never needed this, so failure is ignored.
    func requestSmsIfNeeded(validationSid: String, preset: VKClientPreset) async {
        guard let url = URL(string: "\(VKApiConstants.apiBaseURL)/auth.validatePhone") else { return }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(preset.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = FormEncoding.data([
            "sid": validationSid, "client_id": preset.clientId, "client_secret": preset.clientSecret,
            "v": VKApiConstants.apiVersion
        ])
        _ = try? await urlSession.data(for: request)
    }

    /// VK answers errors with HTTP 4xx and a JSON body, so the body is parsed regardless of status.
    static func parse(_ data: Data) throws -> VKTokenGrant {
        guard let dto = try? JSONDecoder().decode(VKLoginResponseDTO.self, from: data) else {
            throw VKAuthError.parsingError
        }
        if let token = dto.accessToken, !token.isEmpty, let uid = dto.userId {
            return VKTokenGrant(accessToken: token, userId: uid, secret: dto.secret, trustedHash: dto.trustedHash)
        }
        switch dto.error {
        case "need_validation":
            throw VKAuthError.needValidation(
                validationType: dto.validationType ?? "2fa_app",
                phoneMask: dto.phoneMask,
                redirectUri: dto.redirectUri,
                validationSid: dto.validationSid)
        case "need_captcha":
            if let sid = dto.captchaSid, let img = dto.captchaImg {
                throw VKAuthError.needCaptcha(sid: sid, imgUrl: img)
            }
            // VK ID style captcha: only a redirect page is provided (no sid/img). Heuristic.
            if let uri = dto.redirectUrl ?? dto.redirectUri {
                throw VKAuthError.needVKIdCaptcha(captchaUrl: uri)
            }
            throw VKAuthError.parsingError
        case "invalid_client", "invalid_request", "invalid_grant", "username_or_password_is_incorrect":
            throw VKAuthError.invalidCredentials
        default:
            if dto.errorType == "username_or_password_is_incorrect" { throw VKAuthError.invalidCredentials }
            throw VKAuthError.parsingError
        }
    }
}
