import Foundation

/// Typed navigation for all kit screen IDs (S01–S44).
enum AppRoute: Hashable, Identifiable {
    case conversation(Int64)
    case albumPhotos(Int64)
    case onboarding
    case postDetail(Int64)
    case comments(Int64)
    case composePost
    case groupChat(Int64)
    case chatInfo(Int64)
    case chatAttachments(Int64)
    case chatSearch(Int64)
    case userProfile(Int64)
    case editProfile
    case friends
    case friendRequests
    case community(Int64)
    case communities
    case communityMembers(Int64)
    case globalSearch
    case notifications
    case photoAlbums
    case photos
    case photoViewer(Int64)
    case videoList
    case videoPlayer(Int64)
    case musicLibrary
    case audioPlayer
    case playlist(Int64)
    case settings
    case notificationSettings
    case privacySettings
    case appearanceSettings
    case storageSettings
    case accountSettings
    case bookmarks
    case story(Int64)
    case incomingCall
    case errorDemo
    case actionsDemo

    var id: String { String(describing: self) }

    var screenID: String {
        switch self {
        case .conversation: "S09"
        case .albumPhotos: "S27"
        case .onboarding: "S03"
        case .postDetail: "S05"
        case .comments: "S06"
        case .composePost: "S07"
        case .groupChat: "S10"
        case .chatInfo: "S11"
        case .chatAttachments: "S12"
        case .chatSearch: "S14"
        case .userProfile: "S15"
        case .editProfile: "S17"
        case .friends: "S18"
        case .friendRequests: "S19"
        case .community: "S20"
        case .communities: "S21"
        case .communityMembers: "S22"
        case .globalSearch: "S23"
        case .notifications: "S24"
        case .photoAlbums: "S26"
        case .photos: "S27"
        case .photoViewer: "S28"
        case .videoList: "S29"
        case .videoPlayer: "S30"
        case .musicLibrary: "S31"
        case .audioPlayer: "S32"
        case .playlist: "S33"
        case .settings: "S34"
        case .notificationSettings: "S35"
        case .privacySettings: "S36"
        case .appearanceSettings: "S37"
        case .storageSettings: "S38"
        case .accountSettings: "S39"
        case .bookmarks: "S40"
        case .story: "S41"
        case .incomingCall: "S42"
        case .errorDemo: "S43"
        case .actionsDemo: "S44"
        }
    }
}
