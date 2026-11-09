import Foundation

/// Account identity used for the OAuth password grant and `sig`-signed ("nohttps") API calls.
/// Each case carries its own public `client_id`/`client_secret` pair and the User-Agent VK expects
/// for that client, so audio/messages scopes issued to it aren't rejected by a mismatched UA.
enum VKAccountType: Int, Codable, CaseIterable, Hashable, Sendable {
    case vkAndroid = 1
    case kateMobile = 2
    case vkMe = 3
    case vkIos = 4
    case vkAdmin = 5

    var title: String {
        switch self {
        case .vkAndroid: "VK Android"
        case .kateMobile: "Kate Mobile"
        case .vkMe: "VK Me"
        case .vkIos: "VK iOS"
        case .vkAdmin: "VK Admin"
        }
    }

    var clientId: String {
        switch self {
        case .vkAndroid: "2274003"
        case .kateMobile: "2685278"
        case .vkMe: "6146827"
        case .vkIos: "3140623"
        case .vkAdmin: "5776857"
        }
    }

    var clientSecret: String {
        switch self {
        case .vkAndroid: "hHbZxrka2uZ6jB1inYsH"
        case .kateMobile: "lxhD8OD7dMsqO7PRjSos"
        case .vkMe: "qVxWRF1CwHERuIrKBnqe"
        case .vkIos: "VeWdmVclDCtn6ihuP1nt"
        case .vkAdmin: "wpeEslv1VnJgE0mkeL04"
        }
    }

    var userAgent: String {
        switch self {
        case .kateMobile: "KateMobileAndroid/95.1 lite-544 (Android 13; SDK 33; arm64-v8a; Xiaomi M2102J20SG; ru)"
        case .vkAndroid: "VKAndroidApp/8.45-17324 (Android 13; SDK 33; arm64-v8a; Pixel 7; ru; 2400x1080)"
        case .vkMe: "VKMeAndroid/1.35-1000 (Android 13; SDK 33; arm64-v8a; Pixel 7; ru; 2400x1080)"
        case .vkIos: "com.vk.vkclient/8.45 (iPhone; iOS 17.4; Scale/3.00)"
        case .vkAdmin: "VKAdminAndroid/2.10 (Android 13; SDK 33; arm64-v8a; Pixel 7; ru)"
        }
    }

    /// `VKClientPreset` is the login-screen-facing type used by `DirectAuthView`.
    var preset: VKClientPreset { VKClientPreset(self) }
}

enum VKApiConstants {
    static let apiVersion = "5.199"
    static let legacyApiVersion = "5.131"
    static let oauthBaseURL = "https://oauth.vk.com"
    static let apiBaseURL = "https://api.vk.com/method"
    static let blankRedirectURI = "https://oauth.vk.com/blank.html"
    /// Bitmask for every scope in `VKScopes.fullAccess`.
    static let fullScopeBitmask = VKScopes.fullAccess.rawValue
    /// Retried once when VK answers `invalid_scope` to the full set (some clients may not request ads/stats/market).
    static let conservativeScopeBitmask = VKScopes.coreAccess.rawValue
}

/// Full shape of a `POST /token` response: success fields and every documented challenge field
/// in one struct, because VK answers both cases with HTTP 200/400 and the same JSON object.
struct VKLoginResponseDTO: Decodable, Sendable {
    let accessToken: String?
    let userId: Int64?
    let expiresIn: Int?
    let secret: String?
    let trustedHash: String?
    let webviewRefreshToken: String?
    let accessTokenId: String?

    let error: String?
    let errorDescription: String?
    let errorType: String?

    let validationType: String?
    let validationSid: String?
    let phoneMask: String?
    let redirectUri: String?
    let restoreSessionId: String?

    let captchaSid: String?
    let captchaImg: String?
    let captchaTs: Double?
    let captchaAttempt: Int?
    let isRefreshEnabled: Bool?
    let redirectUrl: String?
    let banInfo: BanInfo?

