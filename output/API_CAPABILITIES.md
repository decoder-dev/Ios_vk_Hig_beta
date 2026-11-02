# API capabilities

Official public OAuth 2.1 + PKCE is implemented using Apple AuthenticationServices. VKCOM/vkid-ios-sdk 3.0.0 served as protocol reference; it is not bundled or modified. No confidential secret is shipped.

The OAuth response grants determine P0 repository access; server permission errors remain authoritative for catalog methods. Default requested scope: vkid.personal_info. Configure additional scopes ONLY if granted to this app in the VK cabinet.

Implemented method adapters: users.get; messages.getConversations/getHistory/send/search/delete/getConversationsById; newsfeed.get; wall.getComments/createComment/post; likes.add/delete; friends.get/getRequests/add; groups.get/getById/getMembers; users.search/groups.search; notifications.get; photos.getAlbums/getAll/get/getMessagesUploadServer/saveMessagesPhoto; docs.getMessagesUploadServer/save; video.get; fave.get.

First live-success verification: NOT RUN. No user access token available. VK music catalog and native incoming calling require official authorization/SDK. Local audio and conference-link calling are implemented. APNs device registration requires signed entitlements and VK push-provider configuration.

Additional adapters: wall.deleteComment/editComment; newsfeed.search; notifications.markAsViewed; calls.start/forceFinish; account.registerDevice/unregisterDevice. Offset/cursor pagination covers friends, groups, members, albums, photos, videos, notifications and bookmarks.

Server-side friends.search and paged peer-specific messages.search are implemented; message search pages deduplicate by server ID. Simulator build, 17 unit and 3 UI tests PASS at main 774b58e; real API acceptance is still NOT RUN.
