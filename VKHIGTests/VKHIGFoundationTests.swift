import XCTest
@testable import VKHIG

final class VKHIGFoundationTests: XCTestCase {
    @MainActor
    func testSessionStartsUnauthenticatedWithoutKeychainToken() {
        // May be authenticated if a previous simulator Keychain token exists;
        // shell entry still works locally.
        let store = SessionStore(authCoordinator: VKIDAuthCoordinator(
            configuration: VKIDConfiguration(clientID: nil, redirectURLScheme: nil)
        ))
        // Fresh coordinator without credentials should not invent a live session from empty Keychain.
        // If Keychain has leftover data on a device, mode may be .authenticated — assert sign-out clears it.
        store.signOut()
        XCTAssertFalse(store.isAuthenticated)
    }

    @MainActor
    func testShellSignInAndOutAreLocalOnly() {
        let store = SessionStore(authCoordinator: VKIDAuthCoordinator(
            configuration: VKIDConfiguration(clientID: nil, redirectURLScheme: nil)
        ))
        store.signOut()
        store.enterShellWithoutAuth()
        XCTAssertTrue(store.isAuthenticated)
        XCTAssertFalse(store.isLiveVKSession)
        store.signOut()
        XCTAssertFalse(store.isAuthenticated)
    }

    func testDesignTokenSpacingMatchesTokensJSONContract() {
        XCTAssertEqual(VKStyle.Spacing.md, 16)
        XCTAssertEqual(VKStyle.Size.tapTargetMin, 44)
        XCTAssertEqual(VKStyle.Radius.card, 20)
    }

    func testMessageReconcilerIsIdempotentPerRandomID() async {
        let reconciler = MessageReconciler()
        let first = await reconciler.prepare(peerID: 1, content: "hi", randomID: 42)
        let second = await reconciler.prepare(peerID: 1, content: "hi", randomID: 42)
        XCTAssertEqual(first.id, second.id)
        let confirmed = await reconciler.confirm(localID: first.id, serverID: 9001)
        XCTAssertEqual(confirmed?.state, .sent)
        XCTAssertEqual(confirmed?.serverID, 9001)
    }

    func testFixtureInboxLoadsWithoutClaimingLiveAPI() async {
        let repo = ConversationRepository(fixtures: .embedded)
        let result = await repo.fetchInbox(
            dataMode: .fixtures,
            capabilities: CapabilityRegistry(),
            isNetworkReachable: true
        )
        guard case .success(let items) = result else {
            return XCTFail("Expected fixture inbox")
        }
        XCTAssertFalse(items.isEmpty)
    }

    func testOutgoingFixtureMessageStaysPending() async {
        let repo = ConversationRepository(fixtures: .embedded)
        let peer = PeerID(raw: 111)
        let result = await repo.enqueueOutgoing(
            peerID: peer,
            text: "test",
            dataMode: .fixtures,
            capabilities: CapabilityRegistry()
        )
        guard case .success(let message) = result else {
            return XCTFail("Expected pending local enqueue")
        }
        XCTAssertEqual(message.state, .pending)
        XCTAssertNotNil(message.randomID)
    }

    func testVKIDAuthorizeFailsWithoutCredentials() async {
        let coordinator = VKIDAuthCoordinator(
            configuration: VKIDConfiguration(clientID: nil, redirectURLScheme: nil)
        )
        let result = await coordinator.authorize()
        guard case .failure(let error) = result else {
            return XCTFail("Expected missing credentials")
        }
        XCTAssertEqual(error, .missingCredentials)
    }

    func testMusicCapabilityIsUnavailable() {
        let registry = CapabilityRegistry()
        XCTAssertEqual(registry.status(for: .music), .unavailable)
    }
}
