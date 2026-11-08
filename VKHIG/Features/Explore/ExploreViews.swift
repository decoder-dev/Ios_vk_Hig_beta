import SwiftUI
import Observation

@MainActor
@Observable
final class GlobalSearchModel {
    let environment:AppEnvironment
    var hits:[SearchHit]=[]
    var errors:[String]=[]
    var loading=false
    var searched=false
    private var generation=UUID()
    private var userOffset=0
    private var groupOffset=0
    private var postCursor:String?
    private var usersMore=true
    private var groupsMore=true
    private var postsMore=true
    var hasMore:Bool {usersMore || groupsMore || postsMore}
    init(environment:AppEnvironment) {self.environment=environment}
    private func result(_ method:String,_ parameters:[String:String],enabled:Bool) async -> Result<VKJSON,AppError> {
        guard enabled else {return .success(.object(["items":.array([])]))}
        do {return .success(try await environment.catalog.request(method,parameters))}
        catch {return .failure(error as? AppError ?? .network(error.localizedDescription))}
    }
    func search(_ query:String,reset:Bool = true) async {
        if reset {generation=UUID();userOffset=0;groupOffset=0;postCursor=nil;usersMore=true;groupsMore=true;postsMore=true;hits=[];errors=[]}
        let ticket=generation,text=query.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty else {searched=false;loading=false;return}
        guard reset || !loading else {return}
        loading=true;searched=true
        if reset {do {try await Task.sleep(for:.milliseconds(300))} catch {if ticket==generation {loading=false};return}}
        guard !Task.isCancelled,ticket==generation else {return}
        if !environment.isLiveVKSession {
            hits=CatalogFixtures.searchHits.filter {$0.title.localizedCaseInsensitiveContains(text)}
            usersMore=false;groupsMore=false;postsMore=false;loading=false;return
        }
        var postParameters=["q":text,"count":"30","extended":"1"]
        if let postCursor {postParameters["start_from"]=postCursor}
        async let users=result("users.search",["q":text,"count":"30","offset":"\(userOffset)","fields":"photo_100,city"],enabled:usersMore)
        async let groups=result("groups.search",["q":text,"count":"30","offset":"\(groupOffset)"],enabled:groupsMore)
        async let posts=result("newsfeed.search",postParameters,enabled:postsMore)
        let responses=await (users,groups,posts)
        guard ticket==generation,!Task.isCancelled else {return}
        var page:[SearchHit]=[],warnings:[String]=[]
        switch responses.0 {
        case .success(let response):
            let items=response.list
            page+=items.map {j in let name=VKCatalogService.name(j);return SearchHit(id:"u\(j["id"].int)",kind:.person,title:name,subtitle:j["city"]["title"].string,initials:VKCatalogService.initials(name),avatarURL:VKCatalogService.avatarURL(j))}
            userOffset+=items.count;usersMore=items.count==30
        case .failure(let error):warnings.append("Люди: "+error.localizedDescription);usersMore=false
        }
        switch responses.1 {
        case .success(let response):
            let items=response.list
            page+=items.map {SearchHit(id:"g\($0["id"].int)",kind:.community,title:$0["name"].string,subtitle:"Сообщество",initials:VKCatalogService.initials($0["name"].string),avatarURL:VKCatalogService.avatarURL($0))}
            groupOffset+=items.count;groupsMore=items.count==30
        case .failure(let error):warnings.append("Сообщества: "+error.localizedDescription);groupsMore=false
        }
        switch responses.2 {
        case .success(let response):
            let posts=environment.catalog.mapPosts(response)
            page+=posts.map {SearchHit(id:"p\($0.id)",kind:.post,title:$0.text,subtitle:$0.authorName,initials:$0.authorInitials,avatarURL:$0.avatarURL)}
            let next=response["next_from"].string;postsMore = !next.isEmpty && next != postCursor;postCursor=next.isEmpty ? nil : next
        case .failure(let error):warnings.append("Записи: "+error.localizedDescription);postsMore=false
        }
        var seen=Set(hits.map(\.id));hits+=page.filter {seen.insert($0.id).inserted};errors=Array(Set(errors+warnings)).sorted();loading=false
    }
}

