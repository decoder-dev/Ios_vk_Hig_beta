import SwiftUI
import AVKit
import Observation

@MainActor
@Observable
final class BookmarksModel {
    var items:[BookmarkItem]=[]
    var loading=false
    var busy=false
    var more=true
    var error:String?
    private var offset=0
    private let request:(String,[String:String]) async throws -> VKJSON
    init(request:((String,[String:String]) async throws -> VKJSON)?=nil) {self.request=request ?? {try await VKCatalogService.shared.request($0,$1)}}
    func load(reset:Bool=true) async {
        guard !loading else {return};loading=true;error=nil;defer {loading=false}
        let start=reset ? 0 : offset
        do {
            let response=try await request("fave.get",["count":"100","offset":String(start)])
            let page=VKCatalogService.mapBookmarks(response)
            var next=reset ? [] : items
            var ids=Set(next.map(\.id));next+=page.filter {ids.insert($0.id).inserted}
            items=next;offset=start+response.list.count;more=response.list.count==100
        } catch {self.error=error.localizedDescription}
    }
    func add(_ input:String) async -> Bool {
        guard !busy else {return false};busy=true;error=nil;defer {busy=false}
        do {
            let action=try VKAction.bookmarkAddition(input)
            let result=try await request(action.method,action.parameters)
            guard result.int==1 else {throw AppError.decoding}
            await load();return true
        } catch {self.error=error.localizedDescription;return false}
    }
    func remove(_ item:BookmarkItem) async {
        guard !busy else {return};busy=true;error=nil;defer {busy=false}
        do {
            let action=try VKAction.bookmarkRemoval(item)
            let result=try await request(action.method,action.parameters)
            guard result.int==1 else {throw AppError.decoding}
            items.removeAll {$0.id==item.id};await load()
        } catch {self.error=error.localizedDescription}
    }
}
extension VKCatalogService {
    static func mapBookmarks(_ response:VKJSON) -> [BookmarkItem] {
        response.list.map {item in
            let type=item["type"].string,value=item[item["type"].string]
            var owner=value["owner_id"].int
            if type=="page" {owner=item["user"]["id"].int != 0 ? item["user"]["id"].int : -item["group"]["id"].int}
            let id=value["id"].int
            let linkID=item["link"]["id"].string
            var url=value["url"].url ?? value["view_url"].url ?? item["link"]["url"].url
            if url==nil,owner != 0,owner != Int64.min {
                let prefix:[String:String]=["post":"wall","video":"video","clip":"clip"]
                if type=="product",id>0 {url=URL(string:"https://vk.com/market\(owner)?w=product\(owner)_\(id)")}
                else if type=="page" {url=URL(string:"https://vk.com/\(owner>0 ? "id" : "club")\(abs(owner))")}
                else if let prefix=prefix[type],id>0 {url=URL(string:"https://vk.com/\(prefix)\(owner)_\(id)")}
            }
            let title=value["title"].string.isEmpty ? (value["text"].string.isEmpty ? "Сохранённое VK" : String(value["text"].string.prefix(120))) : value["title"].string
            let key="\(type):\(owner):\(id):\(linkID):\(url?.absoluteString ?? "")"
            return BookmarkItem(id:BookmarkItem.stableID(key),title:title,subtitle:type,symbol:"bookmark",targetURL:url,kind:type,ownerID:owner,itemID:id,linkID:linkID)
        }
    }
}
struct BookmarksView:View {
    @Environment(AppEnvironment.self) private var env
    @State private var model=BookmarksModel()
    @State private var adding=false
    @State private var input=""
    @State private var deleting:BookmarkItem?
    var body:some View {
        List {
            if !env.isLiveVKSession {FixtureBanner();ForEach(CatalogFixtures.bookmarks) {Text($0.title)}}
            ForEach(model.items) {item in
                HStack {
                    if let url=item.targetURL {Link(destination:url) {Label(item.title,systemImage:item.symbol)}} else {Text(item.title)}
                    Spacer()
                    if (try? VKAction.bookmarkRemoval(item)) != nil {Button("Удалить",role:.destructive) {deleting=item}.disabled(model.busy)}
                }
            }
            if model.loading {ProgressView()}
            if let error=model.error {Text(error).foregroundStyle(.red);Button("Повторить") {Task {await model.load()}}}
            if env.isLiveVKSession && model.items.isEmpty && !model.loading && model.error==nil {Text("Сохранённых материалов нет")}
            if !model.items.isEmpty && model.more {Button("Загрузить ещё") {Task {await model.load(reset:false)}}.disabled(model.loading || model.busy)}
        }.navigationTitle("Сохранённое")
        .toolbar {ToolbarItem(placement:.topBarTrailing) {Button("Добавить",systemImage:"plus") {adding=true}.disabled(!env.isLiveVKSession || model.busy)}}
        .task {if env.isLiveVKSession {await model.load()}}
        .refreshable {if env.isLiveVKSession {await model.load()}}
        .confirmationDialog("Удалить из сохранённого?",isPresented:Binding(get:{deleting != nil},set:{if !$0 {deleting=nil}})) {Button("Удалить",role:.destructive) {if let item=deleting {Task {await model.remove(item)}};deleting=nil}}
        .sheet(isPresented:$adding) {
            NavigationStack {
                Form {
                    TextField("Ссылка https://…",text:$input).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    if let error=model.error {Text(error).foregroundStyle(.red)}
                    Button("Сохранить ссылку") {Task {if await model.add(input) {input="";adding=false}}}.disabled(model.busy || input.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                }.navigationTitle("В сохранённое")
                .toolbar {ToolbarItem(placement:.cancellationAction) {Button("Отмена") {adding=false}}}
            }
        }
    }
}

struct VKStory:Identifiable,Equatable {
    let id:Int64
    let ownerID:Int64
    let nativeID:Int64
    let author:String
    let photoURL:URL?
    let videoURL:URL?
    let link:URL?
    let expiresAt:Date?
    var authorAvatar:URL? = nil
    var url:URL {URL(string:"https://vk.com/story\(ownerID)_\(nativeID)")!}
    var available:Bool {expiresAt.map {$0>Date()} ?? true}
}
extension VKCatalogService {
    func fetchStories() async throws -> [VKStory] {
        let response=try await request("stories.get",["extended":"1","fields":"photo_100"])
        let mapped=Self.mapStories(response)
        for story in mapped {stories[story.id]=story}
        return mapped
    }
    static func mapStories(_ response:VKJSON) -> [VKStory] {
        var authors=Dictionary(response["profiles"].items.map {($0["id"].int,Self.name($0))},uniquingKeysWith:{a,_ in a})
        for group in response["groups"].items {authors[-group["id"].int]=group["name"].string}
        var avatars:[Int64:URL]=[:]
        for p in response["profiles"].items {if let url=Self.avatarURL(p) {avatars[p["id"].int]=url}}
        for g in response["groups"].items {if let url=Self.avatarURL(g) {avatars[-g["id"].int]=url}}
        func flatten(_ items:[VKJSON],depth:Int) -> [VKJSON] {
            guard depth<8 else {return []}
            return items.flatMap {item -> [VKJSON] in
                if !item["stories"].items.isEmpty {return item["stories"].items}
                if !item["grouped"].items.isEmpty {return flatten(item["grouped"].items,depth:depth+1)}
                return item["id"].int != 0 && item["owner_id"].int != 0 ? [item] : []
            }
        }
        var ids:Set<Int64>=[]
        return flatten(response.list,depth:0).compactMap {j in
            guard !j["is_deleted"].flag,!j["is_expired"].flag else {return nil}
            if case .null=j["can_see"] {} else if !j["can_see"].flag {return nil}
            let nativeID=j["id"].int,owner=j["owner_id"].int
            let product=owner.multipliedReportingOverflow(by:1_000_000_000)
            guard !product.overflow else {return nil}
            let encoded=product.partialValue.addingReportingOverflow(nativeID)
            guard !encoded.overflow,ids.insert(encoded.partialValue).inserted else {return nil}
            let expiration=j["expires_at"].int>0 ? Date(timeIntervalSince1970:Double(j["expires_at"].int)) : nil
            if let expiration,expiration<=Date() {return nil}
            let video=j["video"]["files"]
            return VKStory(id:encoded.partialValue,ownerID:owner,nativeID:nativeID,author:authors[owner] ?? "VK",photoURL:Self.mediaPhotoURL(j["photo"]),videoURL:video["hls"].url ?? video["mp4_720"].url ?? video["mp4_480"].url,link:j["link"]["url"].url,expiresAt:expiration,authorAvatar:avatars[owner])
        }
    }
    func story(_ id:Int64) async throws -> VKStory {
        guard let cached=stories[id] else {throw AppError.network("История не найдена. Обновите список историй.")}
        let response=try await request("stories.getById",["stories":"\(cached.ownerID)_\(cached.nativeID)","extended":"1"])
        guard let story=Self.mapStories(response).first else {throw AppError.network("История удалена, скрыта или истекла.")}
        stories[id]=story;return story
    }
}
@MainActor
@Observable
final class StoriesModel {
    var items:[VKStory]=[]
    var loading=false
    var error:String?
    func load() async {
        guard !loading else {return};loading=true;error=nil;defer {loading=false}
        do {items=try await VKCatalogService.shared.fetchStories()} catch {self.error=error.localizedDescription}
    }
}
struct StoriesListView:View {
    @Environment(AppEnvironment.self) private var env
    @State private var model=StoriesModel()
    var body:some View {
        List {
            if !env.isLiveVKSession {FixtureBanner();Text("Войдите в VK ID для просмотра историй.")}
            ForEach(model.items) {story in NavigationLink(value:AppRoute.story(story.id)) {Label(story.author,systemImage:"person.crop.circle")}}
            if model.loading {ProgressView()}
            if let error=model.error {Text(error).foregroundStyle(.red);Button("Повторить") {Task {await model.load()}}}
            if !model.loading && model.error==nil && model.items.isEmpty && env.isLiveVKSession {Text("Доступных историй нет")}
        }.navigationTitle("Истории").withAppRoutes()
        .task {if env.isLiveVKSession {await model.load()}}
        .refreshable {if env.isLiveVKSession {await model.load()}}
    }
}
struct LiveStoriesStrip:View {
    @State private var model=StoriesModel()
    var body:some View {
        VStack(alignment:.leading) {
            ScrollView(.horizontal,showsIndicators:false) {
                HStack(spacing:VKStyle.Spacing.sm) {
                    ForEach(model.items) {story in
                        NavigationLink(value:AppRoute.story(story.id)) {
                            VKStoryBubble(title:story.author,initials:VKCatalogService.initials(story.author),url:story.authorAvatar)
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal,VKStyle.Size.contentMargin)
            }
            if let error=model.error {Text(error).font(.caption).foregroundStyle(.secondary);Button("Повторить истории") {Task {await model.load()}}}
        }.task {await model.load()}
    }
}
struct StoryViewerView:View {
    let storyID:Int64
    @Environment(AppEnvironment.self) private var env
    @State private var story:VKStory?
    @State private var error:String?
    @State private var loading=false
    @State private var player:AVPlayer?
    @State private var now=Date()
    var body:some View {
        VStack {
            if loading {ProgressView()}
            if let story,story.expiresAt.map({$0>now}) ?? true {
                Text(story.author).font(.headline)
                if let video=story.videoURL {
                    VideoPlayer(player:player).task(id:video) {player=AVPlayer(url:video);player?.play()}.onDisappear {player?.pause()}
                } else if let photo=story.photoURL {AsyncImage(url:photo) {image in image.resizable().scaledToFit()} placeholder:{ProgressView()}}
                else {Link("Открыть историю в VK",destination:story.url)}
                HStack {ShareLink(item:story.url);if let link=story.link {Link("Открыть ссылку",destination:link)}}
            } else if !loading {ContentUnavailableView("История недоступна",systemImage:"clock.badge.exclamationmark",description:Text(error ?? "Срок истории истёк."));Button("Повторить") {Task {await load()}}}
        }.padding().navigationTitle("История").navigationBarTitleDisplayMode(.inline)
        .task {await load()}
        .task {
            while !Task.isCancelled {do {try await Task.sleep(for:.seconds(1))} catch {return};now=Date();if let story, !story.available {player?.pause()}}
        }
    }
    private func load() async {
        guard env.isLiveVKSession else {error="Просмотр историй требует входа в VK ID.";return}
        loading=true;error=nil;defer {loading=false}
        do {story=try await env.catalog.story(storyID)} catch {self.error=error.localizedDescription}
    }
}

struct IncomingCallView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openURL) private var openURL
    @State private var link=""
    @State private var callID:String?
    @State private var busy=false
    @State private var error:String?
    @State private var confirmFinish=false
    private var joinURL:URL? {
        guard let url=URL(string:link.trimmingCharacters(in:.whitespacesAndNewlines)),url.scheme=="https",let host=url.host?.lowercased(),["vk.com","vk.ru","vk.me","calls.vk.com"].contains(host) else {return nil}
        return url
    }
    var body:some View {
        Form {
            Section("Конференция VK") {
                Button("Создать звонок",systemImage:"video.badge.plus") {Task {await create()}}.disabled(busy || !env.isLiveVKSession || callID != nil)
                TextField("Ссылка на звонок VK",text:$link).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                if let joinURL {
                    Button("Присоединиться",systemImage:"phone.fill") {openURL(joinURL)}
                    ShareLink(item:joinURL) {Label("Поделиться приглашением",systemImage:"square.and.arrow.up")}
                }
                if callID != nil {Button("Завершить для всех",role:.destructive) {confirmFinish=true}.disabled(busy)}
                if busy {ProgressView()}
                if let error {Text(error).foregroundStyle(.red)}
            }
            Section {
                Text("Создание и завершение конференции выполняет VK API. Аудио и видео открываются в официальном клиенте VK или браузере. Приём входящих звонков внутри приложения требует отдельного SDK и доступа VK.").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("Звонки")
        .confirmationDialog("Завершить звонок для всех участников?",isPresented:$confirmFinish) {Button("Завершить",role:.destructive) {Task {await finish()}}}
    }
    private func create() async {
        guard !busy else {return};busy=true;error=nil;defer {busy=false}
        do {
            let response=try await env.catalog.request("calls.start")
            guard let url=response["join_link"].url else {throw AppError.decoding}
            link=url.absoluteString
            let id=response["call_id"].string;callID=id.isEmpty ? nil : id
            guard joinURL != nil else {link="";throw AppError.decoding}
        } catch {self.error=error.localizedDescription}
    }
    private func finish() async {
        guard let callID,!busy else {return};busy=true;error=nil;defer {busy=false}
        do {
            let response=try await env.catalog.request("calls.forceFinish",["call_id":callID])
            guard response.int == 1 else {throw AppError.decoding}
            self.callID=nil;link=""
        } catch {self.error=error.localizedDescription}
    }
}

/// S43 — error / offline demo.
struct ErrorDemoView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var mode = "error"

    var body: some View {
        VStack {
            Picker("State", selection: $mode) {
                Text("Error").tag("error")
                Text("Offline").tag("offline")
                Text("Empty").tag("empty")
                Text("Permission").tag("permission")
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                switch mode {
                case "offline":
                    VKErrorState(message: "S43 · Offline", symbol: "wifi.slash", onRetry: {})
                case "empty":
                    VKEmptyState(symbol: "tray", title: "S43 · Empty", details: "Nothing here yet.")
                case "permission":
                    VKUnavailableState(title: "S43 · Permission", details: "Feature needs an official scope grant.")
                default:
                    VKErrorState(message: "S43 · Something went wrong", onRetry: {})
                }
            }
            Toggle("Simulate offline for app", isOn: Binding(
                get: { !env.isNetworkReachable },
                set: { env.isNetworkReachable = !$0 }
            ))
            .padding()
        }
        .navigationTitle("Состояния")
    }
}

/// S44 — confirmation / context menu demo.
struct ActionsDemoView: View {
    @State private var showConfirm = false
    @State private var showSheet = false
    @State private var result = "—"

    var body: some View {
        List {
            Section("S44") {
                Button("confirmationDialog") { showConfirm = true }
                Button("sheet") { showSheet = true }
                Text("Long-press row for contextMenu")
                    .contextMenu {
                        Button("Copy") { result = "Copy" }
                        Button("Share") { result = "Share" }
                        Button("Delete", role: .destructive) { result = "Delete" }
                    }
            }
            Section("Last action") {
                Text(result)
            }
        }
        .navigationTitle("Действия")
        .confirmationDialog("Выберите действие", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Primary") { result = "Primary" }
            Button("Destructive", role: .destructive) { result = "Destructive" }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showSheet) {
            NavigationStack {
                Text("System sheet content")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showSheet = false }
                        }
                    }
                    .navigationTitle("Sheet")
            }
            .presentationDetents([.medium])
        }
    }
}
