import XCTest
@testable import VKHIG

final class VKAccountsTests: XCTestCase {
    private let hex85 = String(repeating: "a1", count: 42) + "f"

    func testParsesBareHexToken() {
        XCTAssertEqual(VKTokenParser.parse(hex85)?.token, hex85)
    }
    func testParsesJSON() {
        let p = VKTokenParser.parse(#"{"token":"\#(hex85)","user_id":12345}"#)
        XCTAssertEqual(p, ParsedVKToken(token: hex85, userId: 12345))
    }
    func testParsesRedirectURL() {
        let p = VKTokenParser.parse("https://oauth.vk.com/blank.html#access_token=\(hex85)&expires_in=0&user_id=7")
        XCTAssertEqual(p, ParsedVKToken(token: hex85, userId: 7))
    }
    func testRejectsGarbage() { XCTAssertNil(VKTokenParser.parse("hello")) }

    func testDirectAuthParsesChallenges() {
        func err(_ json: String) -> VKAuthError? {
            do { _ = try VKDirectAuthService.parse(Data(json.utf8)); return nil } catch { return error as? VKAuthError }
        }
        if case .needValidation(let t, let m, _, let sid)? = err(
            #"{"error":"need_validation","validation_type":"2fa_sms","phone_mask":"+7 *** 12","validation_sid":"42"}"#) {
            XCTAssertEqual(t, "2fa_sms"); XCTAssertEqual(m, "+7 *** 12"); XCTAssertEqual(sid, "42")
        } else { XCTFail() }
        if case .needCaptcha(let sid, _)? = err(#"{"error":"need_captcha","captcha_sid":"9","captcha_img":"https://x/c.jpg"}"#) {
            XCTAssertEqual(sid, "9")
        } else { XCTFail() }
        if case .invalidCredentials? = err(#"{"error":"invalid_client"}"#) {} else { XCTFail() }
        let ok = try? VKDirectAuthService.parse(Data(#"{"access_token":"abc","user_id":5,"secret":"s","trusted_hash":"h"}"#.utf8))
        XCTAssertEqual(ok?.userId, 5); XCTAssertEqual(ok?.secret, "s"); XCTAssertEqual(ok?.trustedHash, "h")
    }

    func testScopesFullAccess() {
        XCTAssertTrue(VKScopes.fullAccess.contains([.messages, .market, .offline]))
    }

    func testAccountTypePresetsMatchKnownClients() {
        XCTAssertEqual(VKAccountType.kateMobile.clientId, "2685278")
        XCTAssertEqual(VKAccountType.vkAndroid.clientId, "2274003")
        XCTAssertEqual(VKAccountType.vkIos.clientId, "3140623")
        XCTAssertEqual(VKAccountType.vkMe.clientId, "6146827")
        XCTAssertEqual(VKAccountType.vkAdmin.clientId, "5776857")
        XCTAssertEqual(VKClientPreset.all.count, VKAccountType.allCases.count)
    }

    func testSignatureIsDeterministicMD5() {
        let sig = VKAPISession.signature(method: "users.get", params: ["v": "5.199", "access_token": "T"], secret: "s3cr3t")
        XCTAssertEqual(sig.count, 32)
        XCTAssertEqual(sig, VKAPISession.signature(method: "users.get", params: ["v": "5.199", "access_token": "T"], secret: "s3cr3t"))
    }

    func testDeviceIdentityIsStableAcrossReads() {
        XCTAssertEqual(VKDeviceIdentity.current, VKDeviceIdentity.current)
        XCTAssertFalse(VKDeviceIdentity.current.isEmpty)
    }

    func testQRLoginExtractsAuthHashFromURLAndBareString() {
        XCTAssertEqual(VKQRLoginService.authHash(from: "https://vk.com/auth_by_code#auth_hash=abcDEF123456789012"),
                       "abcDEF123456789012")
        XCTAssertEqual(VKQRLoginService.authHash(from: "abcDEF123456789012"), "abcDEF123456789012")
        XCTAssertNil(VKQRLoginService.authHash(from: "short"))
    }

    func testDirectAuthMapsEveryFailureToAnActionableError() {
        func err(_ json: String) -> VKAuthError? {
            do { _ = try VKDirectAuthService.parse(Data(json.utf8)); return nil } catch { return error as? VKAuthError }
        }
        if case .wrongCode? = err(#"{"error":"invalid_request","error_description":"code is invalid","error_type":"wrong_otp"}"#) {} else { XCTFail("wrong otp") }
        if case .tooManyAttempts? = err(#"{"error":"9;Flood control"}"#) {} else { XCTFail("flood") }
        if case .tooManyAttempts? = err(#"{"error":"invalid_request","error_type":"password_bruteforce_attempt"}"#) {} else { XCTFail("bruteforce") }
        if case .invalidScope? = err(#"{"error":"invalid_scope"}"#) {} else { XCTFail("scope") }
        if case .invalidCredentials? = err(#"{"error":"invalid_client","error_description":"Username or password is incorrect"}"#) {} else { XCTFail("password") }
        if case .accountBlocked(let message, let restore)? = err(#"{"error":"need_validation","ban_info":{"message":"frozen","restore_url":"https://vk.com/restore"}}"#) {
            XCTAssertEqual(message, "frozen"); XCTAssertEqual(restore, "https://vk.com/restore")
        } else { XCTFail("ban") }
        if case .needValidation(let type, _, let redirect, _)? = err(#"{"error":"need_validation","redirect_uri":"https://m.vk.com/login?act=authcheck"}"#) {
            XCTAssertEqual(type, "web"); XCTAssertEqual(redirect, "https://m.vk.com/login?act=authcheck")
        } else { XCTFail("web validation") }
        if case .needCaptcha(let sid, _)? = err(#"{"error":"need_captcha","captcha_sid":123456,"captcha_img":"https://api.vk.com/captcha.php?sid=1"}"#) {
            XCTAssertEqual(sid, "123456")
        } else { XCTFail("numeric captcha sid") }
        if case .server(let text)? = err(#"{"error":"something_new","error_description":"Try later"}"#) {
            XCTAssertTrue(text.contains("Try later"))
        } else { XCTFail("unknown error keeps VK text") }
    }

    func testLoginNormalizationKeepsEmailAndCleansPhone() {
        XCTAssertEqual(VKDirectAuthService.normalizedLogin("  user@example.com \n"), "user@example.com")
        XCTAssertEqual(VKDirectAuthService.normalizedLogin("+7 (999) 123-45-67"), "+79991234567")
        XCTAssertEqual(VKDirectAuthService.normalizedLogin("8 999 123 45 67"), "89991234567")
        XCTAssertEqual(VKDirectAuthService.normalizedLogin("durov"), "durov")
    }

    func testOAuthLandingPageOnBothDomains() {
        let com = URL(string: "https://oauth.vk.com/blank.html#access_token=abc&user_id=42&expires_in=0")!
        let ru = URL(string: "https://oauth.vk.ru/blank.html#access_token=def&user_id=7")!
        XCTAssertTrue(VKOAuthRedirect.isBlankPage(com))
        XCTAssertTrue(VKOAuthRedirect.isBlankPage(ru))
        XCTAssertFalse(VKOAuthRedirect.isBlankPage(URL(string: "https://oauth.vk.com/authorize?client_id=1")!))
        XCTAssertFalse(VKOAuthRedirect.isBlankPage(URL(string: "https://evil.example/blank.html#access_token=x")!))
        XCTAssertEqual(VKOAuthRedirect.values(com)["access_token"], "abc")
        XCTAssertEqual(VKOAuthRedirect.values(ru)["user_id"], "7")
        XCTAssertEqual(VKOAuthRedirect.values(URL(string: "https://oauth.vk.com/blank.html?error=access_denied")!)["error"], "access_denied")
    }

    func testBenignWebViewErrorsDoNotFailLogin() {
        XCTAssertTrue(VKOAuthRedirect.isBenign(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)))
        XCTAssertTrue(VKOAuthRedirect.isBenign(NSError(domain: "WebKitErrorDomain", code: 102)))
        XCTAssertFalse(VKOAuthRedirect.isBenign(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)))
    }

    @MainActor
    func testSecurityCheckRedirectValues() {
        let url = URL(string: "https://oauth.vk.com/blank.html#success=1&access_token=tok&user_id=5")!
        let values = DirectAuthViewModel.fragmentValues(url)
        XCTAssertEqual(values["success"], "1"); XCTAssertEqual(values["access_token"], "tok"); XCTAssertEqual(values["user_id"], "5")
    }

    func testAPIErrorBodyReadsChallengeFields() throws {
        let json = #"{"error":{"error_code":14,"error_msg":"Captcha needed","captcha_sid":987,"captcha_img":"https://api.vk.com/captcha.php?sid=987"}}"#
        let envelope = try JSONDecoder().decode(VKAPIEnvelope<Int>.self, from: Data(json.utf8))
        XCTAssertEqual(envelope.error?.error_code, 14)
        XCTAssertEqual(envelope.error?.captcha_sid, "987")
        XCTAssertNotNil(envelope.error?.captcha_img)
    }
}
