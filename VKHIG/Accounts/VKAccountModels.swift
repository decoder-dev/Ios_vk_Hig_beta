import Foundation

enum TokenType: String, Codable, Sendable {
    case official = "OFFICIAL" // Официальный клиент / Kate Mobile
    case web = "WEB"
    case custom = "CUSTOM"
}

struct VKAccount: Codable, Identifiable, Hashable, Sendable {
    var id: Int64 { userId }
    let userId: Int64
    let token: String
    let secret: String?
    let tokenType: TokenType
    /// Which VK client this token was issued to (password-grant logins only). Picks the matching
    /// `User-Agent` and lets `sig` signing use the right `client_secret`-derived session secret.
    var accountType: VKAccountType?
    let refreshToken: String?
    var firstName: String
    var lastName: String
    var avatarUrl: String?
    var isActive: Bool

    var displayName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }

    // Never print tokens.
    private enum CodingKeys: String, CodingKey {
        case userId, token, secret, tokenType, accountType, refreshToken, firstName, lastName, avatarUrl, isActive
    }

    init(userId: Int64, token: String, secret: String?, tokenType: TokenType, accountType: VKAccountType? = nil,
         refreshToken: String?, firstName: String, lastName: String, avatarUrl: String?, isActive: Bool) {
        self.userId = userId
        self.token = token
        self.secret = secret
        self.tokenType = tokenType
        self.accountType = accountType
        self.refreshToken = refreshToken
        self.firstName = firstName
        self.lastName = lastName
        self.avatarUrl = avatarUrl
        self.isActive = isActive
    }

    /// Accounts saved before `accountType` existed decode it as `nil`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(Int64.self, forKey: .userId)
        token = try c.decode(String.self, forKey: .token)
        secret = try c.decodeIfPresent(String.self, forKey: .secret)
        tokenType = try c.decode(TokenType.self, forKey: .tokenType)
        accountType = try c.decodeIfPresent(VKAccountType.self, forKey: .accountType)
        refreshToken = try c.decodeIfPresent(String.self, forKey: .refreshToken)
        firstName = try c.decode(String.self, forKey: .firstName)
        lastName = try c.decode(String.self, forKey: .lastName)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        isActive = try c.decode(Bool.self, forKey: .isActive)
    }
}

struct VKScopes: OptionSet, Sendable {
    let rawValue: Int

    static let notify        = VKScopes(rawValue: 1)
    static let friends       = VKScopes(rawValue: 2)
    static let photos        = VKScopes(rawValue: 4)
    static let audio         = VKScopes(rawValue: 8)
    static let video         = VKScopes(rawValue: 16)
    static let stories       = VKScopes(rawValue: 64)
    static let pages         = VKScopes(rawValue: 128)
    static let status        = VKScopes(rawValue: 1024)
    static let notes         = VKScopes(rawValue: 2048)
    static let messages      = VKScopes(rawValue: 4096)
    static let wall          = VKScopes(rawValue: 8192)
    static let ads           = VKScopes(rawValue: 32768)
    static let offline       = VKScopes(rawValue: 65536)
    static let docs          = VKScopes(rawValue: 131072)
    static let groups        = VKScopes(rawValue: 262144)
    static let notifications = VKScopes(rawValue: 524288)
    static let stats         = VKScopes(rawValue: 1048576)
    static let email         = VKScopes(rawValue: 4194304)
    static let market        = VKScopes(rawValue: 134217728)

    static let fullAccess: VKScopes = [
        .notify, .friends, .photos, .audio, .video, .stories,
        .pages, .status, .notes, .messages, .wall, .ads,
        .offline, .docs, .groups, .notifications, .stats, .email, .market
    ]
}

enum VKAuthError: Error {
    case invalidCredentials
    case needValidation(validationType: String, phoneMask: String?, redirectUri: String?, validationSid: String?)
    case needCaptcha(sid: String, imgUrl: String)
    case needVKIdCaptcha(captchaUrl: String)
    case tokenRevoked
    case networkError(Error)
    case parsingError
}

extension VKAuthError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidCredentials: "Неверный логин или пароль"
        case .needValidation: "Требуется подтверждение входа"
        case .needCaptcha, .needVKIdCaptcha: "Требуется ввести капчу"
        case .tokenRevoked: "Сессия недействительна. Войдите снова"
        case .networkError(let e): "Ошибка сети: \(e.localizedDescription)"
        case .parsingError: "Не удалось разобрать ответ VK"
        }
    }
}

extension Notification.Name {
    /// Posted on the main thread after the active account changed (or became nil).
    /// Repositories / LongPoll owners observe it to drop caches and restart.
    static let vkActiveAccountDidChange = Notification.Name("vkActiveAccountDidChange")
}
