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

    func testAdapterInjectsTokenOnlyForVKAPI() {
        let a = VKRequestAdapter()
        a.setCredentials(VKCredentials(token: "T", tokenType: .official))
        let r = a.adapt(URLRequest(url: URL(string: "https://api.vk.com/method/users.get?access_token=old")!))
        XCTAssertEqual(URLComponents(url: r.url!, resolvingAgainstBaseURL: false)?.queryItems?.filter { $0.name == "access_token" }.map(\.value), ["T"])
        XCTAssertEqual(r.value(forHTTPHeaderField: "User-Agent"), "VK/6.35")
        let other = a.adapt(URLRequest(url: URL(string: "https://example.com/x")!))
        XCTAssertEqual(other.url?.absoluteString, "https://example.com/x")
    }

    func testDirectAuthParsesChallenges() {
        func err(_ json: String) -> VKAuthError? {
            do { _ = try VKDirectAuthService.parse(Data(json.utf8)); return nil } catch { return error as? VKAuthError }
        }
        if case .needValidation(let t, let m, _)? = err(#"{"error":"need_validation","validation_type":"2fa_sms","phone_mask":"+7 *** 12"}"#) {
            XCTAssertEqual(t, "2fa_sms"); XCTAssertEqual(m, "+7 *** 12")
        } else { XCTFail() }
        if case .needCaptcha(let sid, _)? = err(#"{"error":"need_captcha","captcha_sid":"9","captcha_img":"https://x/c.jpg"}"#) {
            XCTAssertEqual(sid, "9")
        } else { XCTFail() }
        if case .invalidCredentials? = err(#"{"error":"invalid_client"}"#) {} else { XCTFail() }
        let ok = try? VKDirectAuthService.parse(Data(#"{"access_token":"abc","user_id":5}"#.utf8))
        XCTAssertEqual(ok?.userId, 5)
    }

    func testScopesFullAccess() {
        XCTAssertTrue(VKScopes.fullAccess.contains([.messages, .market, .offline]))
    }
}
