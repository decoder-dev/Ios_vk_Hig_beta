import SwiftUI

struct AppRouteDestination: View {
    let route: AppRoute

    var body: AnyView {
        switch route {
        case .conversation(let id):
            return AnyView(ConversationView(conversation: Conversation(peerID:PeerID(raw:id),displayName:"VK \(id)",initials:"VK",lastMessagePreview:"",lastUpdatedLabel:"",unreadCount:0,isOnline:false)))
        case .albumPhotos(let id):
            return AnyView(PhotosGridView(albumID:id))
        case .onboarding:
            return AnyView(OnboardingView())
        case .postDetail(let id):
            return AnyView(PostDetailView(postID: id))
        case .comments(let id):
            return AnyView(CommentsView(postID: id))
        case .composePost:
            return AnyView(ComposePostView())
        case .groupChat(let id):
            return AnyView(GroupChatView(chatID: id))
        case .chatInfo(let id):
            return AnyView(ChatInfoView(peerID: id))
        case .chatAttachments(let id):
            return AnyView(ChatAttachmentsView(peerID: id))
        case .chatSearch(let id):
            return AnyView(ChatSearchView(peerID: id))
        case .userProfile(let id):
            return AnyView(UserProfileView(userID: id))
        case .editProfile:
            return AnyView(EditProfileView())
        case .friends:
            return AnyView(FriendsView())
        case .friendRequests:
            return AnyView(FriendRequestsView())
        case .community(let id):
            return AnyView(CommunityView(communityID: id))
        case .communities:
            return AnyView(CommunitiesListView())
        case .communityMembers(let id):
            return AnyView(CommunityMembersView(communityID: id))
        case .globalSearch:
            return AnyView(GlobalSearchView())
        case .notifications:
            return AnyView(NotificationsView())
        case .photoAlbums:
            return AnyView(PhotoAlbumsView())
        case .photos:
            return AnyView(PhotosGridView())
        case .photoViewer(let id):
            return AnyView(PhotoViewerView(photoID: id))
        case .videoList:
            return AnyView(VideoListView())
        case .videoPlayer(let id):
            return AnyView(VideoPlayerView(videoID: id))
        case .musicLibrary:
            return AnyView(MusicLibraryView())
        case .audioPlayer:
            return AnyView(AudioPlayerView())
        case .playlist(let id):
            return AnyView(PlaylistView(playlistID: id))
        case .settings:
            return AnyView(SettingsHubView())
        case .notificationSettings:
            return AnyView(NotificationSettingsView())
        case .privacySettings:
            return AnyView(PrivacySettingsView())
        case .appearanceSettings:
            return AnyView(AppearanceSettingsView())
        case .storageSettings:
            return AnyView(StorageSettingsView())
        case .accountSettings:
            return AnyView(AccountSettingsView())
        case .bookmarks:
            return AnyView(BookmarksView())
        case .story(let id):
            return AnyView(StoryViewerView(storyID: id))
        case .incomingCall:
            return AnyView(IncomingCallView())
        case .errorDemo:
            return AnyView(ErrorDemoView())
        case .actionsDemo:
            return AnyView(ActionsDemoView())
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
