# API capabilities

Public OAuth 2.1 + PKCE uses Apple AuthenticationServices; VKCOM/vkid-ios-sdk 3.0.0 is a protocol reference, not a bundled calling SDK. Client secret never enters the app, logs or CI artifacts. Both requested Actions secrets were saved previously; only the public client ID is materialized by CI.

Default requested scope is vkid.personal_info. Actual OAuth grants and server responses are authoritative. Configure only rights approved for this VK application.

Implemented adapters include:
- users.get/search; friends.get/search/getRequests/add; groups.get/getById/getMembers/getSettings/join/leave/edit/editManager/removeUser; database.getCountries/getCities; account.getProfileInfo/saveProfileInfo.
- messages.getConversations/getConversationsById/getConversationMembers/getHistory/getLongPollServer/markAsRead/send/search/searchConversations/edit/delete/editChat/addChatUser/removeChatUser/pin/unpin.
- newsfeed.get/search; wall.get/getComments/createComment/editComment/deleteComment/post; likes.add/delete; notifications.get/markAsViewed.
- photos album/photo/upload/save methods; docs.getMessagesUploadServer/save; video.get/save; safe media and quote mapping.
- fave.get and typed add/remove methods; stories.get/getById; audio.get only when the actual audio grant is present; calls.start/forceFinish; account.registerDevice/unregisterDevice.

Offset/cursor pagination and deduplication cover conversations/history/message search, recipient selection, friends/groups/members, country/city selection, photos/albums/videos, notifications, saved items and music. messages.searchConversations has no offset contract: up to 200 results prompt a narrower query.

Settings offers user-initiated read-only account checks without displaying a token. Successful real-account acceptance is NOT RUN here. Music rights/streams, native incoming-call SDK and APNs/VK provider setup cannot be inferred from client ID/secret or simulator tests.
