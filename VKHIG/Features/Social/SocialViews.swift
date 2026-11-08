import SwiftUI
import Observation

/// S15 — another user's profile.
struct UserProfileView: View {
    let userID: Int64
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        FixtureScreen(
            title: "Профиль",
            screenID: "S15",
            resourceID: userID,
            emptyTitle: "Пользователь не найден",
            emptySymbol: "person.crop.circle",
            emptyDetails: "Данные появятся, когда VK выдаст приложению доступ.",
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
                    Label(friend.lastSeen ?? (friend.isOnline ? "Онлайн" : "Не в сети"), systemImage: "circle.fill")
                        .foregroundStyle(friend.isOnline ? .green : .secondary)
                    if let city = friend.city {
                        Label(city, systemImage: "mappin.and.ellipse")
                    }
                }
                Section("Действия") {
                    NavigationLink(value: AppRoute.conversation(userID)) { Label("Написать сообщение", systemImage:"bubble.left") }
                    Button("Сохранить профиль") {Task {if env.isLiveVKSession {_ = await env.catalog.perform("fave.addPage",["user_id":String(userID)])}}}.disabled(!env.isLiveVKSession)
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
            VKCoverBackground(seed: friend.displayName)
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: VKStyle.Radius.card, style: .continuous))
            VKAvatar(initials: friend.initials, url: friend.avatarURL, size: 88, isOnline: friend.isOnline)
                .padding(4)
                .background(VKStyle.groupedCanvas, in: Circle())
                .offset(y: -48)
                .padding(.bottom, -48)
            Text(friend.displayName).font(.title2.bold())
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
    }
}

