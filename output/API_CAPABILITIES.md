# API capabilities

Official public OAuth 2.1 + PKCE is implemented using Apple AuthenticationServices. VKCOM/vkid-ios-sdk 3.0.0 served as protocol reference; it is not bundled or modified. No confidential secret is shipped.

The OAuth response grants determine P0 repository access; server permission errors remain authoritative for catalog methods. Default requested scope: vkid.personal_info. Configure additional scopes ONLY if granted to this app in the VK cabinet.

Implemented method adapters: users.get; messages.getConversations/getHistory/send/search/delete/getConversationsById; newsfeed.get; wall.getComments/createComment/post; likes.add/delete; friends.get/getRequests/add; groups.get/getById/getMembers; users.search/groups.search; notifications.get; photos.getAlbums/getAll/get/getMessagesUploadServer/saveMessagesPhoto; docs.getMessagesUploadServer/save; video.get; fave.get.

First live-success verification: NOT RUN. No user access token available. Music and calling remain unsupported without official authorization.
