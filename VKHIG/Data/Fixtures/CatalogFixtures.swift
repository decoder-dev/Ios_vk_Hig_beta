import Foundation

enum CatalogFixtures {
    static let friends: [Friend] = [
        .init(id: 201, displayName: "Анастасия Смирнова", initials: "АС", isOnline: true, city: "Москва", lastSeen: "Онлайн"),
        .init(id: 202, displayName: "Дмитрий Орлов", initials: "ДО", isOnline: false, city: "Казань", lastSeen: "Был в сети 15 минут назад"),
        .init(id: 203, displayName: "Мария Волкова", initials: "МВ", isOnline: true, city: "Санкт-Петербург", lastSeen: "Онлайн"),
        .init(id: 204, displayName: "Илья Назаров", initials: "ИН", isOnline: false, city: "Мурманск", lastSeen: "Был в сети 27 минут назад"),
        .init(id: 205, displayName: "Елена Соколова", initials: "ЕС", isOnline: false, city: "Москва", lastSeen: "Была в сети сегодня в 07:29"),
        .init(id: 206, displayName: "Сергей Беляев", initials: "СБ", isOnline: false, city: nil, lastSeen: "Был в сети вчера в 23:41")
    ]

    static let friendRequests: [FriendRequest] = [
        .init(id: 1, user: friends[0], direction: .incoming, subtitle: "Общие друзья: 3"),
        .init(id: 2, user: friends[1], direction: .outgoing, subtitle: "Заявка отправлена")
    ]

    static let communities: [Community] = [
        .init(id: 501, name: "Путешествия по России", initials: "ПР", membersCount: 211_842,
              description: "Маршруты, фото и советы для поездок по стране.", isMember: true,
              activity: "Туризм · Путешествия · Природа", isVerified: true),
        .init(id: 502, name: "SwiftUI HIG", initials: "SH", membersCount: 8_420,
              description: "Обсуждение нативных паттернов.", isMember: false, activity: "Программирование"),
        .init(id: 503, name: "Фотография", initials: "ФО", membersCount: 56_001,
              description: "Галереи и критика.", isMember: true, activity: "Фотография"),
        .init(id: 504, name: "Горы и походы", initials: "ГП", membersCount: 486_120,
              description: "Походы, снаряжение и маршруты.", isMember: false, activity: "Активный отдых", isVerified: true)
    ]

    static let comments: [CommentItem] = [
        .init(id: 1, postID: 700, author: "Елена", initials: "ЕЛ", text: "Красивые кадры!", dateLabel: "1ч", replyToID: nil),
        .init(id: 2, postID: 700, author: "Иван", initials: "ИВ", text: "Был там осенью — согласен.", dateLabel: "45м", replyToID: 1),
        .init(id: 3, postID: 701, author: "Ольга", initials: "ОЛ", text: "Поздравляю с проектом!", dateLabel: "20м", replyToID: nil)
    ]

    static let notifications: [NotificationItem] = [
        .init(id: 1, title: "Дмитрий Орлов оценил вашу запись", body: "Осенний Алтай", dateLabel: "3 мин назад", symbol: "heart.fill", isUnread: true, category: .reactions),
        .init(id: 2, title: "Мария Волкова прокомментировала фотографию", body: "«Невероятно! 🔥»", dateLabel: "12 мин назад", symbol: "bubble.left.fill", isUnread: true, category: .comments),
        .init(id: 3, title: "Илья Назаров подписался на вас", body: "", dateLabel: "24 мин назад", symbol: "person.fill", isUnread: false),
        .init(id: 4, title: "Сообщество «Горы и походы» опубликовало новую запись", body: "", dateLabel: "Вчера в 21:37", symbol: "bell.fill", isUnread: false),
        .init(id: 5, title: "У вас 2 новые заявки в друзья", body: "", dateLabel: "Вчера в 17:22", symbol: "person.2.fill", isUnread: false)
    ]

    static let searchHits: [SearchHit] = [
        .init(id: "u201", kind: .person, title: "Анастасия Смирнова", subtitle: "Москва", initials: "АС"),
        .init(id: "u204", kind: .person, title: "Илья Назаров", subtitle: "Мурманск", initials: "ИН"),
        .init(id: "g501", kind: .community, title: "Путешествия по России", subtitle: "Сообщество · 211 тыс. участников", initials: "ПР"),
        .init(id: "g504", kind: .community, title: "Горы и походы", subtitle: "Сообщество · 486 тыс. участников", initials: "ГП"),
        .init(id: "p700", kind: .post, title: "Осенние пейзажи Алтая", subtitle: "Путешествия по России", initials: "ПР")
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
        .init(id: 1, title: "Мурманск. Край северного ветра", durationLabel: "14:27", author: "Путешествия по России", views: 327_000, dateLabel: "2 дня назад"),
        .init(id: 2, title: "Поход в Хибины | Зимний маршрут", durationLabel: "7:18", author: "Горы и походы", views: 89_000, dateLabel: "5 дней назад"),
        .init(id: 3, title: "Прогулка по городу", durationLabel: "4:55", author: "Фотография", views: 12_400, dateLabel: "неделю назад")
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