struct VKLocationChoice:Identifiable,Equatable {
    let id:Int64
    let title:String
}
@MainActor
@Observable
final class ProfileEditorModel {
    var firstName=""
    var lastName=""
    var maidenName=""
    var screenName=""
    var status=""
    var birthday=""
    var birthdayVisibility=0
    var sex=0
    var relation=0
    var homeTown=""
    var country:VKLocationChoice?
    var city:VKLocationChoice?
    var partner:Friend?
    var loading=false
    var saving=false
    var loaded=false
    var error:String?
    var notice:String?
    private let request:(String,[String:String]) async throws -> VKJSON
    init(request:((String,[String:String]) async throws -> VKJSON)?=nil) {
        self.request=request ?? {try await VKCatalogService.shared.request($0,$1)}
    }
    static func validBirthday(_ text:String) -> Bool {
        if text.isEmpty {return true}
        let parts=text.split(separator:".",omittingEmptySubsequences:false)
        let values=parts.compactMap {Int($0)}
        guard values.count==parts.count,(values.count==2 || values.count==3) else {return false}
        let year=values.count==3 ? values[2] : 2000
        guard year>=1900,year<=Calendar.current.component(.year,from:Date()) else {return false}
        let calendar=Calendar(identifier:.gregorian)
        guard let date=calendar.date(from:DateComponents(year:year,month:values[1],day:values[0])) else {return false}
        if values.count==3 && date>Date() {return false}
        let result=calendar.dateComponents([.year,.month,.day],from:date)
        return result.year==year && result.month==values[1] && result.day==values[0]
    }
    func load() async {
        loading=true;error=nil;defer {loading=false}
        do {
            let profile=try await request("account.getProfileInfo",[:])
            if case .null=profile["first_name"] {throw AppError.decoding}
            firstName=profile["first_name"].string;lastName=profile["last_name"].string;maidenName=profile["maiden_name"].string
            screenName=profile["screen_name"].string;status=profile["status"].string;birthday=profile["bdate"].string
            birthdayVisibility=Int(profile["bdate_visibility"].int);sex=Int(profile["sex"].int);relation=Int(profile["relation"].int);homeTown=profile["home_town"].string
            country=profile["country"]["id"].int>0 ? VKLocationChoice(id:profile["country"]["id"].int,title:profile["country"]["title"].string) : nil
            city=profile["city"]["id"].int>0 ? VKLocationChoice(id:profile["city"]["id"].int,title:profile["city"]["title"].string) : nil
            if profile["relation_partner"]["id"].int>0 {partner=VKCatalogService.friend(profile["relation_partner"])}
            loaded=true
        } catch {self.error=error.localizedDescription}
    }
    func save() async {
        guard loaded,!saving else {return}
        guard !firstName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,!lastName.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else {error="Укажите имя и фамилию.";return}
        guard Self.validBirthday(birthday) else {error="Укажите существующую дату: ДД.ММ или ДД.ММ.ГГГГ.";return}
        saving=true;error=nil;defer {saving=false}
        var params=["first_name":firstName,"last_name":lastName,"maiden_name":maidenName,"screen_name":screenName,"status":status,"bdate":birthday,"bdate_visibility":String(birthdayVisibility),"sex":String(sex),"relation":String(relation),"home_town":homeTown]
        params["country_id"]=String(country?.id ?? 0);params["city_id"]=String(city?.id ?? 0)
        params["relation_partner_id"]=String(partner?.id ?? 0)
        do {
            let response=try await request("account.saveProfileInfo",params)
            let pending=response["name_request"]["status"].string
            notice=pending.isEmpty ? (response["changed"].flag ? "Профиль сохранён в VK" : "Изменений нет") : "Изменение имени: \(pending)"
            await load()
        } catch {self.error=error.localizedDescription}
    }
}
struct EditProfileView:View {
    @Environment(AppEnvironment.self) private var env
    @State private var model=ProfileEditorModel()
    @State private var location:String?
    @State private var partnerPicker=false
    var body:some View {
        Form {
            if !env.isLiveVKSession {FixtureBanner();Text("Для изменения профиля войдите в VK ID.")}
            if model.loading {ProgressView()}
            if let error=model.error {Text(error).foregroundStyle(.red);Button("Повторить") {Task {await model.load()}}}
            if let notice=model.notice {Text(notice).font(.footnote)}
            if model.loaded {fields}
        }.navigationTitle("Редактирование профиля")
        .task {if env.isLiveVKSession {await model.load()}}
        .toolbar {ToolbarItem(placement:.confirmationAction) {Button("Сохранить") {Task {await model.save()}}.disabled(!model.loaded || model.loading || model.saving)}}
        .sheet(isPresented:Binding(get:{location != nil},set:{if !$0 {location=nil}})) {
            LocationPickerView(countryID:location=="city" ? model.country?.id : nil) {choice in
                if location=="city" {model.city=choice} else {if model.country?.id != choice.id {model.city=nil};model.country=choice}
            }
        }
        .sheet(isPresented:$partnerPicker) {VKUserPicker {person in model.partner=person;return true}}
    }
    private var fields:some View {
        @Bindable var model=model
        return Group {
            Section("Имя и адрес страницы") {
                TextField("Имя",text:$model.firstName);TextField("Фамилия",text:$model.lastName);TextField("Девичья фамилия",text:$model.maidenName)
                TextField("Адрес страницы vk.com/…",text:$model.screenName).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Статус",text:$model.status,axis:.vertical).lineLimit(1...4)
            }
            Section("Основная информация") {
                Picker("Пол",selection:$model.sex) {Text("Не указан").tag(0);Text("Женский").tag(1);Text("Мужской").tag(2)}
                TextField("День рождения: ДД.ММ.ГГГГ",text:$model.birthday).keyboardType(.numbersAndPunctuation)
                Picker("Показывать дату рождения",selection:$model.birthdayVisibility) {Text("Не показывать").tag(0);Text("Полностью").tag(1);Text("Без года").tag(2)}
                Picker("Семейное положение",selection:$model.relation) {ForEach(0..<9) {value in Text(["Не указано","Не в браке","Есть партнёр","Помолвлены","В браке","Всё сложно","В активном поиске","Влюблены","Гражданский брак"][value]).tag(value)}}
                Button(model.partner?.displayName ?? "Выбрать партнёра") {partnerPicker=true}
                if model.partner != nil {Button("Убрать партнёра",role:.destructive) {model.partner=nil}}
            }
            Section("География") {
                TextField("Родной город",text:$model.homeTown)
                Button("Страна: "+(model.country?.title ?? "Не указана")) {location="country"}
                Button("Город: "+(model.city?.title ?? "Не указан")) {location="city"}.disabled(model.country==nil)
                Button("Убрать место проживания",role:.destructive) {model.country=nil;model.city=nil}
            }
        }.disabled(model.saving)
    }
}
struct LocationPickerView:View {
    let countryID:Int64?
    let select:(VKLocationChoice)->Void
    @Environment(\.dismiss) private var dismiss
    @State private var query=""
    @State private var items:[VKLocationChoice]=[]
    @State private var loading=false
    @State private var error:String?
    @State private var offset=0
    @State private var hasMore=false
    @State private var requestID=UUID()
    private var visible:[VKLocationChoice] {countryID != nil || query.isEmpty ? items : items.filter {$0.title.localizedCaseInsensitiveContains(query)}}
    var body:some View {
        NavigationStack {
            List {
                ForEach(visible) {item in Button(item.title) {select(item);dismiss()}}
                if loading {ProgressView()}
                if let error {Text(error).foregroundStyle(.red);Button("Повторить") {Task {await load(reset:true)}}}
                if hasMore {Button("Загрузить ещё") {Task {await load(reset:false)}}.disabled(loading)}
            }.navigationTitle(countryID==nil ? "Страна" : "Город").searchable(text:$query)
            .toolbar {ToolbarItem(placement:.cancellationAction) {Button("Отмена") {dismiss()}}}
            .task(id:countryID == nil ? "countries" : query) {await load(reset:true)}
        }
    }
    private func load(reset:Bool) async {
        if !reset && loading {return}
        if reset {requestID=UUID();offset=0;items=[]}
        let ticket=requestID
        loading=true;error=nil;defer {if ticket==requestID {loading=false}}
        do {
            if countryID != nil {try await Task.sleep(for:.milliseconds(300))}
            var params=["count":"1000","offset":String(offset),"need_all":"1"]
            if let countryID {params=["country_id":String(countryID),"q":query,"count":"100","offset":String(offset),"need_all":"1"]}
            let response=try await VKCatalogService.shared.request(countryID==nil ? "database.getCountries" : "database.getCities",params)
            try Task.checkCancellation();guard ticket==requestID else {return}
            let page=response.list.map {VKLocationChoice(id:$0["id"].int,title:$0["title"].string)}
            var ids=Set(items.map(\.id));items+=page.filter {ids.insert($0.id).inserted};offset+=page.count;hasMore=page.count==(countryID==nil ? 1000 : 100)
        } catch is CancellationError {} catch {if ticket==requestID {self.error=error.localizedDescription}}
    }
}

