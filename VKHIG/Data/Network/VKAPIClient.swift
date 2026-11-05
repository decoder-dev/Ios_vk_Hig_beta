import Foundation

/// Typed POST transport for documented VK methods.
/// Confirm API version, scopes, and method availability before enabling live mode.
struct VKAPIErrorBody: Decodable, Sendable {
    let error_code: Int
    let error_msg: String
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
        case .remote(let code, _): "Ошибка VK API: \(code)"
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
        apiVersion: String
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
