import XCTest
@testable import VKHIG

final class VKHIGFoundationTests: XCTestCase {
    func testChatActionUsesChatIDAndRejectsPersonalDialog() throws {
        XCTAssertThrowsError(try VKAction.chat("messages.editChat",peerID:123))
        XCTAssertThrowsError(try VKAction.chat("messages.editChat",peerID:2_000_000_000))
        let action=try VKAction.chat("messages.removeChatUser",peerID:2_000_000_042,values:["member_id":"123"])
        XCTAssertEqual(action.parameters,["chat_id":"42","member_id":"123"])
        XCTAssertFalse(VKAction.allows("owner",isOwner:false,isAdmin:true))
        XCTAssertTrue(VKAction.allows("owner_and_admins",isOwner:false,isAdmin:true))
        XCTAssertFalse(VKAction.allows("unknown",isOwner:false,isAdmin:false))
    }
    func testBookmarkActionsKeepObjectIdentity() throws {
        let add=try VKAction.bookmarkAddition("https://vk.com/wall-42_99?access_key=fixture-key")
        XCTAssertEqual(add.method,"fave.addPost")
        XCTAssertEqual(add.parameters,["owner_id":"-42","id":"99","access_key":"fixture-key"])
        let item=BookmarkItem(id:1,title:"Post",subtitle:"",symbol:"bookmark",kind:"post",ownerID:-42,itemID:99)
        XCTAssertEqual(try VKAction.bookmarkRemoval(item).parameters,["owner_id":"-42","id":"99"])
        XCTAssertThrowsError(try VKAction.bookmarkAddition("https://user:password@example.com/private"))
        XCTAssertThrowsError(try VKAction.bookmarkAddition("http://example.com/"))
        XCTAssertEqual(BookmarkItem.stableID("video:1:2"),BookmarkItem.stableID("video:1:2"))
        XCTAssertNotEqual(BookmarkItem.stableID("video:1:2"),BookmarkItem.stableID("post:1:2"))
    }
    func testUploadNamesCannotInjectMultipartHeaders() {
        let name=VKUploadFile.safeName("../../secret\"\r\nX-Header: injected.pdf")
        XCTAssertFalse(name.contains("\r"));XCTAssertFalse(name.contains("\n"));XCTAssertFalse(name.contains("\""));XCTAssertFalse(name.contains("/"))
        XCTAssertTrue(name.hasSuffix(".pdf"))
        XCTAssertEqual(VKUploadFile.safeName(""),"document.bin")
    }
    func testJSONIntegerOverflowDoesNotCrash() {
        XCTAssertEqual(VKJSON.number(1e100).int,0)
        XCTAssertEqual(VKJSON.number(-1e100).int,0)
        XCTAssertEqual(VKJSON.number(123).int,123)
    }
    func testReplyAndForwardQuotesPreserveAttachmentsAndStayBounded() throws {
        let data=Data("""
        {"reply_message":{"text":"Reply","attachments":[{"type":"link","link":{"url":"https://example.com/","title":"Source"}}]},"fwd_messages":[{"text":"Forward"}]}
        """.utf8)
        let quotes=try JSONDecoder().decode(VKJSON.self,from:data).messageQuotes
        XCTAssertEqual(quotes.count,2)
        XCTAssertEqual(quotes[0].attachments.count,1)
        XCTAssertEqual(quotes[1].text,"Forward")
        XCTAssertEqual(Set(quotes.map(\.id)).count,2)
    }

