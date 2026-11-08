import Foundation

/// Stable domain models. Network DTOs must map into these — never drive SwiftUI from raw VK JSON.

struct PeerID: Hashable, Codable, Sendable {
    let raw: Int64
}

struct Conversation: Identifiable, Hashable, Sendable {
    var id: Int64 { peerID.raw }
    let peerID: PeerID
    let displayName: String
    let initials: String
    let lastMessagePreview: String
    let lastUpdatedLabel: String
    let unreadCount: Int
    let isOnline: Bool
    var avatarURL: URL? = nil
    var isMuted = false

    enum Kind: Hashable, Sendable { case user, chat, community }
    var kind: Kind { peerID.raw >= 2_000_000_000 ? .chat : peerID.raw < 0 ? .community : .user }
}

struct ChatMessage: Identifiable, Hashable, Sendable {
    enum DeliveryState: String, Hashable, Sendable {
        case received
        case pending
        case sent
        case failed
    }

    let id: UUID
    let serverID: Int64?
    let peerID: PeerID
    let text: String
    let timestamp: Date
    let isOutgoing: Bool
    var state: DeliveryState
    /// Used for idempotent `messages.send` once live API is enabled.
    let randomID: Int64?
    var attachments: [ChatAttachment] = []
    var quotes:[ChatQuote] = []
}

struct FeedPost: Identifiable, Hashable, Sendable {
    let id: Int64
    let authorName: String
    let authorInitials: String
    let dateLabel: String
    let text: String
    let hasMedia: Bool
    let reactionCount: Int
    let commentCount: Int
    var ownerID: Int64 = 0
    var nativeID: Int64? = nil
    var mediaURL: URL? = nil
    var attachments:[ChatAttachment] = []
    var avatarURL: URL? = nil
    var repostCount = 0
    var viewCount: Int? = nil

    var webURL: URL? {
        guard ownerID != 0, let nativeID else { return nil }
        return URL(string: "https://vk.com/wall\(ownerID)_\(nativeID)")
    }
}

struct UserProfile: Identifiable, Hashable, Sendable {
    let id: Int64
    let displayName: String
    let initials: String
    let city: String?
    let statusText: String?
    var avatarURL: URL? = nil
    var isOnline = false
    var counters: ProfileCounters? = nil
    var university: String? = nil
}

struct ProfileCounters: Hashable, Sendable {
    var friends: Int?
    var communities: Int?
    var photos: Int?
    var videos: Int?
}

enum AppError: Error, LocalizedError, Equatable, Sendable {
    case notAuthenticated
    case capabilityUnavailable(String)
    case offline
    case network(String)
    case decoding
    case fixtureOnly(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Войдите в аккаунт VK ID."
        case .capabilityUnavailable(let feature):
            return feature
        case .offline:
            return "Нет подключения к сети."
        case .network(let message):
            return message
        case .decoding:
            return "Не удалось прочитать ответ сервера."
        case .fixtureOnly(let detail):
            return detail
        }
    }
}

enum LoadState<Value: Equatable>: Equatable {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(AppError)
    case offline
}

struct ChatAttachment: Identifiable, Hashable, Sendable {
    enum Kind: String, Hashable, Sendable { case photo, document, video, audio, voice, sticker, link, graffiti, unsupported }
    let id: String
    let kind: Kind
    let title: String
    let url: URL
    var playbackURL:URL? = nil
    var symbol:String {
        switch kind {
        case .photo,.sticker,.graffiti:return "photo"
        case .video:return "play.rectangle"
        case .audio:return "music.note"
        case .voice:return "waveform"
        case .link:return "link"
        case .document:return "doc"
        case .unsupported:return "paperclip"
        }
    }
}

struct VKUploadFile {
    static func safeName(_ input:String) -> String {
        let base=(input as NSString).lastPathComponent
        let allowed=CharacterSet.alphanumerics.union(CharacterSet(charactersIn:"._- "))
        let cleaned=base.unicodeScalars.map {allowed.contains($0) ? String($0) : "_"}.joined()
        let result=String(cleaned.prefix(120))
        return result.isEmpty || result=="." || result==".." ? "document.bin" : result
    }
}

struct ChatQuote:Identifiable,Hashable,Sendable {
    let id:String
    let title:String
    let text:String
    let attachments:[ChatAttachment]
}