/// S18 — friends list, board 03: Все/Онлайн pills, rows with presence and a message shortcut.
struct FriendsView: View {
    @State private var query = ""
    @State private var onlineOnly = false

    var body: some View {
        FixtureScreen(
            title: "Друзья",
            screenID: "S18",
            query:query,
            emptyTitle: "Нет друзей",
            emptySymbol: "person.2",
            emptyDetails: "Данные появятся, когда VK выдаст приложению доступ.",
            isEmpty: { $0.isEmpty },
            loadValue: { CatalogFixtures.friends }
        ) { friends in
            let matching = query.isEmpty ? friends : friends.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
            let visible = onlineOnly ? matching.filter(\.isOnline) : matching
            ScrollView {
                LazyVStack(spacing: 0) {
                    VKPillPicker(chips: [VKChip(value: false, title: "Все"), VKChip(value: true, title: "Онлайн")], selection: $onlineOnly)
                        .padding(.horizontal, VKStyle.Size.contentMargin)
                        .padding(.vertical, VKStyle.Spacing.xs)
                    if visible.isEmpty {
                        Text(onlineOnly ? "Среди загруженных друзей никого нет в сети." : "Никого не найдено.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .padding(VKStyle.Spacing.xl)
                    }
                    ForEach(visible) { friend in
                        FriendRow(friend: friend)
                    }
                }
            }
            .background(VKStyle.canvas)
            .searchable(text: $query, prompt: "Поиск среди друзей")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: AppRoute.friendRequests) {
                        Image(systemName: "person.badge.plus")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Заявки в друзья")
                }
            }
            .withAppRoutes()
        }
    }
}

