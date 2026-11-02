import Foundation

// Synthetic preview data. Never populate production sessions from these fixtures.
struct VKConversationPreview: Identifiable, Hashable {
    let id: Int64
    let displayName: String
    let initials: String
    let lastMessage: String
    let lastUpdated: String
    let unreadCount: Int
    let online: Bool
}

struct VKChatMessage: Identifiable, Hashable {
    enum State: String, Hashable { case received, pending, sent, failed }
    let id: UUID
    let serverID: Int64?
    let text: String
    let time: String
    let outgoing: Bool
    var state: State
}

struct VKFeedPreview: Identifiable, Hashable {
    let id: Int64
    let author: String
    let initials: String
    let dateDescription: String
    let content: String
    let hasMedia: Bool
    let reactions: Int
    let comments: Int
}

enum ReferenceFixtures {
    static let conversations: [VKConversationPreview] = [
        .init(id: 1, displayName: "Анастасия", initials: "АС", lastMessage: "Скинешь фото? ☺", lastUpdated: "09:40", unreadCount: 2, online: true),
        .init(id: 2_000_000_021, displayName: "Друзья", initials: "ДР", lastMessage: "Встречаемся в 19:00?", lastUpdated: "09:28", unreadCount: 7, online: false),
        .init(id: 3, displayName: "Дмитрий", initials: "ДМ", lastMessage: "Договорились, спасибо!", lastUpdated: "Вчера", unreadCount: 0, online: true),
        .init(id: 4, displayName: "Мария", initials: "МВ", lastMessage: "Точно, так и сделаем", lastUpdated: "Вчера", unreadCount: 0, online: false)
    ]
    static let messages: [VKChatMessage] = [
        .init(id: UUID(), serverID: 100, text: "Привет! Как дела?", time: "09:12", outgoing: false, state: .received),
        .init(id: UUID(), serverID: 101, text: "Привет! Всё отлично, а у тебя?", time: "09:14", outgoing: true, state: .sent),
        .init(id: UUID(), serverID: 102, text: "Тоже хорошо! Может, сходим куда-нибудь?", time: "09:15", outgoing: false, state: .received),
        .init(id: UUID(), serverID: 103, text: "Давай, на выходных прогуляемся.", time: "09:16", outgoing: true, state: .sent)
    ]
    static let feed: [VKFeedPreview] = [
        .init(id: 200, author: "Путешествия по России", initials: "ПР", dateDescription: "вчера в 18:24", content: "Осенний Алтай — невероятная красота. Делимся кадрами с поездки.", hasMedia: true, reactions: 1486, comments: 87),
        .init(id: 201, author: "Елена Соколова", initials: "ЕС", dateDescription: "сегодня в 10:12", content: "Наконец-то закончила новый проект!", hasMedia: false, reactions: 42, comments: 3)
    ]
}
