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
        let login = Self.normalizedLogin(username)
        do {
            return try await requestToken(login: login, password: password, preset: preset, answer: answer,
                                          scope: VKApiConstants.fullScopeBitmask)
        } catch VKAuthError.invalidScope {
            // Some clients may not request ads/stats/market; retry once with what the app really uses.
            return try await requestToken(login: login, password: password, preset: preset, answer: answer,
                                          scope: VKApiConstants.conservativeScopeBitmask)
        }
    }

    /// Trims autofill whitespace; phone numbers lose formatting ("+7 (999) 123-45-67" → "+79991234567").
    static func normalizedLogin(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains("@") else { return trimmed }
        let phoneCharacters = CharacterSet(charactersIn: "+0123456789 ()-.\u{00A0}")
        guard trimmed.unicodeScalars.allSatisfy(phoneCharacters.contains),
              trimmed.contains(where: \.isNumber) else { return trimmed }
        let digits = trimmed.filter { $0.isNumber }
        return trimmed.hasPrefix("+") ? "+" + digits : digits
    }

    private func requestToken(login username: String, password: String, preset: VKClientPreset,
                              answer: VKAuthChallengeAnswer, scope: Int) async throws -> VKTokenGrant {
        guard let url = URL(string: "\(VKApiConstants.oauthBaseURL)/token") else { throw VKAuthError.parsingError }
        var fields: [String: String] = [
            "grant_type": "password",
            "client_id": preset.clientId,
            "client_secret": preset.clientSecret,
            "username": username,
            "password": password,
            "v": VKApiConstants.apiVersion,
            "lang": "ru",
            "scope": String(scope),
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
        let response: URLResponse
        do { (data, response) = try await urlSession.data(for: request) }
        catch { throw VKAuthError.networkError(error) }
        let grant: VKTokenGrant
        do { grant = try Self.parse(data) }
        catch VKAuthError.parsingError {
            // Non-JSON body (proxy page, 5xx): report the HTTP status instead of a vague parse error.
            if let http = response as? HTTPURLResponse, !(200...499).contains(http.statusCode) {
                throw VKAuthError.server("VK временно недоступен (HTTP \(http.statusCode)). Попробуйте позже")
            }
            throw VKAuthError.parsingError
        }
        if let hash = grant.trustedHash {
            TrustedHashStore.shared.save(hash, clientId: preset.clientId, username: username)
        }
        return grant
    }

    /// Asks VK to actually send the SMS for a `need_validation` session. VK does not send it by itself for
    /// password-grant logins. Returns the resend delay in seconds when VK reports one.
    @discardableResult
    func requestSms(validationSid: String, preset: VKClientPreset) async -> Int? {
        guard let url = URL(string: "\(VKApiConstants.apiBaseURL)/auth.validatePhone") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(preset.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = FormEncoding.data([
            "sid": validationSid, "client_id": preset.clientId, "api_id": preset.clientId,
            "client_secret": preset.clientSecret, "v": VKApiConstants.apiVersion, "lang": "ru"
        ])
        guard let (data, _) = try? await urlSession.data(for: request),
              let json = try? JSONDecoder().decode(VKJSON.self, from: data) else { return nil }
        let delay = json["response"]["delay"].int
        return delay > 0 ? Int(delay) : nil
    }

    /// Kept for callers that only need the side effect.
    func requestSmsIfNeeded(validationSid: String, preset: VKClientPreset) async {
        await requestSms(validationSid: validationSid, preset: preset)
    }

    /// VK answers errors with HTTP 4xx and a JSON body, so the body is parsed regardless of status.
    static func parse(_ data: Data) throws -> VKTokenGrant {
        guard let dto = try? JSONDecoder().decode(VKLoginResponseDTO.self, from: data) else {
            throw VKAuthError.parsingError
        }
        if let token = dto.accessToken, !token.isEmpty, let uid = dto.userId {
            return VKTokenGrant(accessToken: token, userId: uid, secret: dto.secret, trustedHash: dto.trustedHash)
        }
        let error = dto.error ?? ""
        let type = dto.errorType ?? ""
        let description = dto.errorDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if let ban = dto.banInfo {
            throw VKAuthError.accountBlocked(message: ban.message, restoreURL: ban.restoreURL)
        }
        if ["wrong_otp", "otp_format_is_incorrect", "wrong_otp_format"].contains(type)
            || description.localizedCaseInsensitiveContains("code is invalid")
            || description.localizedCaseInsensitiveContains("wrong code") {
            throw VKAuthError.wrongCode
        }
        if type == "password_bruteforce_attempt" || type == "too_many_requests" || error.hasPrefix("9;")
            || description.localizedCaseInsensitiveContains("flood") || error == "too_many_requests" {
            throw VKAuthError.tooManyAttempts
        }
        switch error {
        case "need_validation":
            // No validation_type but a redirect: VK wants a security check page, not a code.
            let validationType = dto.validationType ?? (dto.redirectUri != nil ? "web" : "2fa_app")
            throw VKAuthError.needValidation(
                validationType: validationType,
                phoneMask: dto.phoneMask,
                redirectUri: dto.redirectUri,
                validationSid: dto.validationSid)
        case "need_captcha":
            if let sid = dto.captchaSid, let img = dto.captchaImg {
                throw VKAuthError.needCaptcha(sid: sid, imgUrl: img)
            }
            // VK ID style captcha: only a redirect page is provided (no sid/img).
            if let uri = dto.redirectUrl ?? dto.redirectUri {
                throw VKAuthError.needVKIdCaptcha(captchaUrl: uri)
            }
            throw VKAuthError.server("VK запросил проверку, которую нельзя пройти в этой форме. Войдите через веб-форму VK")
        case "invalid_scope":
            throw VKAuthError.invalidScope
        case "invalid_client", "invalid_grant", "username_or_password_is_incorrect":
            throw VKAuthError.invalidCredentials
        case "invalid_request":
            if type == "username_or_password_is_incorrect" { throw VKAuthError.invalidCredentials }
            throw VKAuthError.server(description.isEmpty ? "VK отклонил запрос входа" : "VK: \(description)")
        default:
            if type == "username_or_password_is_incorrect" { throw VKAuthError.invalidCredentials }
            if !description.isEmpty { throw VKAuthError.server("VK: \(description)") }
            if !error.isEmpty { throw VKAuthError.server("VK: \(error)") }
            throw VKAuthError.parsingError
        }
    }
}
