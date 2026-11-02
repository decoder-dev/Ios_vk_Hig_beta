# IMPLEMENTATION STATUS — VK HIG

**Updated:** 2026-11-02 · Branch **`main`**  
Build/tests/screenshots: **NOT RUN** (Linux VM — Mac verification only).

Status: `NOT_STARTED` | `IN_PROGRESS` | `UI_DONE` | `INTEGRATED` | `QA_PASSED` | `BLOCKED`

| Screen ID | Status | Files / route | API | Build | Tests | Screenshot | Notes |
|---|---|---|---|---|---|---|---|
| S01 Launch | UI_DONE | `VKHIGApp` auth gate | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | Session restore via Keychain presence |
| S02 VK ID login | UI_DONE | `AuthStubView`, `VKIDAuthCoordinator` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | Placeholders in Info.plist / Secrets.example |
| S03 Onboarding | UI_DONE | `OnboardingView` | local | NOT RUN | NOT RUN | NOT RUN | |
| S04 Feed | UI_DONE | `FeedView` + stories entry | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | Fixture banner |
| S05 Post detail | UI_DONE | `PostDetailView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S06 Comments | UI_DONE | `CommentsView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | Local composer; no fake publish |
| S07 Compose post | UI_DONE | `ComposePostView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | Explicit not-published notice |
| S08 Inbox | UI_DONE | `InboxView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S09 Chat | UI_DONE | `ConversationView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | Pending send; context menu S13 |
| S10 Group chat | UI_DONE | `GroupChatView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | peer ≥ 2e9 |
| S11 Chat info | UI_DONE | `ChatInfoView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S12 Attachments | UI_DONE | `ChatAttachmentsView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | No upload |
| S13 Message actions | UI_DONE | contextMenu on bubbles | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S14 Chat search | UI_DONE | `ChatSearchView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S15 User profile | UI_DONE | `UserProfileView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S16 My profile | UI_DONE | `ProfileView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S17 Edit profile | UI_DONE | `EditProfileView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | Local draft |
| S18 Friends | UI_DONE | `FriendsView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S19 Friend requests | UI_DONE | `FriendRequestsView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S20 Community | UI_DONE | `CommunityView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S21 Communities | UI_DONE | `CommunitiesListView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S22 Members | UI_DONE | `CommunityMembersView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S23 Global search | UI_DONE | `GlobalSearchView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S24 Notifications | UI_DONE | `NotificationsView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S25 Services hub | UI_DONE | `ServicesHubView` | local | NOT RUN | NOT RUN | NOT RUN | Full route catalog |
| S26 Albums | UI_DONE | `PhotoAlbumsView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S27 Photos grid | UI_DONE | `PhotosGridView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S28 Photo viewer | UI_DONE | `PhotoViewerView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | Placeholder bitmap |
| S29 Video list | UI_DONE | `VideoListView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S30 Video player | UI_DONE | `VideoPlayerView` | UNAVAILABLE/NEEDS | NOT RUN | NOT RUN | NOT RUN | No stream without rights |
| S31 Music library | UI_DONE | `MusicLibraryView` | UNAVAILABLE | NOT RUN | NOT RUN | NOT RUN | Play disabled |
| S32 Audio player | UI_DONE | `AudioPlayerView` | UNAVAILABLE | NOT RUN | NOT RUN | NOT RUN | Controls disabled |
| S33 Playlist | UI_DONE | `PlaylistView` | UNAVAILABLE | NOT RUN | NOT RUN | NOT RUN | |
| S34 Settings | UI_DONE | `SettingsHubView` | local | NOT RUN | NOT RUN | NOT RUN | |
| S35 Notif settings | UI_DONE | `NotificationSettingsView` | local | NOT RUN | NOT RUN | NOT RUN | |
| S36 Privacy | UI_DONE | `PrivacySettingsView` | local/NEEDS | NOT RUN | NOT RUN | NOT RUN | |
| S37 Appearance | UI_DONE | `AppearanceSettingsView` | local | NOT RUN | NOT RUN | NOT RUN | |
| S38 Storage | UI_DONE | `StorageSettingsView` | local | NOT RUN | NOT RUN | NOT RUN | |
| S39 Account | UI_DONE | `AccountSettingsView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S40 Bookmarks | UI_DONE | `BookmarksView` | NEEDS_CONFIG | NOT RUN | NOT RUN | NOT RUN | |
| S41 Stories | UI_DONE | `StoryViewerView` | NEEDS_CONFIG/UNAVAIL | NOT RUN | NOT RUN | NOT RUN | Shell only |
| S42 Incoming call | UI_DONE | `IncomingCallView` | UNAVAILABLE | NOT RUN | NOT RUN | NOT RUN | SDK not linked; buttons disabled |
| S43 Error states | UI_DONE | `ErrorDemoView` | local | NOT RUN | NOT RUN | NOT RUN | |
| S44 Actions sheet | UI_DONE | `ActionsDemoView` | local | NOT RUN | NOT RUN | NOT RUN | |

## Navigation

- Typed `AppRoute` + `withAppRoutes()` on root stacks
- Tabs: Feed / Services / Messages / Music / Profile

## Credentials

- Placeholders: `Info.plist` `VK_CLIENT_ID=YOUR_VK_ID_CLIENT_ID`, `Config/Secrets.example.xcconfig`, `Secrets.example.md`
- Jessica fills locally — do not wait in-repo
