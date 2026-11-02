import SwiftUI

/// S23 — global search.
struct GlobalSearchView: View {
    @State private var query = ""
    @State private var scope = "Все"

    var body: some View {
        FixtureScreen(
            title: "Поиск",
            screenID: "S23",
            emptyTitle: "No results",
            emptySymbol: "magnifyingglass",
            emptyDetails: "users.search / groups.search when scoped.",
            isEmpty: { $0.isEmpty },
            loadValue: { CatalogFixtures.searchHits }
        ) { hits in
            let scoped: [SearchHit] = {
                switch scope {
                case "Люди": return hits.filter { $0.kind == .person }
                case "Сообщества": return hits.filter { $0.kind == .community }
                case "Записи": return hits.filter { $0.kind == .post }
                default: return hits
                }
            }()
            let visible = query.isEmpty ? scoped : scoped.filter { $0.title.localizedCaseInsensitiveContains(query) }
            List {
                Picker("Scope", selection: $scope) {
                    ForEach(["Все", "Люди", "Сообщества", "Записи"], id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                ForEach(visible) { hit in
                    row(for: hit)
                }
            }
            .searchable(text: $query, prompt: "Люди, сообщества, записи")
            .withAppRoutes()
        }
    }

    @ViewBuilder
    private func row(for hit: SearchHit) -> some View {
        switch hit.kind {
        case .person:
            let id = Int64(String(hit.id.dropFirst())) ?? 201
            NavigationLink(value: AppRoute.userProfile(id)) {
                Label(hit.title, systemImage: "person")
            }
        case .community:
            let id = Int64(String(hit.id.dropFirst())) ?? 501
            NavigationLink(value: AppRoute.community(id)) {
                Label(hit.title, systemImage: "person.3")
            }
        case .post:
            NavigationLink(value: AppRoute.postDetail(700)) {
                Label(hit.title, systemImage: "doc.text")
            }
        }
    }
}

/// S24 — notifications inbox.
struct NotificationsView: View {
    var body: some View {
        FixtureScreen(
            title: "Уведомления",
            screenID: "S24",
            emptyTitle: "No notifications",
            emptySymbol: "bell",
            emptyDetails: "notifications.get when scoped.",
            isEmpty: { $0.isEmpty },
            loadValue: { CatalogFixtures.notifications }
        ) { items in
            List(items) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.symbol)
                        .frame(width: 28)
                        .foregroundStyle(VKStyle.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.headline)
                        Text(item.body).font(.subheadline).foregroundStyle(.secondary)
                        Text(item.dateLabel).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if item.isUnread {
                        Circle().fill(VKStyle.accent).frame(width: 8, height: 8)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

/// S25 — services catalog hub (replaces placeholder).
struct ServicesHubView: View {
    var body: some View {
        List {
            Section("S25 · Сервисы") {
                NavigationLink(value: AppRoute.videoList) {
                    Label("Видео", systemImage: "play.rectangle")
                }
                NavigationLink(value: AppRoute.communities) {
                    Label("Сообщества", systemImage: "person.3")
                }
                NavigationLink(value: AppRoute.friends) {
                    Label("Друзья", systemImage: "person.2")
                }
                NavigationLink(value: AppRoute.photos) {
                    Label("Фотографии", systemImage: "photo.on.rectangle.angled")
                }
                NavigationLink(value: AppRoute.photoAlbums) {
                    Label("Альбомы", systemImage: "rectangle.stack")
                }
            }
            Section("Дополнительно") {
                NavigationLink(value: AppRoute.bookmarks) {
                    Label("Сохранённое", systemImage: "bookmark")
                }
                NavigationLink(value: AppRoute.notifications) {
                    Label("Уведомления", systemImage: "bell")
                }
                NavigationLink(value: AppRoute.globalSearch) {
                    Label("Поиск", systemImage: "magnifyingglass")
                }
                NavigationLink(value: AppRoute.musicLibrary) {
                    Label("Музыка", systemImage: "music.note")
                }
            }
            Section("Диагностика UI") {
                NavigationLink(value: AppRoute.errorDemo) {
                    Label("Состояния ошибок", systemImage: "exclamationmark.triangle")
                }
                NavigationLink(value: AppRoute.actionsDemo) {
                    Label("Шторка действий", systemImage: "ellipsis.circle")
                }
                NavigationLink(value: AppRoute.incomingCall) {
                    Label("Входящий звонок (stub)", systemImage: "phone")
                }
                NavigationLink(value: AppRoute.onboarding) {
                    Label("Онбординг", systemImage: "sparkles")
                }
            }
            Section {
                Text("Routes open fixture-backed screens. Live VK calls stay capability-gated.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Сервисы")
        .withAppRoutes()
    }
}
