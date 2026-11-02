import Foundation

struct Friend: Identifiable, Hashable, Sendable {
    let id: Int64
    let displayName: String
    let initials: String
    let isOnline: Bool
    let city: String?
}

struct FriendRequest: Identifiable, Hashable, Sendable {
    enum Direction: String, Hashable, Sendable { case incoming, outgoing }
    let id: Int64
    let user: Friend
    let direction: Direction
    let subtitle: String
}

struct Community: Identifiable, Hashable, Sendable {
    let id: Int64
    let name: String
    let initials: String
    let membersCount: Int
    let description: String
    let isMember: Bool
}

struct CommentItem: Identifiable, Hashable, Sendable {
    let id: Int64
    let postID: Int64
    let author: String
    let initials: String
    let text: String
    let dateLabel: String
    let replyToID: Int64?
    var authorID: Int64 = 0
}

struct NotificationItem: Identifiable, Hashable, Sendable {
    let id: Int64
    let title: String
    let body: String
    let dateLabel: String
    let symbol: String
    let isUnread: Bool
    var targetURL: URL? = nil
}

struct SearchHit: Identifiable, Hashable, Sendable {
    enum Kind: String, Hashable, Sendable { case person, community, post }
    let id: String
    let kind: Kind
    let title: String
    let subtitle: String
    let initials: String
}

struct PhotoAlbum: Identifiable, Hashable, Sendable {
    let id: Int64
    let title: String
    let count: Int
}

struct PhotoItem: Identifiable, Hashable, Sendable {
    let id: Int64
    let albumID: Int64
    let caption: String
    var url: URL? = nil
    var ownerID: Int64 = 0
}

struct VideoItem: Identifiable, Hashable, Sendable {
    let id: Int64
    let title: String
    let durationLabel: String
    let author: String
    var streamURL: URL? = nil
    var playerURL: URL? = nil
    var ownerID: Int64 = 0
}

struct TrackItem: Identifiable, Hashable, Sendable {
    let id: Int64
    let title: String
    let artist: String
    let durationLabel: String
}

struct PlaylistItem: Identifiable, Hashable, Sendable {
    let id: Int64
    let title: String
    let trackCount: Int
}

struct BookmarkItem: Identifiable, Hashable, Sendable {
    let id: Int64
    let title: String
    let subtitle: String
    let symbol: String
    var targetURL: URL? = nil
}

struct StoryItem: Identifiable, Hashable, Sendable {
    let id: Int64
    let author: String
    let initials: String
}

struct ChatDetails: Equatable, Sendable {
    let peerID: Int64
    let title: String
    let members: [Friend]
}
