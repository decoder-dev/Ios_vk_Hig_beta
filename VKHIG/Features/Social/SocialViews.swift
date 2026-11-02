import SwiftUI

/// S15 — another user's profile.
struct UserProfileView: View {
    let userID: Int64
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        FixtureScreen(
            title: "Профиль",
            screenID: "S15",
            resourceID: userID,
            emptyTitle: "User not found",
            emptySymbol: "person.crop.circle",
            emptyDetails: "users.get when scoped.",
            loadValue: {
                CatalogFixtures.friends.first(where: { $0.id == userID })
                    ?? Friend(id: userID, displayName: "User \(userID)", initials: "U", isOnline: false, city: nil)
            }
        ) { friend in
            List {
                Section {
                    profileHeader(friend)
                }
                Section {
                    Label(friend.isOnline ? "В сети (fixture flag)" : "Не в сети", systemImage: "circle.fill")
                        .foregroundStyle(friend.isOnline ? .green : .secondary)
                    if let city = friend.city {
                        Label(city, systemImage: "mappin.and.ellipse")
                    }
                }
                Section("Действия") {
                    NavigationLink(value: AppRoute.conversation(userID)) { Label("Написать сообщение", systemImage:"bubble.left") }
                    Button("Добавить в друзья") { Task {
                        if env.isLiveVKSession { _ = await env.catalog.perform("friends.add", ["user_id":"\(userID)"]) }
                        else { env.catalog.notice = "Деморежим: заявка не отправлена." }
                    } }
                }
            }
        }
    }

    private func profileHeader(_ friend: Friend) -> some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [.blue.opacity(0.5), .teal.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 120)
            VKAvatar(initials: friend.initials, size: 72, tint: VKStyle.accent)
                .offset(y: -36)
                .padding(.bottom, -36)
            Text(friend.displayName).font(.title2.bold())
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
    }
}

/// S17 — edit profile (local form; save gated).
struct EditProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var isSaving = false
    @State private var name = "Preview User"
    @State private var status = ""
    @State private var city = "Москва"
    @State private var notice: String?

    var body: some View {
        Form {
            Section("S17") {
                TextField("Имя", text: $name)
                TextField("Статус", text: $status)
                LabeledContent("Город",value:city)
            }
            if let notice {
                Section { Text(notice).foregroundStyle(.secondary) }
            }
            Section {
                Text("account.saveProfileInfo (or equivalent) stays gated until verified.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Редактирование")
        .task {
            guard env.isLiveVKSession else { return }
            if let user: VKJSON = try? await env.catalog.request("users.get", ["fields":"status,city"]), let first = user.items.first {
                name = VKCatalogService.name(first); status = first["status"].string; city = first["city"]["title"].string
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        guard env.isLiveVKSession else { notice = "Деморежим: изменения не отправлены в VK."; return }
                        isSaving = true; defer { isSaving = false }
                        let parts = name.split(separator:" ", maxSplits:1).map(String.init)
                        if await env.catalog.perform("account.saveProfileInfo", ["first_name":parts.first ?? "", "last_name":parts.count > 1 ? parts[1] : "", "status":status]) { notice = "Профиль сохранён" }
                    }
                }
            }
        }
    }
}

/// S18 — friends list.
struct FriendsView: View {
    @State private var query = ""

