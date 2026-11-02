import Foundation
import AuthenticationServices
import CryptoKit
import Security
import UIKit

struct VKIDConfiguration: Sendable {
    var clientID: String?
    var redirectURLScheme: String?
    var isConfigured: Bool {
        guard let id = clientID, !id.isEmpty, id.allSatisfy(\.isNumber),
              let scheme = redirectURLScheme, !scheme.isEmpty else { return false }
        return true
    }
    var redirectURI: String { "\(redirectURLScheme ?? "vkhig")://vkid" }
}

enum VKIDAuthError: Error, LocalizedError, Equatable {
    case missingCredentials, sdkNotLinked, cancelled, failed(String)
    var errorDescription: String? {
        switch self {
        case .missingCredentials: return "Не настроен идентификатор приложения VK ID."
        case .sdkNotLinked: return "Авторизация недоступна в этой сборке."
        case .cancelled: return "Вход отменён."
        case .failed(let message): return message
        }
    }
}

/// Official VK ID public OAuth 2.1 flow. Uses ASWebAuthenticationSession + S256 PKCE.
/// A confidential client secret is never shipped in the application.
@MainActor
final class VKIDAuthCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = VKIDAuthCoordinator()
    private let configuration: VKIDConfiguration
    private let tokenStore: KeychainTokenStore
    private let metadata = KeychainTokenStore(account: "vk-oauth-session")
    private var webSession: ASWebAuthenticationSession?
    private var refreshTask: Task<String?, Never>?
    private(set) var grants: Set<String> = []
    private(set) var userID: Int64?
    private var generation = UUID()

    private struct Session: Codable {
        var accessToken: String
        var refreshToken: String
        var deviceID: String
        var expiration: Date
        var userID: Int64
        var scope: String
    }
    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Double
        let user_id: Int64
        let scope: String?
        let state: String?
    }
    init(configuration: VKIDConfiguration = .init(clientID: AppSecrets.vkClientID, redirectURLScheme: AppSecrets.vkRedirectScheme), tokenStore: KeychainTokenStore = .init()) {
        self.configuration = configuration
        self.tokenStore = tokenStore
        super.init()
        if let saved = savedSession() { grants = Set(saved.scope.split(separator: " ").map(String.init)); userID = saved.userID }
    }
    var isConfigured: Bool { configuration.isConfigured }
    var redirectURI: String { configuration.redirectURI }

    func authorize() async -> Result<Void, VKIDAuthError> {
        guard isConfigured, let clientID = configuration.clientID else { return .failure(.missingCredentials) }
        guard webSession == nil else { return .failure(.failed("Вход уже выполняется.")) }
        let ticket = generation
        do {
            let verifier = try Self.randomString()
            let state = try Self.randomString()
            let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
            var components = URLComponents(string: "https://id.vk.ru/authorize")!
            components.queryItems = [
                .init(name: "response_type", value: "code"), .init(name: "client_id", value: clientID),
                .init(name: "redirect_uri", value: redirectURI), .init(name: "state", value: state),
                .init(name: "code_challenge", value: challenge), .init(name: "code_challenge_method", value: "S256"),
                .init(name: "scope", value: AppSecrets.requestedScopes)
            ]
            guard let url = components.url else { throw VKIDAuthError.failed("Некорректный адрес входа.") }
            let callback: URL = try await withCheckedThrowingContinuation { continuation in
                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: configuration.redirectURLScheme) { callback, error in
                    if let error { continuation.resume(throwing: error) }
                    else if let callback { continuation.resume(returning: callback) }
                    else { continuation.resume(throwing: VKIDAuthError.cancelled) }
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                self.webSession = session
                if !session.start() { self.webSession = nil; continuation.resume(throwing: VKIDAuthError.failed("Не удалось открыть окно входа.")) }
            }
            webSession = nil
            guard ticket == generation else { throw VKIDAuthError.cancelled }
            let values = try Self.validateCallback(callback, redirectURI: redirectURI, state: state)
            let device = values["device_id"]!
            let response = try await exchange([
                "grant_type": "authorization_code", "client_id": clientID, "redirect_uri": redirectURI,
                "code": values["code"]!, "code_verifier": verifier, "state": state, "device_id": device
            ])
            guard ticket == generation else { throw VKIDAuthError.cancelled }
            if let returnedState = response.state, returnedState != state { throw VKIDAuthError.failed("Ответ VK ID не прошёл проверку безопасности.") }
            try persist(.init(accessToken: response.access_token, refreshToken: response.refresh_token ?? "", deviceID: device,
                              expiration: Date().addingTimeInterval(response.expires_in), userID: response.user_id, scope: response.scope ?? "vkid.personal_info"))
            return .success(())
        } catch {
            webSession = nil
            if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin { return .failure(.cancelled) }
            return .failure(error as? VKIDAuthError ?? .failed("Не удалось войти. Проверьте сеть и настройки приложения VK ID."))
        }
    }
    static func validateCallback(_ url: URL, redirectURI: String, state: String) throws -> [String: String] {
        guard let expected = URL(string: redirectURI), url.scheme == expected.scheme, url.host == expected.host,
              url.path == expected.path, url.port == expected.port, url.user == nil, url.password == nil, url.fragment == nil, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw VKIDAuthError.failed("Неверный адрес возврата VK ID.")
        }
        var values: [String: String] = [:]
        for item in components.queryItems ?? [] {
            guard values[item.name] == nil else { throw VKIDAuthError.failed("Повторяющийся параметр VK ID.") }
            values[item.name] = item.value ?? ""
        }
        guard values["state"] == state, values["error"] == nil,
              !(values["code"] ?? "").isEmpty, !(values["device_id"] ?? "").isEmpty else {
            throw VKIDAuthError.failed("VK ID не подтвердил вход или права доступа.")
        }
        return values
    }
    func freshAccessToken() async -> String? {
        if let task = refreshTask { return await task.value }
        guard let saved = savedSession() else { return nil }
        if saved.expiration.timeIntervalSinceNow > 60 { return saved.accessToken }
        guard !saved.refreshToken.isEmpty, let id = configuration.clientID else { clearSession(); return nil }
        let ticket = generation
        let task = Task<String?, Never> { [weak self] in
            guard let self else { return nil }
            do {
                let state = try Self.randomString()
                let response = try await self.exchange(["grant_type":"refresh_token", "client_id":id,
                    "refresh_token":saved.refreshToken, "device_id":saved.deviceID, "state":state])
                guard ticket == self.generation else { return nil }
                if let echoed = response.state, echoed != state { return nil }
                try self.persist(.init(accessToken:response.access_token, refreshToken:response.refresh_token ?? saved.refreshToken,
                    deviceID:saved.deviceID, expiration:Date().addingTimeInterval(response.expires_in),
                    userID:response.user_id, scope:response.scope ?? saved.scope))
                return response.access_token
            } catch { return nil }
        }
        refreshTask = task
        let result = await task.value
        refreshTask = nil
        return result
    }
    func fetchIdentity() async throws -> UserProfile {
        guard let accessToken = await freshAccessToken(),let session = savedSession(),let clientID = configuration.clientID else { throw AppError.notAuthenticated }
        var request = URLRequest(url:URL(string:"https://id.vk.ru/oauth2/user_info")!)
        request.httpMethod = "POST"; request.timeoutInterval = 30
        request.setValue("Bearer " + accessToken,forHTTPHeaderField:"Authorization")
        request.setValue("application/x-www-form-urlencoded",forHTTPHeaderField:"Content-Type")
        request.httpBody = FormEncoding.data(["client_id":clientID,"device_id":session.deviceID])
        let (data,http) = try await URLSession.shared.data(for:request)
        guard let http = http as? HTTPURLResponse,(200...299).contains(http.statusCode) else { throw AppError.notAuthenticated }
        let value = try JSONDecoder().decode(VKJSON.self,from:data)["user"]
        let name = [value["first_name"].string,value["last_name"].string].filter { !$0.isEmpty }.joined(separator:" ")
        guard !name.isEmpty else { throw AppError.decoding }
        return UserProfile(id:session.userID,displayName:name,initials:VKCatalogService.initials(name),city:nil,statusText:nil)
    }
    func restoreSessionIfPossible() -> Bool { savedSession() != nil }
    func clearSession() {
        generation = UUID(); webSession?.cancel(); webSession = nil
        refreshTask?.cancel(); refreshTask = nil; tokenStore.delete(); metadata.delete(); grants = []; userID = nil
    }
    private func savedSession() -> Session? {
        guard let raw = metadata.load(), let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }
    private func persist(_ session: Session) throws {
        guard !session.accessToken.isEmpty else { throw VKIDAuthError.failed("VK ID вернул пустой токен.") }
        let raw = String(decoding: try JSONEncoder().encode(session), as: UTF8.self)
        guard metadata.save(raw) == errSecSuccess, tokenStore.save(session.accessToken) == errSecSuccess else {
            metadata.delete(); tokenStore.delete(); throw VKIDAuthError.failed("Не удалось безопасно сохранить сессию.")
        }
        grants = Set(session.scope.split(separator: " ").map(String.init)); userID = session.userID
    }
    private func exchange(_ parameters: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://id.vk.ru/oauth2/auth")!)
        request.httpMethod = "POST"; request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = FormEncoding.data(parameters)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw VKIDAuthError.failed("VK ID отклонил обмен кода.") }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }
    private static func randomString() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw VKIDAuthError.failed("Не удалось создать защищённый запрос входа.") }
        return Data(bytes).base64URL
    }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
private extension Data {
    var base64URL: String { base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
}
