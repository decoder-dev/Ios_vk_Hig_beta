import SwiftUI

struct AppRouteDestination: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .conversation(let id):
            ConversationView(conversation: Conversation(peerID:PeerID(raw:id),displayName:"VK \(id)",initials:"VK",lastMessagePreview:"",lastUpdatedLabel:"",unreadCount:0,isOnline:false))
        case .albumPhotos(let id):
            PhotosGridView(albumID:id)
        case .onboarding:
            OnboardingView()
        case .postDetail(let id):
            PostDetailView(postID: id)
        case .comments(let id):
            CommentsView(postID: id)
        case .composePost:
            ComposePostView()
        case .groupChat(let id):
            GroupChatView(chatID: id)
        case .chatInfo(let id):
            ChatInfoView(peerID: id)
        case .chatAttachments(let id):
            ChatAttachmentsView(peerID: id)
        case .chatSearch(let id):
            ChatSearchView(peerID: id)
        case .userProfile(let id):
            UserProfileView(userID: id)
        case .editProfile:
            EditProfileView()
        case .friends:
            FriendsView()
        case .friendRequests:
            FriendRequestsView()
        case .community(let id):
            CommunityView(communityID: id)
        case .communities:
            CommunitiesListView()
        case .communityMembers(let id):
            CommunityMembersView(communityID: id)
        case .globalSearch:
            GlobalSearchView()
        case .notifications:
            NotificationsView()
        case .photoAlbums:
            PhotoAlbumsView()
        case .photos:
            PhotosGridView()
        case .photoViewer(let id):
            PhotoViewerView(photoID: id)
        case .videoList:
            VideoListView()
        case .videoPlayer(let id):
            VideoPlayerView(videoID: id)
        case .musicLibrary:
            MusicLibraryView()
        case .audioPlayer:
            AudioPlayerView()
        case .playlist(let id):
            PlaylistView(playlistID: id)
        case .settings:
            SettingsHubView()
        case .notificationSettings:
            NotificationSettingsView()
        case .privacySettings:
            PrivacySettingsView()
        case .appearanceSettings:
            AppearanceSettingsView()
        case .storageSettings:
            StorageSettingsView()
        case .accountSettings:
            AccountSettingsView()
        case .bookmarks:
            BookmarksView()
        case .story(let id):
            StoryViewerView(storyID: id)
        case .incomingCall:
            IncomingCallView()
        case .errorDemo:
            ErrorDemoView()
        case .actionsDemo:
            ActionsDemoView()
        }
    }
}

extension View {
    func withAppRoutes() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            AppRouteDestination(route: route)
        }
    }
}
