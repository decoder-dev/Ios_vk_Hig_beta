import Foundation
import Combine

struct VKCredentials: Equatable, Sendable {
    let token: String
    let tokenType: TokenType
    let userAgent: String

    init(token: String, tokenType: TokenType) {
        self.token = token
        self.tokenType = tokenType
        self.userAgent = tokenType == .official ? "VK/6.35" : "KateMobile/56 lite"
    }
}

/// Injects `access_token`, `v` and `User-Agent` into every request to api.vk.com.
final class VKRequestAdapter: @unchecked Sendable {
    static let apiVersion = "5.131"
    private let lock = NSLock()
    private var current: VKCredentials?

    var credentials: VKCredentials? {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func setCredentials(_ value: VKCredentials?) {
        lock.lock(); current = value; lock.unlock()
    }

    func adapt(_ request: URLRequest, using override: VKCredentials? = nil) -> URLRequest {
        guard let creds = override ?? credentials,
              let url = request.url, url.host == "api.vk.com",
              var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return request }
        var items = (comps.queryItems ?? []).filter { $0.name != "access_token" && $0.name != "v" }
        items.append(URLQueryItem(name: "access_token", value: creds.token))
        items.append(URLQueryItem(name: "v", value: Self.apiVersion))
        comps.queryItems = items
        var adapted = request
        adapted.url = comps.url
        adapted.setValue(creds.userAgent, forHTTPHeaderField: "User-Agent")
        return adapted
    }
}

/// Thin API transport on top of the adapter. Detects error 5 (User authorization failed).
final class VKAPISession: @unchecked Sendable {
    static let shared = VKAPISession()

    let adapter = VKRequestAdapter()
    /// Fires when the *active* session's token is rejected (error_code 5).
    /// Payload is the rejected token, so late duplicate events can't kill a newer account.
    let onSessionExpired = PassthroughSubject<String, Never>()
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    /// - Parameter credentials: explicit token (e.g. validating a not-yet-saved one). `nil` = active account.
    func call(method: String, params: [String: String] = [:], credentials: VKCredentials? = nil) async throws -> Data {
        guard method.range(of: #"^[A-Za-z]+\.[A-Za-z][A-Za-z0-9]*$"#, options: .regularExpression) != nil,
              var comps = URLComponents(string: "https://api.vk.com/method/\(method)") else {
            throw VKAPITransportError.invalidMethod
        }
        comps.queryItems = params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = comps.url else { throw VKAPITransportError.invalidMethod }
        guard let used = credentials ?? adapter.credentials else { throw VKAPITransportError.authorizationRequired }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request = adapter.adapt(request, using: credentials)

        let data: Data
        let response: URLResponse
        do { (data, response) = try await urlSession.data(for: request) }
        catch { throw VKAuthError.networkError(error) }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw VKAPITransportError.httpStatus(http.statusCode)
        }
        if let body = try? JSONDecoder().decode(VKAPIEnvelopeError.self, from: data), let err = body.error {
            if err.error_code == 5 {
                if credentials == nil { onSessionExpired.send(used.token) }
                throw VKAuthError.tokenRevoked
            }
            throw VKAPITransportError.remote(err.error_code, err.error_msg)
        }
        return data
    }
}

private struct VKAPIEnvelopeError: Decodable {
    let error: VKAPIErrorBody?
}

// MARK: - users.get

struct VKUserProfile: Sendable {
    let id: Int64
    let firstName: String
    let lastName: String
    let avatarUrl: String?
}

extension VKAPISession {
    func fetchProfile(credentials: VKCredentials? = nil) async throws -> VKUserProfile {
        struct Envelope: Decodable {
            struct User: Decodable {
                let id: Int64
                let first_name: String
                let last_name: String
                let photo_100: String?
            }
            let response: [User]?
        }
        let data = try await call(method: "users.get", params: ["fields": "photo_100"], credentials: credentials)
        guard let u = (try? JSONDecoder().decode(Envelope.self, from: data))?.response?.first else {
            throw VKAuthError.parsingError
        }
        return VKUserProfile(id: u.id, firstName: u.first_name, lastName: u.last_name, avatarUrl: u.photo_100)
    }
}
