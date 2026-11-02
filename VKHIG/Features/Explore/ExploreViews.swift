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
        async let users=result("users.search",["q":text,"count":"30","offset":"\(userOffset)"],enabled:usersMore)
        async let groups=result("groups.search",["q":text,"count":"30","offset":"\(groupOffset)"],enabled:groupsMore)
        async let posts=result("newsfeed.search",postParameters,enabled:postsMore)
        let responses=await (users,groups,posts)
        guard ticket==generation,!Task.isCancelled else {return}
        var page:[SearchHit]=[],warnings:[String]=[]
        switch responses.0 {
        case .success(let response):
            let items=response.list
            page+=items.map {j in let name=VKCatalogService.name(j);return SearchHit(id:"u\(j["id"].int)",kind:.person,title:name,subtitle:"",initials:VKCatalogService.initials(name))}
            userOffset+=items.count;usersMore=items.count==30
        case .failure(let error):warnings.append("Люди: "+error.localizedDescription);usersMore=false
        }
        switch responses.1 {
        case .success(let response):
            let items=response.list
            page+=items.map {SearchHit(id:"g\($0["id"].int)",kind:.community,title:$0["name"].string,subtitle:"",initials:VKCatalogService.initials($0["name"].string))}
            groupOffset+=items.count;groupsMore=items.count==30
        case .failure(let error):warnings.append("Сообщества: "+error.localizedDescription);groupsMore=false
        }
        switch responses.2 {
        case .success(let response):
            let posts=environment.catalog.mapPosts(response)
            page+=posts.map {SearchHit(id:"p\($0.id)",kind:.post,title:$0.text,subtitle:$0.authorName,initials:$0.authorInitials)}
            let next=response["next_from"].string;postsMore = !next.isEmpty && next != postCursor;postCursor=next.isEmpty ? nil : next
        case .failure(let error):warnings.append("Записи: "+error.localizedDescription);postsMore=false
        }
        var seen=Set(hits.map(\.id));hits+=page.filter {seen.insert($0.id).inserted};errors=Array(Set(errors+warnings)).sorted();loading=false
    }
}

struct GlobalSearchView:View {
    @Environment(AppEnvironment.self) private var env
    @State private var query=""
    @State private var scope="Все"
    @State private var model:GlobalSearchModel?
    var body:some View {
        List {
            Picker("Раздел",selection:$scope) {ForEach(["Все","Люди","Сообщества","Записи"],id:\.self) {Text($0).tag($0)}}.pickerStyle(.segmented)
            if let model {
                if !env.isLiveVKSession {FixtureBanner()}
                ForEach(model.errors,id:\.self) {Text($0).font(.footnote).foregroundStyle(.secondary)}
                ForEach(model.hits.filter {scope=="Все" || (scope=="Люди" && $0.kind == .person) || (scope=="Сообщества" && $0.kind == .community) || (scope=="Записи" && $0.kind == .post)}) {hit in row(hit)}
                if model.loading {ProgressView().frame(maxWidth:.infinity)}
                if model.searched,!model.loading,model.hits.isEmpty {ContentUnavailableView.search(text:query)}
                if !model.loading,model.searched,model.hasMore {Button("Загрузить ещё") {Task {await model.search(query,reset:false)}}.frame(minHeight:44)}
                if !model.searched {Text("Найдите людей, сообщества и записи.").foregroundStyle(.secondary)}
            }
        }.navigationTitle("Поиск").searchable(text:$query,prompt:"Люди, сообщества, записи").withAppRoutes()
        .task(id:query) {let vm:GlobalSearchModel;if let model {vm=model} else {vm=GlobalSearchModel(environment:env);model=vm};await vm.search(query)}
    }
    @ViewBuilder private func row(_ hit:SearchHit) -> some View {
        if let id=Int64(hit.id.dropFirst()) {
            let route:AppRoute = hit.kind == .person ? .userProfile(id) : hit.kind == .community ? .community(id) : .postDetail(id)
            NavigationLink(value:route) {VStack(alignment:.leading,spacing:5) {Text(hit.title).lineLimit(4);if !hit.subtitle.isEmpty {Text(hit.subtitle).font(.caption).foregroundStyle(.secondary)}}}
        } else {Text(hit.title)}
    }
}

/// S24 — notifications inbox.
struct NotificationsView: View {
    @Environment(AppEnvironment.self) private var env
    var body: some View {
        FixtureScreen(
            title: "Уведомления",
            screenID: "S24",
            emptyTitle: "Нет уведомлений",
            emptySymbol: "bell",
            emptyDetails: "notifications.get when scoped.",
            isEmpty: { $0.isEmpty },
            loadValue: { CatalogFixtures.notifications }
        ) { items in
            List(items) { item in
                Link(destination:item.targetURL ?? URL(string:"https://vk.com/feed?section=notifications")!) {
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
                }.foregroundStyle(.primary)
            }.task {if env.isLiveVKSession {_ = try? await env.catalog.request("notifications.markAsViewed")}}
        }
    }
}

/// S25 — services catalog hub (replaces placeholder).
struct ServicesHubView: View {
    var body: some View {
        List {
            Section("S25 · Сервисы") {
                NavigationLink(value:AppRoute.incomingCall) {Label("Звонки VK",systemImage:"phone")}
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
                NavigationLink(value: AppRoute.onboarding) {
                    Label("Онбординг", systemImage: "sparkles")
                }
            }
            Section {
                Text("Доступность разделов зависит от разрешений VK.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Сервисы")
        .withAppRoutes()
    }
}
