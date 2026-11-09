import Foundation

/// Typed POST transport for documented VK methods.
/// Confirm API version, scopes, and method availability before enabling live mode.
struct VKAPIErrorBody: Decodable, Sendable {
    let error_code: Int
    let error_msg: String
    var captcha_sid: String? = nil
    var captcha_img: String? = nil
    var redirect_uri: String? = nil

    enum CodingKeys: String, CodingKey { case error_code, error_msg, captcha_sid, captcha_img, redirect_uri }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        error_code = (try? c.decode(Int.self, forKey: .error_code)) ?? 0
        error_msg = (try? c.decode(String.self, forKey: .error_msg)) ?? ""
        if let text = try? c.decode(String.self, forKey: .captcha_sid) { captcha_sid = text }
        else if let number = try? c.decode(Int64.self, forKey: .captcha_sid) { captcha_sid = String(number) }
        captcha_img = try? c.decode(String.self, forKey: .captcha_img)
        redirect_uri = try? c.decode(String.self, forKey: .redirect_uri)
    }
}

struct VKAPIEnvelope<T: Decodable>: Decodable {
    let response: T?
    let error: VKAPIErrorBody?
}

enum VKAPITransportError: Error, LocalizedError, Sendable {
    case authorizationRequired
    case invalidMethod
    case httpStatus(Int)
    case remote(Int, String)
    case missingResponse

    var errorDescription: String? {
        switch self {
        case .authorizationRequired: "Требуется вход в VK"
        case .invalidMethod: "Неверный метод VK API"
        case .httpStatus(let status): "Ошибка сервера: HTTP \(status)"
        case .remote(14, _): "VK запросил капчу. Повторите действие и введите текст с картинки"
        case .remote(17, _): "VK запросил подтверждение. Повторите действие и пройдите проверку"
        case .remote(let code, let message): message.isEmpty ? "Ошибка VK API: \(code)" : "Ошибка VK API \(code): \(message)"
        case .missingResponse: "VK вернул пустой ответ"
        }
    }
}

actor VKAPIClient {
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func call<T: Decodable>(
        method: String,
        parameters: [String: String],
        accessToken: String,
        apiVersion: String,
        allowChallengeRetry: Bool = true
    ) async throws -> T {
        guard !accessToken.isEmpty else { throw VKAPITransportError.authorizationRequired }
        let validMethod = method.range(of: #"^[A-Za-z]+\.[A-Za-z][A-Za-z0-9]*$"#, options: .regularExpression) != nil
        guard validMethod else { throw VKAPITransportError.invalidMethod }
        guard let url = URL(string: "https://api.vk.com/method/\(method)") else {
            throw VKAPITransportError.invalidMethod
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var fields = parameters
        fields["access_token"] = accessToken
        fields["v"] = apiVersion
        request.httpBody = FormEncoding.data(fields)
        // Tokens issued to a specific VK client (password grant, web form) expect that client's User-Agent.
        // HTTPS requests do not need `sig`, so none is added here.
        if let account = VKAPISession.shared.adapter.credentials, account.token == accessToken {
            request.setValue(account.userAgent, forHTTPHeaderField: "User-Agent")
        }
        request.timeoutInterval = 30
        // Never log request bodies — they contain tokens.

        let (data, urlResponse) = try await session.data(for: request)
        guard let http = urlResponse as? HTTPURLResponse else {
            throw VKAPITransportError.missingResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw VKAPITransportError.httpStatus(http.statusCode)
        }
        let envelope = try decoder.decode(VKAPIEnvelope<T>.self, from: data)
        if let error = envelope.error {
            switch error.error_code {
            case 5:
                VKAPISession.shared.onSessionExpired.send(accessToken)
            case 14 where allowChallengeRetry:
                // Captcha: ask the user, then repeat the same call once with the answer.
                if let sid = error.captcha_sid, let image = error.captcha_img,
                   let resolver = VKAPISession.shared.challengeResolver,
                   let answer = await resolver.resolveCaptcha(sid: sid, imgUrl: image) {
                    var retry = parameters
                    retry["captcha_sid"] = answer.sid
                    retry["captcha_key"] = answer.key
                    return try await call(method: method, parameters: retry, accessToken: accessToken,
                                          apiVersion: apiVersion, allowChallengeRetry: false)
                }
            case 17 where allowChallengeRetry:
                // Validation required: VK's own page, then the same call once more.
                if let redirect = error.redirect_uri, let resolver = VKAPISession.shared.challengeResolver,
                   await resolver.resolveValidation(redirectUri: redirect) {
                    return try await call(method: method, parameters: parameters, accessToken: accessToken,
                                          apiVersion: apiVersion, allowChallengeRetry: false)
                }
            default:
                break
            }
            throw VKAPITransportError.remote(error.error_code, error.error_msg)
        }
        guard let response = envelope.response else { throw VKAPITransportError.missingResponse }
        return response
    }
}


enum FormEncoding {
    static func data(_ values: [String: String]) -> Data {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return Data(values.sorted { $0.key < $1.key }.map {
            "\($0.key.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }.joined(separator: "&").utf8)
    }
}