    var body: some View {
        FixtureScreen(
            title: "Друзья",
            screenID: "S18",
            query:query,
            emptyTitle: "Нет друзей",
            emptySymbol: "person.2",
            emptyDetails: "friends.get when scoped.",
            isEmpty: { $0.isEmpty },
            loadValue: { CatalogFixtures.friends }
        ) { friends in
            let visible = query.isEmpty ? friends : friends.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
            List(visible) { friend in
                NavigationLink(value: AppRoute.userProfile(friend.id)) {
                    HStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            VKAvatar(initials: friend.initials, size: 44, tint: .indigo)
                            if friend.isOnline {
                                Circle().fill(.green).frame(width: 10, height: 10)
                            }
                        }
                        VStack(alignment: .leading) {
                            Text(friend.displayName)
                            if let city = friend.city {
                                Text(city).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Поиск друзей")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: AppRoute.friendRequests) {
                        Image(systemName: "person.badge.plus")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
            }
            .withAppRoutes()
        }
    }
}

/// S19 — friend requests.
struct FriendRequestsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var accepted: Set<Int64> = []
    var body: some View {
        FixtureScreen(
            title: "Заявки",
            screenID: "S19",
            emptyTitle: "Нет заявок",
            emptySymbol: "person.badge.plus",
            emptyDetails: "friends.getRequests when scoped.",
            isEmpty: { $0.isEmpty },
            loadValue: { CatalogFixtures.friendRequests }
        ) { requests in
            List {
                Section("Входящие") {
                    ForEach(requests.filter { $0.direction == .incoming }) { req in
                        requestRow(req)
                    }
                }
                Section("Исходящие") {
                    ForEach(requests.filter { $0.direction == .outgoing }) { req in
                        requestRow(req)
                    }
                }
            }
        }
    }

    private func requestRow(_ req: FriendRequest) -> some View {
        HStack {
            VKAvatar(initials: req.user.initials, size: 40, tint: .blue)
            VStack(alignment: .leading) {
                Text(req.user.displayName)
                Text(req.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if req.direction == .incoming {
                Button(accepted.contains(req.id) ? "Принято" : "Принять") { Task {
                    if env.isLiveVKSession {
                        if await env.catalog.perform("friends.add", ["user_id":"\(req.user.id)"]) { accepted.insert(req.id) }
                    } else { accepted.insert(req.id) }
                } }
                .disabled(accepted.contains(req.id))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }
}

/// S20 — community page.
struct CommunityView: View {
    let communityID: Int64
    @Environment(AppEnvironment.self) private var env
    @State private var wallPosts: [FeedPost] = []
    @State private var wallError: String?

    var body: some View {
        FixtureScreen(
            title: "Сообщество",
            screenID: "S20",
            resourceID: communityID,
            emptyTitle: "Not found",
            emptySymbol: "person.3",
            emptyDetails: "groups.getById when scoped.",
            loadValue: {
                CatalogFixtures.communities.first(where: { $0.id == communityID })
                    ?? CatalogFixtures.communities[0]
            }
        ) { community in
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(community.name).font(.title2.bold())
                        Text(community.description).foregroundStyle(.secondary)
                        Text("\(community.membersCount.formatted()) участников")
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    NavigationLink(value: AppRoute.communityMembers(community.id)) {
                        Label("Участники", systemImage: "person.2")
                    }
                    NavigationLink(value: AppRoute.photos) {
                        Label("Фото", systemImage: "photo")
                    }
                }
                Section("Записи") {
                    ForEach(wallPosts) { post in NavigationLink(value:AppRoute.postDetail(post.id)) { VStack(alignment:.leading) { Text(post.text).lineLimit(5); Text(post.dateLabel).font(.caption).foregroundStyle(.secondary) } } }
                    if let wallError { Text(wallError).font(.footnote).foregroundStyle(.red) }
                    if !env.isLiveVKSession { Text("Демонстрационная страница сообщества").font(.footnote) }
                }
            }
            .withAppRoutes()
            .task(id:communityID) {
                guard env.isLiveVKSession else { return }
                do {
                    let response = try await env.catalog.request("wall.get",["owner_id":"-\(communityID)","count":"30","extended":"1"])
                    wallPosts = env.catalog.mapPosts(response)
                } catch { wallError = error.localizedDescription }
            }
        }
    }
}

/// S21 — communities list.
struct CommunitiesListView: View {
    @State private var query = ""

    var body: some View {
        FixtureScreen(
            title: "Сообщества",
            screenID: "S21",
            emptyTitle: "Нет сообществ",
            emptySymbol: "person.3",
            emptyDetails: "groups.get when scoped.",
            isEmpty: { $0.isEmpty },
            loadValue: {
                CatalogFixtures.communities
            }
        ) { items in
            List(items.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { community in
                NavigationLink(value: AppRoute.community(community.id)) {
                    HStack(spacing: 12) {
                        VKAvatar(initials: community.initials, size: 44, tint: .mint)
                        VStack(alignment: .leading) {
                            Text(community.name)
                            Text("\(community.membersCount.formatted()) · \(community.isMember ? "Вы участник" : "Не подписаны")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $query)
            .withAppRoutes()
        }
    }
}

/// S22 — community members.
struct CommunityMembersView: View {
    let communityID: Int64
    @State private var query = ""

    var body: some View {
        FixtureScreen(
            title: "Участники",
            screenID: "S22",
            resourceID: communityID,
            emptyTitle: "Нет участников",
            emptySymbol: "person.2",
            emptyDetails: "groups.getMembers when scoped.",
            isEmpty: { $0.isEmpty },
            loadValue: {
                return CatalogFixtures.friends
            }
        ) { members in
            List(members.filter { query.isEmpty || $0.displayName.localizedCaseInsensitiveContains(query) }) { friend in
                NavigationLink(value: AppRoute.userProfile(friend.id)) {
                    Label(friend.displayName, systemImage: "person")
                }
            }
            .searchable(text: $query)
            .withAppRoutes()
        }
    }
}
