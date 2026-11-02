import Foundation

enum CatalogFixtures {
    static let friends: [Friend] = [
        .init(id: 201, displayName: "Анастасия Смирнова", initials: "АС", isOnline: true, city: "Москва"),
        .init(id: 202, displayName: "Дмитрий Орлов", initials: "ДО", isOnline: false, city: "Казань"),
        .init(id: 203, displayName: "Мария Волкова", initials: "МВ", isOnline: true, city: "СПб"),
        .init(id: 204, displayName: "Игорь Петров", initials: "ИП", isOnline: false, city: nil)
    ]

    static let friendRequests: [FriendRequest] = [
        .init(id: 1, user: friends[0], direction: .incoming, subtitle: "Общие друзья: 3"),
        .init(id: 2, user: friends[1], direction: .outgoing, subtitle: "Заявка отправлена")
    ]

    static let communities: [Community] = [
        .init(id: 501, name: "Путешествия по России", initials: "ПР", membersCount: 124_000,
              description: "Маршруты, фото и советы.", isMember: true),
        .init(id: 502, name: "SwiftUI HIG", initials: "SH", membersCount: 8_420,
              description: "Обсуждение нативных паттернов.", isMember: false),
        .init(id: 503, name: "Фотография", initials: "ФО", membersCount: 56_001,
              description: "Галереи и критика.", isMember: true)
    ]

    static let comments: [CommentItem] = [
        .init(id: 1, postID: 700, author: "Елена", initials: "ЕЛ", text: "Красивые кадры!", dateLabel: "1ч", replyToID: nil),
        .init(id: 2, postID: 700, author: "Иван", initials: "ИВ", text: "Был там осенью — согласен.", dateLabel: "45м", replyToID: 1),
        .init(id: 3, postID: 701, author: "Ольга", initials: "ОЛ", text: "Поздравляю с проектом!", dateLabel: "20м", replyToID: nil)
    ]

    static let notifications: [NotificationItem] = [
        .init(id: 1, title: "Новый комментарий", body: "Елена ответила к записи", dateLabel: "5 мин", symbol: "bubble.left", isUnread: true),
        .init(id: 2, title: "Заявка в друзья", body: "Анастасия хочет добавить вас", dateLabel: "1 ч", symbol: "person.badge.plus", isUnread: true),
        .init(id: 3, title: "Сообщество", body: "Новый пост в «Путешествия по России»", dateLabel: "Вчера", symbol: "person.3", isUnread: false)
    ]

    static let searchHits: [SearchHit] = [
        .init(id: "u201", kind: .person, title: "Анастасия Смирнова", subtitle: "Москва", initials: "АС"),
        .init(id: "g501", kind: .community, title: "Путешествия по России", subtitle: "124K участников", initials: "ПР"),
        .init(id: "p700", kind: .post, title: "Осенние пейзажи Алтая", subtitle: "Запись", initials: "ЗА")
    ]

    static let albums: [PhotoAlbum] = [
        .init(id: 1, title: "Профиль", count: 24),
        .init(id: 2, title: "Путешествия", count: 86),
        .init(id: 3, title: "Семья", count: 41)
    ]

    static let photos: [PhotoItem] = (1...18).map {
        PhotoItem(id: Int64($0), albumID: $0 < 8 ? 1 : 2, caption: "Photo \($0)")
    }

    static let videos: [VideoItem] = [
        .init(id: 1, title: "Горный трейл", durationLabel: "12:04", author: "Путешествия"),
        .init(id: 2, title: "WWDC notes", durationLabel: "08:19", author: "SwiftUI HIG"),
        .init(id: 3, title: "City walk", durationLabel: "04:55", author: "Фотография")
    ]

    static let tracks: [TrackItem] = [
        .init(id: 1, title: "Demo Track A", artist: "Fixture Artist", durationLabel: "3:21"),
        .init(id: 2, title: "Demo Track B", artist: "Fixture Artist", durationLabel: "2:58"),
        .init(id: 3, title: "Demo Track C", artist: "Library Demo", durationLabel: "4:02")
    ]

    static let playlists: [PlaylistItem] = [
        .init(id: 1, title: "Focus", trackCount: 12),
        .init(id: 2, title: "Evening", trackCount: 8)
    ]

    static let bookmarks: [BookmarkItem] = [
        .init(id: 1, title: "Осенний Алтай", subtitle: "Сохранённая запись", symbol: "bookmark.fill"),
        .init(id: 2, title: "SwiftUI tips", subtitle: "Ссылка", symbol: "link")
    ]

    static let stories: [StoryItem] = [
        .init(id: 1, author: "Вы", initials: "ВЫ"),
        .init(id: 2, author: "Анастасия", initials: "АС"),
        .init(id: 3, author: "Дмитрий", initials: "ДО")
    ]
}