/// S23 — global search, board 03: chips, grouped "Люди / Сообщества / Записи" with "Все ›".
struct GlobalSearchView:View {
    @Environment(AppEnvironment.self) private var env
    @State private var query=""
    @State private var scope: SearchHit.Kind? = nil
    @State private var model:GlobalSearchModel?
    private let scopes: [VKChip<SearchHit.Kind?>] = [
        VKChip(value:nil,title:"Все"),
        VKChip(value:.person,title:"Люди"),
        VKChip(value:.community,title:"Сообщества"),
        VKChip(value:.post,title:"Записи")
    ]
    private static let titles:[SearchHit.Kind:String]=[.person:"Люди",.community:"Сообщества",.post:"Записи"]
    var body:some View {
        ScrollView {
            LazyVStack(alignment:.leading,spacing:0) {
                VKChipBar(chips:scopes,selection:$scope).padding(.vertical,VKStyle.Spacing.xxs)
                if let model {
                    if !env.isLiveVKSession {FixtureBanner().padding(.horizontal,VKStyle.Size.contentMargin).padding(.vertical,6)}
                    ForEach(model.errors,id:\.self) {Text($0).font(.footnote).foregroundStyle(.secondary).padding(.horizontal,VKStyle.Size.contentMargin)}
                    if let scope {
                        ForEach(model.hits.filter {$0.kind == scope}) {hit in row(hit)}
                    } else {
                        ForEach([SearchHit.Kind.person,.community,.post],id:\.self) {kind in
                            let hits=model.hits.filter {$0.kind == kind}
                            if !hits.isEmpty {
                                VKSectionHeader(title:Self.titles[kind] ?? "",actionTitle:hits.count>3 ? "Все" : nil,action:{scope=kind})
                                    .padding(.top,VKStyle.Spacing.sm)
                                ForEach(hits.prefix(3)) {hit in row(hit)}
                            }
                        }
                    }
                    if model.loading {ProgressView().frame(maxWidth:.infinity).padding()}
                    if model.searched,!model.loading,model.hits.isEmpty {ContentUnavailableView.search(text:query).padding(.top,VKStyle.Spacing.xl)}
                    if !model.loading,model.searched,model.hasMore {Button("Загрузить ещё") {Task {await model.search(query,reset:false)}}.frame(maxWidth:.infinity,minHeight:44)}
                    if !model.searched {
                        ContentUnavailableView("Поиск по ВКонтакте",systemImage:"magnifyingglass",description:Text("Найдите людей, сообщества и записи."))
                            .padding(.top,VKStyle.Spacing.xxl)
                    }
                }
            }
            .padding(.bottom,VKStyle.Spacing.lg)
        }
        .background(VKStyle.canvas)
        .navigationTitle("Поиск").searchable(text:$query,prompt:"Поиск по ВКонтакте").withAppRoutes()
        .task(id:query) {let vm:GlobalSearchModel;if let model {vm=model} else {vm=GlobalSearchModel(environment:env);model=vm};await vm.search(query)}
    }
    @ViewBuilder private func row(_ hit:SearchHit) -> some View {
        if let id=Int64(hit.id.dropFirst()) {
            let route:AppRoute = hit.kind == .person ? .userProfile(id) : hit.kind == .community ? .community(id) : .postDetail(id)
            NavigationLink(value:route) {
                HStack(spacing:VKStyle.Spacing.sm) {
                    VKAvatar(initials:hit.initials,url:hit.avatarURL,size:hit.kind == .post ? 40 : VKStyle.Size.avatarRow)
                    VStack(alignment:.leading,spacing:2) {
                        Text(hit.title).font(hit.kind == .post ? Font.subheadline : Font.body.weight(.semibold)).foregroundStyle(.primary).lineLimit(hit.kind == .post ? 3 : 1)
                        if !hit.subtitle.isEmpty {Text(hit.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)}
                    }
                    Spacer(minLength:0)
                }
                .padding(.horizontal,VKStyle.Size.contentMargin)
                .padding(.vertical,6)
            }.buttonStyle(VKRowButtonStyle())
        } else {Text(hit.title).padding(.horizontal,VKStyle.Size.contentMargin)}
    }
}

/// S24 — notifications, board 03: category chips, avatar-style glyph with a coloured badge.
struct NotificationsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var category: NotificationItem.Category? = nil
    private let categories: [VKChip<NotificationItem.Category?>] = [
        VKChip(value: nil, title: "Все"),
        VKChip(value: .reactions, title: "Реакции"),
        VKChip(value: .comments, title: "Комментарии"),
        VKChip(value: .other, title: "Другое")
    ]
    var body: some View {
        FixtureScreen(
            title: "Уведомления",
            screenID: "S24",
            emptyTitle: "Нет уведомлений",
            emptySymbol: "bell",
            emptyDetails: "Данные появятся, когда VK выдаст приложению доступ.",
            isEmpty: { $0.isEmpty },
            loadValue: { CatalogFixtures.notifications }
        ) { items in
            let visible = items.filter { category == nil || $0.category == category }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    VKChipBar(chips: categories, selection: $category)
                        .padding(.vertical, VKStyle.Spacing.xxs)
                    if visible.isEmpty {
                        Text("В этой категории пока пусто.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .padding(VKStyle.Spacing.xl)
                    }
                    ForEach(visible) { item in
                        Link(destination: item.targetURL ?? URL(string: "https://vk.com/feed?section=notifications")!) {
                            NotificationRow(item: item)
                        }
                        .buttonStyle(VKRowButtonStyle())
                    }
                }
            }
            .background(VKStyle.canvas)
            .task { if env.isLiveVKSession { _ = try? await env.catalog.request("notifications.markAsViewed") } }
        }
    }
}