    struct BanInfo: Decodable, Sendable {
        let message: String?
        let restoreURL: String?
        enum CodingKeys: String, CodingKey { case message, restoreURL = "restore_url" }
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case userId = "user_id"
        case expiresIn = "expires_in"
        case secret
        case trustedHash = "trusted_hash"
        case webviewRefreshToken = "webview_refresh_token"
        case accessTokenId = "access_token_id"
        case error
        case errorDescription = "error_description"
        case errorType = "error_type"
        case validationType = "validation_type"
        case validationSid = "validation_sid"
        case phoneMask = "phone_mask"
        case redirectUri = "redirect_uri"
        case restoreSessionId = "restore_session_id"
        case captchaSid = "captcha_sid"
        case captchaImg = "captcha_img"
        case captchaTs = "captcha_ts"
        case captchaAttempt = "captcha_attempt"
        case isRefreshEnabled = "is_refresh_enabled"
        case redirectUrl = "redirect_url"
        case banInfo = "ban_info"
    }

    /// Tolerates `user_id` arriving as a JSON number or a numeric string.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try c.decodeIfPresent(String.self, forKey: .accessToken)
        if let n = try? c.decode(Int64.self, forKey: .userId) { userId = n }
        else if let s = try? c.decode(String.self, forKey: .userId) { userId = Int64(s) }
        else { userId = nil }
        expiresIn = try? c.decodeIfPresent(Int.self, forKey: .expiresIn)
        secret = try c.decodeIfPresent(String.self, forKey: .secret)
        trustedHash = try c.decodeIfPresent(String.self, forKey: .trustedHash)
        webviewRefreshToken = try c.decodeIfPresent(String.self, forKey: .webviewRefreshToken)
        accessTokenId = try c.decodeIfPresent(String.self, forKey: .accessTokenId)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        errorDescription = try c.decodeIfPresent(String.self, forKey: .errorDescription)
        errorType = try c.decodeIfPresent(String.self, forKey: .errorType)
        validationType = try c.decodeIfPresent(String.self, forKey: .validationType)
        validationSid = try c.decodeIfPresent(String.self, forKey: .validationSid)
        phoneMask = try c.decodeIfPresent(String.self, forKey: .phoneMask)
        redirectUri = try c.decodeIfPresent(String.self, forKey: .redirectUri)
        restoreSessionId = try c.decodeIfPresent(String.self, forKey: .restoreSessionId)
        if let text = try? c.decode(String.self, forKey: .captchaSid) { captchaSid = text }
        else if let number = try? c.decode(Int64.self, forKey: .captchaSid) { captchaSid = String(number) }
        else { captchaSid = nil }
        captchaImg = try c.decodeIfPresent(String.self, forKey: .captchaImg)
        captchaTs = try? c.decodeIfPresent(Double.self, forKey: .captchaTs)
        captchaAttempt = try? c.decodeIfPresent(Int.self, forKey: .captchaAttempt)
        isRefreshEnabled = try? c.decodeIfPresent(Bool.self, forKey: .isRefreshEnabled)
        redirectUrl = try c.decodeIfPresent(String.self, forKey: .redirectUrl)
        banInfo = try? c.decodeIfPresent(BanInfo.self, forKey: .banInfo)
    }
}

// MARK: - VK ID Ecosystem (passwordless OTP sign-in)

struct EcosystemSendOtpResponse: Decodable, Sendable {
    let status: String?
    let sid: String?
    let codeLength: Int?
    let info: String?
    enum CodingKeys: String, CodingKey { case status, sid, codeLength = "code_length", info }
}

struct EcosystemCheckOtpResponse: Decodable, Sendable {
    let sid: String?
    let profileExist: Bool?
    let canSkipPassword: Bool?
    enum CodingKeys: String, CodingKey { case sid, profileExist = "profile_exist", canSkipPassword = "can_skip_password" }
}

struct EcosystemGetVerificationMethodsResponse: Decodable, Sendable {
    let methods: [String]
    enum CodingKeys: String, CodingKey { case methods }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        methods = try c.decodeIfPresent([String].self, forKey: .methods) ?? []
    }
}

struct AnonymTokenResponse: Decodable, Sendable {
    let token: String
    let expiredAt: Int?
    enum CodingKeys: String, CodingKey { case token, expiredAt = "expired_at" }
}
