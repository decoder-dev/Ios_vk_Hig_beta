import SwiftUI

/// S15 — another user's profile.
struct UserProfileView: View {
    let userID: Int64

    var body: some View {
        FixtureScreen(
            title: "Профиль",
            screenID: "S15",
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
                    Button("Написать сообщение") {}
                    Button("Добавить в друзья") {}
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
    @State private var name = "Preview User"
    @State private var status = ""
    @State private var city = "Москва"
    @State private var notice: String?

    var body: some View {
        Form {
            Section("S17") {
                TextField("Имя", text: $name)
                TextField("Статус", text: $status)
                TextField("Город", text: $city)
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
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    notice = "Not saved to VK — local draft only."
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
            emptyTitle: "No friends",
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
    var body: some View {
        FixtureScreen(
            title: "Заявки",
            screenID: "S19",
            emptyTitle: "No requests",
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
                Button("Accept") {}
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }
}

/// S20 — community page.
struct CommunityView: View {
    let communityID: Int64

    var body: some View {
        FixtureScreen(
            title: "Сообщество",
            screenID: "S20",
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
                    Text("Community wall posts appear here with fixtures/API.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .withAppRoutes()
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
            emptyTitle: "No communities",
            emptySymbol: "person.3",
            emptyDetails: "groups.get when scoped.",
            isEmpty: { $0.isEmpty },
            loadValue: {
                let all = CatalogFixtures.communities
                if query.isEmpty { return all }
                return all.filter { $0.name.localizedCaseInsensitiveContains(query) }
            }
        ) { items in
            List(items) { community in
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
            emptyTitle: "No members",
            emptySymbol: "person.2",
            emptyDetails: "groups.getMembers when scoped.",
            isEmpty: { $0.isEmpty },
            loadValue: {
                _ = communityID
                let all = CatalogFixtures.friends
                if query.isEmpty { return all }
                return all.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
            }
        ) { members in
            List(members) { friend in
                NavigationLink(value: AppRoute.userProfile(friend.id)) {
                    Label(friend.displayName, systemImage: "person")
                }
            }
            .searchable(text: $query)
            .withAppRoutes()
        }
    }
}