private struct NotificationRow: View {
    let item: NotificationItem

    private var badgeColor: Color {
        switch item.category {
        case .reactions: return .red
        case .comments: return VKStyle.accent
        case .other: return .green
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: VKStyle.Spacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(badgeColor.opacity(0.14))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: item.symbol)
                            .font(.title3)
                            .foregroundStyle(badgeColor)
                    }
                if item.isUnread {
                    Circle()
                        .fill(VKStyle.accent)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(VKStyle.canvas, lineWidth: 2))
                        .accessibilityLabel("Новое")
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(item.isUnread ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                if !item.body.isEmpty {
                    Text(item.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(item.dateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, VKStyle.Size.contentMargin)
        .padding(.vertical, VKStyle.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

/// S25 — services hub: tile grid of VK sections.
struct ServicesHubView: View {
    private struct Tile: Identifiable {
        let title: String
        let symbol: String
        let tint: Color
        let route: AppRoute?
        var id: String { title }
    }
    private let columns = [GridItem(.flexible(), spacing: VKStyle.Spacing.sm), GridItem(.flexible(), spacing: VKStyle.Spacing.sm), GridItem(.flexible(), spacing: VKStyle.Spacing.sm)]
    private let tiles: [Tile] = [
        Tile(title: "Друзья", symbol: "person.2.fill", tint: .blue, route: .friends),
        Tile(title: "Сообщества", symbol: "person.3.fill", tint: .indigo, route: .communities),
        Tile(title: "Фотографии", symbol: "photo.on.rectangle.angled", tint: .orange, route: .photos),
        Tile(title: "Видео", symbol: "play.rectangle.fill", tint: .red, route: .videoList),
        Tile(title: "Музыка", symbol: "music.note", tint: .pink, route: .musicLibrary),
        Tile(title: "Звонки VK", symbol: "phone.fill", tint: .green, route: .incomingCall),
        Tile(title: "Сохранённое", symbol: "bookmark.fill", tint: .teal, route: .bookmarks),
        Tile(title: "Уведомления", symbol: "bell.fill", tint: .purple, route: .notifications),
        Tile(title: "Поиск", symbol: "magnifyingglass", tint: .gray, route: .globalSearch)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VKStyle.Spacing.md) {
                LazyVGrid(columns: columns, spacing: VKStyle.Spacing.sm) {
                    NavigationLink { StoriesListView() } label: { tileLabel("Истории VK", "circle.dashed", .cyan) }
                        .accessibilityLabel("Истории VK")
                    ForEach(tiles) { tile in
                        if let route = tile.route {
                            NavigationLink(value: route) { tileLabel(tile.title, tile.symbol, tile.tint) }
                                .accessibilityLabel(tile.title)
                        }
                    }
                }
                .buttonStyle(.plain)

                #if DEBUG
                VStack(spacing: 0) {
                    NavigationLink(value: AppRoute.photoAlbums) { debugRow("Альбомы", "rectangle.stack") }
                    NavigationLink(value: AppRoute.errorDemo) { debugRow("Состояния ошибок", "exclamationmark.triangle") }
                    NavigationLink(value: AppRoute.actionsDemo) { debugRow("Шторка действий", "ellipsis.circle") }
                    NavigationLink(value: AppRoute.onboarding) { debugRow("Онбординг", "sparkles") }
                }
                .buttonStyle(VKRowButtonStyle())
                .vkCard()
                .clipShape(RoundedRectangle(cornerRadius: VKStyle.Radius.card, style: .continuous))
                #endif

                Text("Доступность разделов зависит от разрешений VK.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(VKStyle.Size.contentMargin)
        }
        .background(VKStyle.groupedCanvas)
        .navigationTitle("Сервисы")
        .withAppRoutes()
    }

    private func tileLabel(_ title: String, _ symbol: String, _ tint: Color) -> some View {
        VStack(spacing: VKStyle.Spacing.xs) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .vkCard(radius: VKStyle.Radius.tile)
        .contentShape(RoundedRectangle(cornerRadius: VKStyle.Radius.tile, style: .continuous))
    }

    private func debugRow(_ title: String, _ symbol: String) -> some View {
        HStack {
            VKIconRow(title: title, symbol: symbol)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, VKStyle.Size.contentMargin)
    }
}
