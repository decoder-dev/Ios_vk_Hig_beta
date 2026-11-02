# API capabilities

Public OAuth 2.1 + PKCE uses Apple AuthenticationServices; VKCOM/vkid-ios-sdk 3.0.0 is a protocol reference, not a bundled calling SDK. Client secret never enters the app, logs or CI artifacts. Both requested Actions secrets were saved previously; only the public client ID is materialized by CI.

Default requested scope is vkid.personal_info. Actual OAuth grants and server responses are authoritative. Configure only rights approved for this VK application.

Implemented adapters include:
- users.get/search; friends.get/search/getRequests/add; groups.get/getById/getMembers/getSettings/join/leave/edit/editManager/removeUser; database.getCountries/getCities; account.getProfileInfo/saveProfileInfo.
- messages.getConversations/getConversationsById/getConversationMembers/getHistory/getLongPollServer/markAsRead/send/search/searchConversations/edit/delete/editChat/addChatUser/removeChatUser/pin/unpin.
- newsfeed.get/search; wall.get/getComments/createComment/editComment/deleteComment/post; likes.add/delete; notifications.get/markAsViewed.
- photos album/photo/upload/save methods; docs.getMessagesUploadServer/save; video.get/save; safe media and quote mapping.
- fave.get and typed add/remove methods; stories.get/getById; audio.get only when the actual audio grant is present; calls.start/forceFinish.

Offset/cursor pagination and deduplication cover conversations/history/message search, recipient selection, friends/groups/members, country/city selection, photos/albums/videos, notifications, saved items and music. messages.searchConversations has no offset contract: up to 200 results prompt a narrower query.

Settings offers user-initiated read-only account checks without displaying a token. Successful real-account acceptance is NOT RUN here. Music rights/streams, native incoming-call SDK  cannot be inferred from client ID/secret or simulator tests.

## Current scope — notifications excluded

By user instruction on 02.11.2026, this release has no push notification permission request, APNs/VK registration, push routing, settings toggle, signing entitlement or remote-notification background mode. Launch cleanup unregisters previous local registration and removes this app's pending/delivered notifications. APNs credentials and provider configuration are not release requirements. The direct APNs diagnostic sender and its tests were removed. Normal app signing is still required for physical-device installation.

Current source 8545072 passed Xcode 27/iOS 27 compilation and all 33 unit tests (0 failures) in run 41521893697, job 125539754736. Earlier successful results refer to their recorded source commits. Music rights and native incoming-call SDK/access remain unprovided. VK ID cabinet access is denied by this environment's browser site-safety policy.


## PrivateMusic2 adaptation (validation pending)
Native music module added using PrivateMusic2 @ 68d10a9 as a behavioral reference:
local playlists, persistent paused queue, global mini-player, account-isolated direct-file downloads,
LRC/LRCLIB lyrics and a real local ten-band equalizer. See docs/MUSIC_ADAPTATION.md for precise scope.
New simulator build/unit/UI checks: NOT RUN yet. Live VK music approval and device audio checks:
NOT RUN. Calls deferred; push remains disabled.