/// Person row shared by friends, members and search.
struct FriendRow: View {
    let friend: Friend
    var showsMessage = true

    var body: some View {
        HStack(spacing: VKStyle.Spacing.sm) {
            NavigationLink(value: AppRoute.userProfile(friend.id)) {
                HStack(spacing: VKStyle.Spacing.sm) {
                    VKAvatar(initials: friend.initials, url: friend.avatarURL, size: VKStyle.Size.avatarRow, isOnline: friend.isOnline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(friend.displayName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let subtitle = friend.lastSeen ?? (friend.isOnline ? "Онлайн" : friend.city) {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if showsMessage {
                NavigationLink(value: AppRoute.conversation(friend.id)) {
                    Image(systemName: "bubble.left")
                        .font(.title3)
                        .foregroundStyle(VKStyle.accent)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Написать \(friend.displayName)")
            }
        }
        .padding(.horizontal, VKStyle.Size.contentMargin)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(VKStyle.separator).frame(height: 0.5)
                .padding(.leading, VKStyle.Size.contentMargin + VKStyle.Size.avatarRow + VKStyle.Spacing.sm)
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
            emptyDetails: "Данные появятся, когда VK выдаст приложению доступ.",
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
            VKAvatar(initials: req.user.initials, url: req.user.avatarURL, size: 44)
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

/// S20 — community page, board 02: cover, identity card, subscribe, action tiles, wall.
struct CommunityView: View {
    let communityID: Int64
    @Environment(AppEnvironment.self) private var env
    @State private var wallPosts: [FeedPost] = []
    @State private var wallError: String?
    @State private var memberOverride: Bool?
    @State private var joining = false

    var body: some View {
        FixtureScreen(
            title: "Сообщество",
            screenID: "S20",
            resourceID: communityID,
            emptyTitle: "Сообщество не найдено",
            emptySymbol: "person.3",
            emptyDetails: "Данные появятся, когда VK выдаст приложению доступ.",
            loadValue: {
                CatalogFixtures.communities.first(where: { $0.id == communityID })
                    ?? CatalogFixtures.communities[0]
            }
        ) { community in
            ScrollView {
                VStack(spacing: VKStyle.Spacing.sm) {
                    header(community)
                    actions(community)
                        .padding(.horizontal, VKStyle.Size.contentMargin)

                    VStack(alignment: .leading, spacing: VKStyle.Spacing.xs) {
                        VKSectionHeader(title: "Записи")
                            .padding(.top, VKStyle.Spacing.xs)
                        if let wallError {
                            Text(wallError).font(.footnote).foregroundStyle(.red)
                                .padding(.horizontal, VKStyle.Size.contentMargin)
                        }
                        if !env.isLiveVKSession {
                            Text("Демонстрационная страница сообщества")
                                .font(.footnote).foregroundStyle(.secondary)
                                .padding(.horizontal, VKStyle.Size.contentMargin)
                        }
                        LazyVStack(spacing: VKStyle.Spacing.xs) {
                            ForEach(wallPosts) { post in
                                NavigationLink(value: AppRoute.postDetail(post.id)) { PostCard(post: post) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.bottom, VKStyle.Spacing.xl)
            }
            .background(VKStyle.groupedCanvas)
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

    private func header(_ community: Community) -> some View {
        let isMember = memberOverride ?? community.isMember
        return VStack(spacing: 0) {
            VKCoverBackground(url: community.coverURL, seed: community.name)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: VKStyle.Radius.card, style: .continuous))
                .padding(.horizontal, VKStyle.Spacing.xs)

            VStack(alignment: .leading, spacing: VKStyle.Spacing.sm) {
                HStack(alignment: .center, spacing: VKStyle.Spacing.sm) {
                    VKAvatar(initials: community.initials, url: community.avatarURL, size: 72)
                        .padding(3)
                        .background(VKStyle.cell, in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text(community.name)
                                .font(.title3.weight(.bold))
                                .lineLimit(2)
                            if community.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(VKStyle.accent)
                                    .accessibilityLabel("Подтверждённое сообщество")
                            }
                        }
                        if let activity = community.activity {
                            Text(activity).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Text(VKFormat.plural(community.membersCount, "участник", "участника", "участников"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if !community.description.isEmpty {
                    Text(community.description)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(4)
                }
                HStack(spacing: VKStyle.Spacing.xs) {
                    if isMember {
                        NavigationLink {
                            CommunityManagementView(communityID: communityID)
                        } label: {
                            Label("Вы подписаны", systemImage: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(VKStyle.accent)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(VKStyle.accentWash, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            Task { await join() }
                        } label: {
                            Text(joining ? "Подписка…" : "Подписаться")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(VKStyle.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(joining)
                    }
                    if env.isLiveVKSession, let url = URL(string: "https://vk.com/club\(communityID)") {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(VKStyle.accent)
                                .frame(width: 44, height: 44)
                                .background(VKStyle.accentWash, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .accessibilityLabel("Поделиться сообществом")
                    }
                }
            }
            .padding(VKStyle.Size.contentMargin)
            .frame(maxWidth: .infinity, alignment: .leading)
            .vkCard(radius: VKStyle.Radius.card)
            .padding(.horizontal, VKStyle.Spacing.xs)
            .padding(.top, -VKStyle.Spacing.xl)
        }
        .padding(.top, VKStyle.Spacing.xs)
    }

    private func actions(_ community: Community) -> some View {
        HStack(spacing: VKStyle.Spacing.xs) {
            NavigationLink(value: AppRoute.communityMembers(community.id)) {
                VKActionTile(symbol: "person.2", title: "Участники")
            }
            NavigationLink(value: AppRoute.photos) {
                VKActionTile(symbol: "photo", title: "Фото")
            }
            NavigationLink {
                CommunityManagementView(communityID: communityID)
            } label: {
                VKActionTile(symbol: "slider.horizontal.3", title: "Управление")
            }
            Button {
                Task { if env.isLiveVKSession { _ = await env.catalog.perform("fave.addPage",["group_id":String(communityID)]) } }
            } label: {
                VKActionTile(symbol: "bookmark", title: "Сохранить")
            }
            .disabled(!env.isLiveVKSession)
        }
        .buttonStyle(.plain)
    }

    private func join() async {
        guard !joining else { return }
        guard env.isLiveVKSession else { env.catalog.notice = "Деморежим: подписка не отправлена в VK."; return }
        joining = true
        defer { joining = false }
        if await env.catalog.perform("groups.join", ["group_id": String(communityID)]) { memberOverride = true }
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
            emptyDetails: "Данные появятся, когда VK выдаст приложению доступ.",
            isEmpty: { $0.isEmpty },
            loadValue: {
                CatalogFixtures.communities
            }
        ) { items in
            List(items.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { community in
                NavigationLink(value: AppRoute.community(community.id)) {
                    HStack(spacing: VKStyle.Spacing.sm) {
                        VKAvatar(initials: community.initials, url: community.avatarURL, size: VKStyle.Size.avatarRow)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(community.name).font(.body.weight(.semibold)).lineLimit(1)
                                if community.isVerified {
                                    Image(systemName: "checkmark.seal.fill").font(.caption).foregroundStyle(VKStyle.accent)
                                }
                            }
                            Text("\(community.activity ?? "Сообщество") · \(VKFormat.compact(community.membersCount))")
                                .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .padding(.vertical, 2)
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
            emptyDetails: "Данные появятся, когда VK выдаст приложению доступ.",
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

@MainActor
@Observable
final class CommunityAdministrationModel {
    let groupID:Int64
    var title=""
    var about=""
    var website=""
    var access=0
    var groupType=""
    var joined=false
    var adminLevel=0
    var members:[Friend]=[]
    var loading=false
    var busy=false
    var hasMore=true
    var error:String?
    var notice:String?
    private var offset=0
    private let request:(String,[String:String]) async throws -> VKJSON
    init(groupID:Int64,request:((String,[String:String]) async throws -> VKJSON)?=nil) {
        self.groupID=groupID;self.request=request ?? {try await VKCatalogService.shared.request($0,$1)}
    }
    func load() async {
        loading=true;error=nil;adminLevel=0;defer {loading=false}
        do {
            guard groupID>0 else {throw AppError.decoding}
            let response=try await request("groups.getById",["group_ids":String(groupID),"fields":"description,members_count,is_member,site"])
            let items=response["groups"].items.isEmpty ? response.list : response["groups"].items
            guard let group=items.first else {throw AppError.decoding}
            groupType=group["type"].string
            title=group["name"].string;about=group["description"].string;website=group["site"].string
            joined=group["is_member"].flag
            adminLevel=group["is_admin"].flag ? Int(group["admin_level"].int) : 0
            if adminLevel>=3 {
                let settings=try await request("groups.getSettings",["group_id":String(groupID)])
                title=settings["title"].string.isEmpty ? title : settings["title"].string
                about=settings["description"].string;website=settings["website"].string;access=Int(settings["access"].int)
            }
        } catch {self.error=error.localizedDescription}
    }
    func loadMembers(reset:Bool=false) async {
        guard !loading else {return};loading=true;defer {loading=false}
        if reset {offset=0;members=[];hasMore=true}
        do {
            let response=try await request("groups.getMembers",["group_id":String(groupID),"fields":"city,online","count":"100","offset":String(offset)])
            let page=response.list.map(VKCatalogService.friend)
            var ids=Set(members.map(\.id));members+=page.filter {ids.insert($0.id).inserted};offset+=page.count;hasMore=page.count==100
        } catch {self.error=error.localizedDescription}
    }
    func membership() async {
        let method=joined ? "groups.leave" : "groups.join"
        if await execute(method,["group_id":String(groupID)]) {await load();notice=joined ? "Вы участник сообщества" : method=="groups.join" ? "Заявка отправлена в VK" : "Вы вышли из сообщества"}
    }
    func save() async {
        guard adminLevel>=3 else {error="Нет прав администратора сообщества.";return}
        guard !title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else {error="Введите название.";return}
        if !website.isEmpty {
            guard let url=URL(string:website),url.scheme=="https",url.host != nil,url.user==nil,url.password==nil else {error="Укажите полную HTTPS-ссылку на сайт.";return}
        }
        var parameters=["group_id":String(groupID),"title":title,"description":about,"website":website]
        if groupType=="group" {parameters["access"]=String(access)}
        if await execute("groups.edit",parameters) {await load()}
    }
    func role(_ role:String,user:Friend) async -> Bool {
        guard adminLevel>=3,["moderator","editor","administrator","advertiser",""].contains(role) else {error="Нет прав на изменение руководителей.";return false}
        var params=["group_id":String(groupID),"user_id":String(user.id)]
        if !role.isEmpty {params["role"]=role}
        return await execute("groups.editManager",params)
    }
    func remove(_ user:Friend) async {
        guard adminLevel>=1,user.id != VKSession.currentUserID else {error="Недостаточно прав.";return}
        if await execute("groups.removeUser",["group_id":String(groupID),"user_id":String(user.id)]) {members.removeAll {$0.id==user.id}}
    }
    private func execute(_ method:String,_ params:[String:String]) async -> Bool {
        guard !busy else {return false};busy=true;error=nil;defer {busy=false}
        do {
            let result=try await request(method,params)
            guard result.int==1 else {throw AppError.decoding}
            notice="Изменения подтверждены VK";return true
        } catch {self.error=error.localizedDescription;return false}
    }
}
struct CommunityManagementView:View {
    let communityID:Int64
    @Environment(AppEnvironment.self) private var env
    @State private var model:CommunityAdministrationModel?
    @State private var leaving=false
    @State private var removing:Friend?
    @State private var manager:Friend?
    @State private var picking=false
    @State private var pendingManager:Friend?
    @State private var role="moderator"
    var body:some View {
        Group {if let model {form(model)} else {ProgressView()}}
            .navigationTitle("Сообщество")
            .task {if model==nil {let vm=CommunityAdministrationModel(groupID:communityID);model=vm;if env.isLiveVKSession {await vm.load()} else {vm.title="Демонстрационное сообщество"}}}
            .sheet(isPresented:$picking,onDismiss:{manager=pendingManager;pendingManager=nil}) {VKUserPicker {user in pendingManager=user;return true}}
            .sheet(item:$manager) {user in roleEditor(user)}
            .confirmationDialog("Выйти из сообщества?",isPresented:$leaving) {Button("Выйти",role:.destructive) {Task {await model?.membership()}}}
            .confirmationDialog("Удалить участника из сообщества?",isPresented:Binding(get:{removing != nil},set:{if !$0 {removing=nil}})) {Button("Удалить",role:.destructive) {if let user=removing {Task {await model?.remove(user)}};removing=nil}}
    }
    private func form(_ model:CommunityAdministrationModel) -> some View {
        @Bindable var model=model
        return Form {
            if !env.isLiveVKSession {FixtureBanner()}
            Section {
                Text(model.title).font(.headline)
                Button(model.joined ? "Выйти из сообщества" : "Вступить в сообщество") {if model.joined {leaving=true} else {Task {await model.membership()}}}.disabled(model.busy || !env.isLiveVKSession)
                if model.loading || model.busy {ProgressView()}
                if let error=model.error {Text(error).foregroundStyle(.red);Button("Повторить загрузку") {Task {await model.load()}}}
                if let notice=model.notice {Text(notice).font(.footnote)}
            }
            if model.adminLevel>=3 {
                Section("Настройки сообщества") {
                    TextField("Название",text:$model.title)
                    TextField("Описание",text:$model.about,axis:.vertical).lineLimit(3...8)
                    TextField("Сайт https://…",text:$model.website).textInputAutocapitalization(.never).keyboardType(.URL)
                    if model.groupType=="group" {Picker("Доступ",selection:$model.access) {Text("Открытое").tag(0);Text("Закрытое").tag(1);Text("Частное").tag(2)}}
                    Button("Сохранить изменения") {Task {await model.save()}}.disabled(model.busy)
                    Button("Назначить руководителя") {picking=true}.disabled(model.busy)
                }
            }
            if model.adminLevel>=1 {
                Section("Участники") {
                    if model.members.isEmpty {Button("Загрузить участников") {Task {await model.loadMembers(reset:true)}}.disabled(model.loading)}
                    ForEach(model.members) {user in
                        Text(user.displayName).contextMenu {
                            if model.adminLevel>=3 {Button("Изменить полномочия") {manager=user}}
                            Button("Удалить участника",role:.destructive) {removing=user}
                        }
                    }
                    if !model.members.isEmpty && model.hasMore {Button("Загрузить ещё") {Task {await model.loadMembers()}}.disabled(model.loading)}
                }
            }
        }
    }
    private func roleEditor(_ user:Friend) -> some View {
        NavigationStack {
            Form {
                Text(user.displayName)
                Picker("Полномочия",selection:$role) {Text("Модератор").tag("moderator");Text("Редактор").tag("editor");Text("Администратор").tag("administrator");Text("Рекламодатель").tag("advertiser");Text("Без полномочий").tag("")}
                if let error=model?.error {Text(error).foregroundStyle(.red)}
                Button("Применить") {Task {if await model?.role(role,user:user) == true {manager=nil}}}.disabled(model?.busy == true)
            }.navigationTitle("Руководитель")
            .toolbar {ToolbarItem(placement:.cancellationAction) {Button("Отмена") {manager=nil}}}
        }
    }
}
