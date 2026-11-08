import Foundation

/// Bundled fictitious data. Provenance: NOT a real VK response.
struct FixtureStore: Sendable {
    var conversations: [Conversation]
    var messagesByPeer: [Int64: [ChatMessage]]
    var feed: [FeedPost]
    var profile: UserProfile

    static func loadBundledOrEmbedded() -> FixtureStore {
        if let url = Bundle.main.url(forResource: "preview_data", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(FixtureDTO.self, from: data) {
            return decoded.asDomain()
        }
        return .embedded
    }

    static let embedded: FixtureStore = {
        let peer = PeerID(raw: 111)
        let conversations: [Conversation] = [
            .init(peerID: peer, displayName: "Анастасия", initials: "АС",
                  lastMessagePreview: "Скинешь фото?", lastUpdatedLabel: "09:40",
                  unreadCount: 2, isOnline: true),
            .init(peerID: PeerID(raw: 2_000_000_005), displayName: "Друзья", initials: "ДР",
                  lastMessagePreview: "Встречаемся в 19:00?", lastUpdatedLabel: "09:28",
                  unreadCount: 7, isOnline: false),
            .init(peerID: PeerID(raw: 112), displayName: "Дмитрий", initials: "ДМ",
                  lastMessagePreview: "Спасибо, договорились", lastUpdatedLabel: "Вчера",
                  unreadCount: 0, isOnline: false)
        ]
        let now = Date()
        let messages: [ChatMessage] = [
            .init(id: UUID(), serverID: 990, peerID: peer, text: "Привет! Как дела?",
                  timestamp: now.addingTimeInterval(-300), isOutgoing: false, state: .received, randomID: nil),
            .init(id: UUID(), serverID: 991, peerID: peer, text: "Хорошо, спасибо!",
                  timestamp: now.addingTimeInterval(-240), isOutgoing: true, state: .sent, randomID: nil),
            .init(id: UUID(), serverID: 992, peerID: peer, text: "Может, сходим куда-нибудь?",
                  timestamp: now.addingTimeInterval(-180), isOutgoing: false, state: .received, randomID: nil)
        ]
        let feed: [FeedPost] = [
            .init(id: 700, authorName: "Путешествия по России", authorInitials: "ПР",
                  dateLabel: "вчера в 18:24",
                  text: "Осенние пейзажи Алтая — делюсь кадрами с поездки.",
                  hasMedia: true, reactionCount: 1486, commentCount: 87),
            .init(id: 701, authorName: "Елена Соколова", authorInitials: "ЕС",
                  dateLabel: "сегодня в 10:12",
                  text: "Наконец-то закончила новый проект!",
                  hasMedia: false, reactionCount: 42, commentCount: 3)
        ]
        let profile = UserProfile(
            id: 1,
            displayName: "Демо-пользователь",
            initials: "ДП",
            city: "Москва",
            statusText: "Демо-профиль, не аккаунт VK",
            isOnline: true,
            counters: ProfileCounters(friends: 342, communities: 28, photos: 1247, videos: 126),
            university: "МГУ"
        )
        return FixtureStore(
            conversations: conversations,
            messagesByPeer: [peer.raw: messages],
            feed: feed,
            profile: profile
        )
    }()
}

// MARK: - JSON DTO (bundle)

private struct FixtureDTO: Decodable {
    let conversations: [ConversationDTO]
    let messages: [MessageDTO]
    let feed: [FeedDTO]

    struct ConversationDTO: Decodable {
        let peer_id: Int64
        let name: String
        let unread_count: Int
        let last_message: String
        let online: Bool
        let last_updated: String?
        let muted: Bool?
    }

    struct MessageDTO: Decodable {
        let id: Int64
        let peer_id: Int64
        let text: String
        let outgoing: Bool
        let minutes_ago: Int?
    }

    struct FeedDTO: Decodable {
        let id: Int64
        let author: String
        let text: String
        let media_kind: String?
        let date_label: String?
        let owner_id: Int64?
        let likes: Int?
        let comments: Int?
        let reposts: Int?
        let views: Int?
    }

    func asDomain() -> FixtureStore {
        let convs: [Conversation] = conversations.map { dto in
            let initials = VKCatalogService.initials(dto.name)
            var conversation = Conversation(
                peerID: PeerID(raw: dto.peer_id),
                displayName: dto.name,
                initials: initials,
                lastMessagePreview: dto.last_message,
                lastUpdatedLabel: dto.last_updated ?? "",
                unreadCount: dto.unread_count,
                isOnline: dto.online
            )
            conversation.isMuted = dto.muted ?? false
            return conversation
        }
        var byPeer: [Int64: [ChatMessage]] = [:]
        let base = Date()
        for (index, dto) in messages.enumerated() {
            let msg = ChatMessage(
                id: UUID(),
                serverID: dto.id,
                peerID: PeerID(raw: dto.peer_id),
                text: dto.text,
                timestamp: base.addingTimeInterval(-TimeInterval((dto.minutes_ago ?? (messages.count - index)) * 60)),
                isOutgoing: dto.outgoing,
                state: dto.outgoing ? .sent : .received,
                randomID: nil
            )
            byPeer[dto.peer_id, default: []].append(msg)
        }
        let posts: [FeedPost] = feed.map { dto in
            FeedPost(
                id: dto.id,
                authorName: dto.author,
                authorInitials: VKCatalogService.initials(dto.author),
                dateLabel: dto.date_label ?? "",
                text: dto.text,
                hasMedia: dto.media_kind != nil,
                reactionCount: dto.likes ?? 0,
                commentCount: dto.comments ?? 0,
                ownerID: dto.owner_id ?? 0,
                repostCount: dto.reposts ?? 0,
                viewCount: dto.views
            )
        }
        return FixtureStore(
            conversations: convs,
            messagesByPeer: byPeer,
            feed: posts,
            profile: FixtureStore.embedded.profile
        )
    }
}