    @MainActor
    func testAttachmentTypesAndUnsafeStreams() throws {
        let data=Data("""
        [{"type":"audio_message","audio_message":{"id":1,"owner_id":2,"link_mp3":"https://example.com/voice.mp3","duration":3}},
         {"type":"sticker","sticker":{"images":[{"width":64,"url":"https://example.com/sticker.png"}]}},
         {"type":"link","link":{"url":"https://example.com/","title":"Link"}},
         {"type":"audio","audio":{"id":4,"url":"http://example.com/unsafe.mp3"}},
         {"type":"unsupported_fixture","unsupported_fixture":{}}]
        """.utf8)
        let items=try JSONDecoder().decode(VKJSON.self,from:data).chatAttachments
        XCTAssertEqual(items.count,5)
        XCTAssertEqual(items[0].kind,.voice)
        XCTAssertEqual(items[1].kind,.sticker)
        XCTAssertEqual(items[2].kind,.link)
        XCTAssertEqual(items[3].kind,.unsupported)
        XCTAssertNil(items[3].playbackURL)
        XCTAssertEqual(items[4].kind,.unsupported)
    }
    @MainActor
    func testStoriesFlattenGroupsAndExcludeExpiredOrHidden() throws {
        let data=Data("""
        {"profiles":[{"id":1,"first_name":"Test","last_name":"User"}],"groups":[{"id":2,"name":"Group"}],"items":[
        {"stories":[{"id":10,"owner_id":1,"photo":{"sizes":[{"width":100,"url":"https://example.com/story.jpg"}]}}]},
        {"grouped":[{"stories":[{"id":10,"owner_id":-2},{"id":11,"owner_id":-2,"is_expired":true},{"id":12,"owner_id":-2,"can_see":0}]}]}]}
        """.utf8)
        let stories=VKCatalogService.mapStories(try JSONDecoder().decode(VKJSON.self,from:data))
        XCTAssertEqual(stories.count,2)
        XCTAssertEqual(Set(stories.map(\.id)).count,2)
        XCTAssertEqual(stories[0].author,"Test User")
        XCTAssertEqual(stories[1].author,"Group")
        XCTAssertTrue(stories[0].available)
    }
    @MainActor
    func testRecipientPagesDeduplicateAndKeepOffset() async {
        var offsets:[String]=[]
        let model=RecipientPickerModel {method,params in
            XCTAssertEqual(method,"messages.getConversations")
            offsets.append(params["offset"] ?? "")
            let ids=params["offset"]=="0" ? Array(1...100) : [100,101]
            let page=ids.map {id in VKJSON.object(["conversation":.object(["peer":.object(["id":.number(Double(id))])])])}
            return .object(["items":.array(page)])
        }
        await model.load()
        XCTAssertTrue(model.hasMore)
        await model.load(reset:false)
        XCTAssertEqual(offsets,["0","100"])
        XCTAssertEqual(model.peers.count,101)
        XCTAssertFalse(model.hasMore)
    }
    @MainActor
    func testChatAdministrationDoesNotWriteWithoutPermission() async {
        var calls=0
        let model=ChatAdministrationModel(peerID:2_000_000_001) {_,_ in calls+=1;return .number(1)}
        let changed=await model.rename("New name")
        XCTAssertFalse(changed);XCTAssertEqual(calls,0)
        XCTAssertNotNil(model.error)
    }
    @MainActor
    func testChatServerACLOverridesPermissivePolicy() async {
        let model=ChatAdministrationModel(peerID:2_000_000_001) {method,_ in
            if method=="messages.getConversationsById" {
                return .object(["items":.array([.object(["chat_settings":.object(["title":.string("Chat"),"acl":.object(["can_change_info":.bool(false),"can_invite":.bool(true)]),"permissions":.object(["change_info":.string("all")])])])])])
            }
            return .object(["items":.array([])])
        }
        await model.load()
        XCTAssertFalse(model.canEdit)
        XCTAssertTrue(model.canInvite)
    }
    @MainActor
    func testCommunityManagementRefusesUnapprovedRoleChange() async {
        var calls=0
        let model=CommunityAdministrationModel(groupID:42) {_,_ in calls+=1;return .number(1)}
        let user=Friend(id:1,displayName:"Test",initials:"T",isOnline:false,city:nil)
        let result=await model.role("administrator",user:user)
        XCTAssertFalse(result);XCTAssertEqual(calls,0)
    }
    @MainActor
    func testBookmarkDeletionFailureKeepsItem() async {
        let item=BookmarkItem(id:1,title:"Post",subtitle:"",symbol:"bookmark",kind:"post",ownerID:1,itemID:2)
        let model=BookmarksModel {_,_ in throw AppError.network("Denied")}
        model.items=[item]
        await model.remove(item)
        XCTAssertEqual(model.items,[item]);XCTAssertNotNil(model.error)
    }
    @MainActor
    func testProfileBirthdayValidationRejectsInvalidComponents() {
        XCTAssertTrue(ProfileEditorModel.validBirthday("29.02.2000"))
        XCTAssertTrue(ProfileEditorModel.validBirthday("29.02"))
        XCTAssertFalse(ProfileEditorModel.validBirthday("29.02.2001"))
        XCTAssertFalse(ProfileEditorModel.validBirthday("1.2.invalid"))
        XCTAssertFalse(ProfileEditorModel.validBirthday("31.04.2000"))
    }
    @MainActor
    func testProfileSaveUsesCountryAndCityIDs() async {
        var saved:[String:String]=[:]
        let model=ProfileEditorModel {method,params in
            if method=="account.saveProfileInfo" {saved=params;return .object(["changed":.number(1)])}
            return .object(["first_name":.string("Test"),"last_name":.string("User")])
        }
        await model.load();model.country=VKLocationChoice(id:1,title:"Country");model.city=VKLocationChoice(id:2,title:"City")
        await model.save()
        XCTAssertEqual(saved["country_id"],"1");XCTAssertEqual(saved["city_id"],"2")
        XCTAssertFalse(model.saving);XCTAssertNil(model.error)
    }
    @MainActor
    func testMusicCatalogDoesNotRequestWithoutAudioGrant() async {
        var calls=0
        let model=VKMusicCatalogModel {_,_ in calls+=1;return .object([:])}
        await model.load(grants:["vkid.personal_info"])
        XCTAssertEqual(calls,0);XCTAssertNotNil(model.error)
    }
    @MainActor
    func testMusicCatalogKeepsUnavailableTracksWithoutUnsafePlayback() {
        let response=VKJSON.object(["items":.array([.object(["id":.number(1),"owner_id":.number(2),"title":.string("Track"),"url":.string("http://example.com/file.mp3")])])])
        let tracks=VKMusicCatalogModel.map(response)
        XCTAssertEqual(tracks.count,1);XCTAssertNil(tracks[0].url)
    }

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
        let edited=await model.edit(reply,text:"Updated reply")
        XCTAssertTrue(edited)
        guard case .loaded(let changed)=model.state else {return XCTFail("Missing edited reply")}
        XCTAssertEqual(changed.first?.replies.last?.text,"Updated reply")
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
