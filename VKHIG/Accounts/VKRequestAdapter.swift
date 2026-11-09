import Foundation
import Combine

struct VKCredentials: Equatable, Sendable {
    let token: String
    let tokenType: TokenType
    let userAgent: String
    /// Session `secret`, when VK issued one for this token (password-grant clients). Enables `sig`
    /// signing for "nohttps" methods that require it; `nil` means no `sig` is added.
    let secret: String?

    init(token: String, tokenType: TokenType, secret: String? = nil, accountType: VKAccountType? = nil) {
        self.token = token
        self.tokenType = tokenType
        self.secret = secret
        self.userAgent = accountType?.userAgent ?? (tokenType == .official ? "VK/6.35" : "KateMobile/56 lite")
    }
}

/// Resolves VK API challenges (`error_code` 14 / 17) so a caller's request can be retried
/// transparently instead of failing outright. UI (captcha sheet, validation web view) implements this.
protocol VKChallengeResolving: Sendable {
    /// Returns the captcha answer to retry with, or `nil` if the user gave up.
    func resolveCaptcha(sid: String, imgUrl: String) async -> (sid: String, key: String)?
    /// Returns `true` once the user completed validation at `redirectUri` (so the original request
    /// can be retried as-is), or `false` if they gave up.
    func resolveValidation(redirectUri: String) async -> Bool
}

/// Injects `access_token`, `v` and `User-Agent` into every request to api.vk.com.
final class VKRequestAdapter: @unchecked Sendable {
    static let apiVersion = VKApiConstants.legacyApiVersion
    private let lock = NSLock()
    private var current: VKCredentials?

    var credentials: VKCredentials? {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func setCredentials(_ value: VKCredentials?) {
        lock.lock(); current = value; lock.unlock()
    }
}

/// Thin API transport. Detects error 5 (session revoked) and transparently retries error 14
/// (captcha) / error 17 (validation) through an injected `VKChallengeResolving`.
final class VKAPISession: @unchecked Sendable {
    static let shared = VKAPISession()

    let adapter = VKRequestAdapter()
    /// Fires when the *active* session's token is rejected (error_code 5).
    /// Payload is the rejected token, so late duplicate events can't kill a newer account.
    let onSessionExpired = PassthroughSubject<String, Never>()
    /// UI hook for error 14 / 17. `nil` = those errors surface as `VKAuthError` to the caller.
    var challengeResolver: VKChallengeResolving?
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    /// - Parameter credentials: explicit token (e.g. validating a not-yet-saved one). `nil` = active account.
    func call(method: String, params: [String: String] = [:], credentials: VKCredentials? = nil,
              allowChallengeRetry: Bool = true, signed: Bool = true) async throws -> Data {
        guard method.range(of: #"^[A-Za-z]+\.[A-Za-z][A-Za-z0-9]*$"#, options: .regularExpression) != nil else {
            throw VKAPITransportError.invalidMethod
        }
        guard let used = credentials ?? adapter.credentials else { throw VKAPITransportError.authorizationRequired }

        var fields = params
        fields["access_token"] = used.token
        fields["v"] = VKRequestAdapter.apiVersion
        let addsSignature = signed && !(used.secret ?? "").isEmpty
        if addsSignature, let secret = used.secret {
            fields["sig"] = Self.signature(method: method, params: fields, secret: secret)
        }
        guard var comps = URLComponents(string: "https://api.vk.com/method/\(method)") else {
            throw VKAPITransportError.invalidMethod
        }
        comps.queryItems = fields.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = comps.url else { throw VKAPITransportError.invalidMethod }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue(used.userAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do { (data, response) = try await urlSession.data(for: request) }
        catch { throw VKAuthError.networkError(error) }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw VKAPITransportError.httpStatus(http.statusCode)
        }
        guard let body = try? JSONDecoder().decode(VKAPIEnvelopeError.self, from: data), let err = body.error else {
            return data
        }
        switch err.error_code {
        case 4 where addsSignature:
            // "Incorrect signature": HTTPS calls do not need `sig`, so retry once unsigned instead of failing login.
            return try await call(method: method, params: params, credentials: credentials,
                                  allowChallengeRetry: allowChallengeRetry, signed: false)
        case 5:
            if credentials == nil { onSessionExpired.send(used.token) }
            throw VKAuthError.tokenRevoked
        case 14 where allowChallengeRetry:
            guard let resolver = challengeResolver,
                  let sid = err.captcha_sid, let img = err.captcha_img,
                  let answer = await resolver.resolveCaptcha(sid: sid, imgUrl: img) else {
                throw VKAuthError.needCaptcha(sid: err.captcha_sid ?? "", imgUrl: err.captcha_img ?? "")
            }
            var retryParams = params
            retryParams["captcha_sid"] = answer.sid
            retryParams["captcha_key"] = answer.key
            return try await call(method: method, params: retryParams, credentials: credentials, allowChallengeRetry: false)
        case 17 where allowChallengeRetry:
            guard let resolver = challengeResolver, let redirect = err.redirect_uri,
                  await resolver.resolveValidation(redirectUri: redirect) else {
                throw VKAuthError.needValidation(validationType: "web", phoneMask: nil, redirectUri: err.redirect_uri, validationSid: nil)
            }
            return try await call(method: method, params: params, credentials: credentials, allowChallengeRetry: false)
        default:
            throw VKAPITransportError.remote(err.error_code, err.error_msg)
        }
    }

    /// `sig = MD5("/method/{method}?{sorted query}{secret}")`, the legacy "nohttps" request signature.
    static func signature(method: String, params: [String: String], secret: String) -> String {
        let query = params.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        return VKMD5.hex("/method/\(method)?\(query)\(secret)")
    }
}

private struct VKAPIEnvelopeError: Decodable {
    struct Body: Decodable {
        let error_code: Int
        let error_msg: String
        let captcha_sid: String?
        let captcha_img: String?
        let redirect_uri: String?
    }
    let error: Body?
}

// MARK: - users.get

struct VKUserProfile: Sendable {
    let id: Int64
    let firstName: String
    let lastName: String
    let avatarUrl: String?
}

extension VKAPISession {
    func fetchProfile(credentials: VKCredentials? = nil, allowChallengeRetry: Bool = true) async throws -> VKUserProfile {
        struct Envelope: Decodable {
            struct User: Decodable {
                let id: Int64
                let first_name: String
                let last_name: String
                let photo_100: String?
            }
            let response: [User]?
        }
        let data = try await call(method: "users.get", params: ["fields": "photo_100"], credentials: credentials,
                                  allowChallengeRetry: allowChallengeRetry)
        guard let u = (try? JSONDecoder().decode(Envelope.self, from: data))?.response?.first else {
            throw VKAuthError.parsingError
        }
        return VKUserProfile(id: u.id, firstName: u.first_name, lastName: u.last_name, avatarUrl: u.photo_100)
    }
}
