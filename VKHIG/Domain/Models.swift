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
}

struct UserProfile: Identifiable, Hashable, Sendable {
    let id: Int64
    let displayName: String
    let initials: String
    let city: String?
    let statusText: String?
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
            return "\(feature) is unavailable for this app configuration"
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
