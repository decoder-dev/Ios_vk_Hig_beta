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
}
