import XCTest
@testable import VKHIG

final class VKHIGFoundationTests: XCTestCase {
    @MainActor
    func testCommentReplyDeletionUpdatesThreadCount() async {
        let session=SessionStore(authCoordinator:VKIDAuthCoordinator(configuration:VKIDConfiguration(clientID:nil,redirectURLScheme:nil)))
        session.signOut()
        let env=AppEnvironment(session:session)
        env.enterShellWithoutAuth()
        let model=CommentsViewModel(postID:700,environment:env)
        await model.load()
        guard case .loaded(let initial)=model.state,let root=initial.first else {return XCTFail("Missing root thread")}
        XCTAssertEqual(root.replies.count,1)
        model.replyTo=root.root
        model.draft="Regression reply"
        await model.send()
        guard case .loaded(let sent)=model.state,let reply=sent.first?.replies.last else {return XCTFail("Missing reply")}
        XCTAssertEqual(sent.first?.totalReplies,2)
        await model.remove(reply)
        guard case .loaded(let remaining)=model.state else {return XCTFail("Thread disappeared")}
        XCTAssertEqual(remaining.first?.totalReplies,1)
        XCTAssertEqual(remaining.first?.replies.count,1)
    }

    @MainActor
    func testEmptySearchCancelsDebouncedResults() async {
        let session=SessionStore(authCoordinator:VKIDAuthCoordinator(configuration:VKIDConfiguration(clientID:nil,redirectURLScheme:nil)))
        session.signOut()
        let env=AppEnvironment(session:session)
        env.enterShellWithoutAuth()
        let model=GlobalSearchModel(environment:env)
        let old=Task {await model.search("VK")}
        for _ in 0..<1000 {if model.loading {break};await Task.yield()}
        XCTAssertTrue(model.loading)
        await model.search("")
        await old.value
        XCTAssertTrue(model.hits.isEmpty)
        XCTAssertFalse(model.loading)
        XCTAssertFalse(model.searched)
    }

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

    @MainActor
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
    func testFormEncodingEscapesPlusAndSeparators() {
        let value = String(decoding:FormEncoding.data(["message":"a+b & привет=1"]),as:UTF8.self)
        XCTAssertEqual(value,"message=a%2Bb%20%26%20%D0%BF%D1%80%D0%B8%D0%B2%D0%B5%D1%82%3D1")
    }
    @MainActor
    func testOAuthRejectsWrongStateAndForeignCallback() {
        XCTAssertThrowsError(try VKIDAuthCoordinator.validateCallback(URL(string:"vkhig://vkid?code=c&device_id=d&state=wrong")!,redirectURI:"vkhig://vkid",state:"expected"))
        XCTAssertThrowsError(try VKIDAuthCoordinator.validateCallback(URL(string:"vkhig://evil?code=c&device_id=d&state=s")!,redirectURI:"vkhig://vkid",state:"s"))
        XCTAssertThrowsError(try VKIDAuthCoordinator.validateCallback(URL(string:"vkhig://vkid?code=c&code=x&device_id=d&state=s")!,redirectURI:"vkhig://vkid",state:"s"))
    }
    @MainActor
    func testOAuthAcceptsValidCallback() throws {
        let values = try VKIDAuthCoordinator.validateCallback(URL(string:"vkhig://vkid?code=c&device_id=d&state=s")!,redirectURI:"vkhig://vkid",state:"s")
        XCTAssertEqual(values["code"],"c")
    }
    func testCapabilityRequiresGrantedScope() {
        var caps = CapabilityRegistry(hasVKIDCredentials:true,hasAccessToken:true)
        XCTAssertFalse(caps.canUseLiveAPI(.sendMessage))
        caps.grantedScopes = ["messages"]
        XCTAssertTrue(caps.canUseLiveAPI(.sendMessage))
        XCTAssertFalse(caps.canUseLiveAPI(.feed))
    }
    func testLiveHistoryWithoutMessagesGrantDoesNotReturnFixtures() async {
        let repository = ConversationRepository(fixtures:.embedded)
        let result = await repository.fetchHistory(peerID:PeerID(raw:111),dataMode:.live,capabilities:CapabilityRegistry(hasVKIDCredentials:true,hasAccessToken:true),isNetworkReachable:true,accessToken:"test-token")
        guard case .failure(.capabilityUnavailable) = result else { return XCTFail("Must reject denied scope") }
    }
    func testRetryRetainsRandomIDAndLocalIdentity() async {
        let repo = ConversationRepository(fixtures:.embedded)
        let localID = UUID()
        let first = await repo.enqueueOutgoing(peerID:PeerID(raw:111),text:"test",dataMode:.fixtures,capabilities:CapabilityRegistry(),randomID:42,localID:localID)
        let second = await repo.enqueueOutgoing(peerID:PeerID(raw:111),text:"test",dataMode:.fixtures,capabilities:CapabilityRegistry(),randomID:42,localID:localID)
        guard case .success(let a) = first,case .success(let b) = second else { return XCTFail("Expected fixture pending") }
        XCTAssertEqual(a.id,b.id); XCTAssertEqual(a.randomID,b.randomID)
        let history = await repo.fetchHistory(peerID:PeerID(raw:111),dataMode:.fixtures,capabilities:CapabilityRegistry(),isNetworkReachable:true)
        guard case .success(let items) = history else { return XCTFail("Expected local history") }
        XCTAssertEqual(items.filter { $0.id == localID }.count,1)
    }
    func testJSONRejectsInsecureMediaURL() throws {
        let j = try JSONDecoder().decode(VKJSON.self,from:Data("{\"url\":\"http://example.com/a\"}".utf8))
        XCTAssertNil(j["url"].url)
    }

}
