import Foundation
import Observation

/// Minimal envelopes for live stubs. Expand after capturing real (redacted) fixtures on Mac.
struct VKCountItemsDTO<Item: Decodable>: Decodable {
    let count: Int?
    let items: [Item]?
}

struct VKConversationItemDTO: Decodable {
    let conversation: VKConversationMetaDTO?
    let last_message: VKLastMessageDTO?
}

struct VKConversationMetaDTO: Decodable {
    let peer: VKPeerDTO?
    let unread_count: Int?
}

struct VKPeerDTO: Decodable {
    let id: Int64?
    let type: String?
}

struct VKLastMessageDTO: Decodable {
    let text: String?
    let date: Int64?
}

// Minimal JSON boundary. Domain models remain strongly typed after mapping.
enum VKJSON: Decodable, Sendable {
    case object([String: VKJSON]), array([VKJSON]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode([String: VKJSON].self) { self = .object(v) }
        else if let v = try? c.decode([VKJSON].self) { self = .array(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else { self = .number(try c.decode(Double.self)) }
    }
    subscript(_ key: String) -> VKJSON { if case .object(let v) = self { return v[key] ?? .null }; return .null }
    var items: [VKJSON] { if case .array(let v) = self { return v }; return [] }
    var string: String { if case .string(let v) = self { return v }; return "" }
    var int: Int64 { if case .number(let v) = self {guard v.isFinite,v>=Double(Int64.min),v<Double(Int64.max) else {return 0};return Int64(v)}; return Int64(string) ?? 0 }
    var flag: Bool { if case .bool(let v) = self { return v }; return int == 1 }
    var url: URL? { URL(string: string).flatMap { $0.scheme == "https" ? $0 : nil } }
    var chatAttachments:[ChatAttachment] {
        items.enumerated().map {index,item in
            let type=item["type"].string,value=item[item["type"].string]
            var url:URL?,playback:URL?,kind:ChatAttachment.Kind = .unsupported
            var title=value["title"].string
            switch type {
            case "photo":kind = .photo;url=VKCatalogService.mediaPhotoURL(value)
            case "doc":kind = .document;url=value["url"].url
            case "video":
                kind = .video;url=value["player"].url
                playback=value["files"]["mp4_720"].url ?? value["files"]["mp4_480"].url
                if url == nil,value["owner_id"].int != 0,value["id"].int != 0 {url=URL(string:"https://vk.com/video\(value["owner_id"].int)_\(value["id"].int)")}
            case "audio":kind = .audio;url=value["url"].url;playback=url;title=[value["artist"].string,value["title"].string].filter {!$0.isEmpty}.joined(separator:" — ")
            case "audio_message":kind = .voice;url=value["link_mp3"].url;playback=url;title="Голосовое сообщение · \(value["duration"].int) с"
            case "sticker":kind = .sticker;url=value["images"].items.max {$0["width"].int < $1["width"].int}?["url"].url;title="Стикер"
            case "graffiti":kind = .graffiti;url=value["url"].url;title="Граффити"
            case "link":kind = .link;url=value["url"].url
            default:break
            }
            if title.isEmpty {title=kind == .photo ? "Фотография" : "Вложение VK: \(type)"}
            if url == nil {kind = .unsupported;title += " · нет доступного файла"}
            return ChatAttachment(id:"\(type)_\(value["owner_id"].int)_\(value["id"].int)_\(index)",kind:kind,title:title,url:url ?? URL(string:"https://vk.com/")!,playbackURL:playback)
        }
    }
    var messageQuotes:[ChatQuote] {
        func read(_ message:VKJSON,depth:Int,path:String) -> [ChatQuote] {
            guard depth<3 else {return []}
            var result:[ChatQuote]=[]
            if case .object=message["reply_message"] {
                let reply=message["reply_message"]
                result.append(ChatQuote(id:path+"reply",title:"Ответ на сообщение",text:reply["text"].string,attachments:reply["attachments"].chatAttachments))
            }
            for (index,forward) in message["fwd_messages"].items.prefix(10).enumerated() {
                let key=path+"forward\(index)"
                result.append(ChatQuote(id:key,title:"Пересланное сообщение",text:forward["text"].string,attachments:forward["attachments"].chatAttachments))
                result+=read(forward,depth:depth+1,path:key)
            }
            return result
        }
        return read(self,depth:0,path:"")
    }
    var list: [VKJSON] { if case .array = self { return items }; return self["items"].items }
}

@MainActor
@Observable
final class VKCatalogService {
    static let shared = VKCatalogService()
    private var feedCursor: String?
    private var feedFinished = false
    private var offsets:[String:Int]=[:]
    private var buffers:[String:Any]=[:]
    private var morePages:[String:Bool]=[:]
    private var pageCursors:[String:String]=[:]
    private let pagedScreens:Set<String>=["S14","S18","S21","S22","S24","S26","S27","S29","S40"]
    func pageKey(_ screen:String,_ id:Int64?,_ query:String) -> String {"\(screen):\(id ?? 0):\(query)"}
    func hasMore(_ screen:String,resourceID:Int64?,query:String) -> Bool {morePages[pageKey(screen,resourceID,query)] == true}
    private func joinArrays<Value>(_ old:Value?,_ new:Value) -> Value {
        func join<T:Identifiable>(_ old:[T],_ new:[T]) -> [T] {var ids=Set(old.map(\.id));return old+new.filter {ids.insert($0.id).inserted}}
        guard let old else {return new}
        let merged:Any
        switch (old,new) {
        case (let a as [ChatMessage],let b as [ChatMessage]):
            var ids=Set(a.compactMap(\.serverID));merged=a+b.filter {message in guard let id=message.serverID else {return true};return ids.insert(id).inserted}
        case (let a as [Friend],let b as [Friend]):merged=join(a,b)
        case (let a as [Community],let b as [Community]):merged=join(a,b)
        case (let a as [PhotoAlbum],let b as [PhotoAlbum]):merged=join(a,b)
        case (let a as [PhotoItem],let b as [PhotoItem]):merged=join(a,b)
        case (let a as [VideoItem],let b as [VideoItem]):merged=join(a,b)
        case (let a as [BookmarkItem],let b as [BookmarkItem]):merged=join(a,b)
        case (let a as [NotificationItem],let b as [NotificationItem]):merged=join(a,b)
        default:merged=new
        }
        return merged as? Value ?? new
    }
    let api: VKAPIClient
    private(set) var posts: [Int64: FeedPost] = [:]
    private(set) var photos: [Int64: PhotoItem] = [:]
    private(set) var videos: [Int64: VideoItem] = [:]
    var stories:[Int64:VKStory]=[:]
    private(set) var people: [Int64: Friend] = [:]
    var notice: String?
    init(api: VKAPIClient = VKAPIClient()) { self.api = api }
    func clear() { offsets=[:];buffers=[:];morePages=[:];pageCursors=[:];feedCursor = nil; feedFinished = false; posts = [:]; photos = [:]; videos = [:]; people = [:]; stories=[:]; notice = nil }
    func request(_ method: String, _ parameters: [String: String] = [:]) async throws -> VKJSON {
        let owner = VKSession.currentUserID
        guard let token = await VKSession.accessToken() else { throw AppError.notAuthenticated }
        do {
            let response: VKJSON = try await api.call(method:method,parameters:parameters,accessToken:token,apiVersion:AppSecrets.vkAPIVersion)
            guard owner == VKSession.currentUserID else { throw AppError.notAuthenticated }
            return response
        }
        catch let error as VKAPITransportError {
            switch error {
            case .remote(5, _), .authorizationRequired: throw AppError.notAuthenticated
            case .remote(let code, _) where [7, 15, 200, 201, 203, 260, 917].contains(code):
                throw AppError.capabilityUnavailable("VK не предоставил доступ к \(method) (код \(code)).")
            default: throw AppError.network(error.localizedDescription)
            }
        } catch let error as URLError where [.notConnectedToInternet, .networkConnectionLost].contains(error.code) { throw AppError.offline }
    }
    func perform(_ method: String, _ parameters: [String: String] = [:]) async -> Bool {
        do { _ = try await request(method, parameters); notice = "Готово"; return true }
        catch { notice = error.localizedDescription; return false }
    }
    nonisolated static func initials(_ name: String) -> String { name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined() }
    nonisolated static func name(_ j: VKJSON) -> String { [j["first_name"].string, j["last_name"].string].filter { !$0.isEmpty }.joined(separator: " ") }
    nonisolated static func friend(_ j: VKJSON) -> Friend {
        let name = name(j)
        return Friend(id: j["id"].int, displayName: name, initials: initials(name), isOnline: j["online"].flag, city: j["city"]["title"].string.isEmpty ? nil : j["city"]["title"].string,
                      avatarURL: avatarURL(j), lastSeen: lastSeen(j))
    }
    /// Largest square avatar VK returned for a user or group.
    nonisolated static func avatarURL(_ j: VKJSON) -> URL? { j["photo_200"].url ?? j["photo_100"].url ?? j["photo_50"].url }
    nonisolated static func lastSeen(_ j: VKJSON) -> String? {
        if j["online"].flag { return "Онлайн" }
        let time = j["last_seen"]["time"].int
        guard time > 0 else { return nil }
        let relative = Date(timeIntervalSince1970: Double(time)).formatted(.relative(presentation: .named))
        return (j["sex"].int == 1 ? "Была в сети " : "Был в сети ") + relative
    }
    nonisolated static func community(_ j: VKJSON) -> Community {
        let cover = j["cover"]["enabled"].flag ? j["cover"]["images"].items.max { $0["width"].int < $1["width"].int }?["url"].url : nil
        return Community(id:j["id"].int, name:j["name"].string, initials:Self.initials(j["name"].string), membersCount:Int(j["members_count"].int), description:j["description"].string, isMember:j["is_member"].flag,
                         avatarURL:avatarURL(j), coverURL:cover, activity:j["activity"].string.isEmpty ? nil : j["activity"].string, isVerified:j["verified"].flag)
    }
    nonisolated static func date(_ j: VKJSON) -> String { Date(timeIntervalSince1970: Double(j.int)).formatted(date: .abbreviated, time: .shortened) }
    nonisolated static func mediaPhotoURL(_ j:VKJSON) -> URL? {j["sizes"].items.max {$0["width"].int < $1["width"].int}?["url"].url}
    nonisolated static func photoURL(_ j: VKJSON) -> URL? { j["sizes"].items.max { $0["width"].int < $1["width"].int }?["url"].url }
    func mapPosts(_ response: VKJSON) -> [FeedPost] {
        let profiles = Dictionary(response["profiles"].items.map { ($0["id"].int, Self.name($0)) }, uniquingKeysWith: { a,_ in a })
        let groups = Dictionary(response["groups"].items.map { (-$0["id"].int, $0["name"].string) }, uniquingKeysWith: { a,_ in a })
        var avatars: [Int64: URL] = [:]
        for p in response["profiles"].items { if let url = Self.avatarURL(p) { avatars[p["id"].int] = url } }
        for g in response["groups"].items { if let url = Self.avatarURL(g) { avatars[-g["id"].int] = url } }
        return response.list.compactMap { j in
            let nativeID = j["post_id"].int == 0 ? j["id"].int : j["post_id"].int
            guard nativeID != 0 else { return nil }
            let ownerID = j["source_id"].int == 0 ? j["owner_id"].int : j["source_id"].int
            let key = ownerID &* 1_000_000_000 &+ nativeID
            let author = profiles[ownerID] ?? groups[ownerID] ?? "VK \(ownerID)"
            let media = j["attachments"].items.compactMap { Self.photoURL($0["photo"]) }.first
            let post = FeedPost(id:key, authorName:author, authorInitials:Self.initials(author), dateLabel:Self.date(j["date"]), text:j["text"].string,
                hasMedia:media != nil, reactionCount:Int(j["likes"]["count"].int), commentCount:Int(j["comments"]["count"].int), ownerID:ownerID, nativeID:nativeID, mediaURL:media, attachments:j["attachments"].chatAttachments,
                avatarURL:avatars[ownerID], repostCount:Int(j["reposts"]["count"].int), viewCount:j["views"]["count"].int > 0 ? Int(j["views"]["count"].int) : nil)
            posts[key] = post
            return post
        }
    }
    func feed(reset: Bool) async throws -> [FeedPost] {
        if reset { feedCursor = nil; feedFinished = false }
        if feedFinished { return [] }
        var parameters = ["count":"30", "filters":"post"]
        if let cursor = feedCursor { parameters["start_from"] = cursor }
        let response = try await request("newsfeed.get", parameters)
        let next = response["next_from"].string
        feedFinished = next.isEmpty || next == feedCursor
        feedCursor = next.isEmpty ? nil : next
        return mapPosts(response)
    }
    func post(_ id: Int64) throws -> FeedPost {
        guard let post = posts[id] else { throw AppError.network("Запись не найдена. Обновите ленту.") }; return post
    }
    func load<Value>(_ screen: String, resourceID: Int64? = nil, query: String = "",append:Bool = false) async throws -> Value {
        let key=pageKey(screen,resourceID,query)
        let offset=append ? offsets[key] ?? 0 : 0
        let pageSize=100
        var nextCursor:String?
        let result: Any
        switch screen {
        case "S05": result = try post(resourceID ?? 0)
        case "S06":
            let p = try post(resourceID ?? 0)
            let response = try await request("wall.getComments", ["owner_id":"\(p.ownerID)", "post_id":"\(p.nativeID ?? p.id)", "extended":"1", "count":"100", "thread_items_count":"10"])
            let names = Dictionary(response["profiles"].items.map { ($0["id"].int, Self.name($0)) }, uniquingKeysWith: { a,_ in a })
            result = response.list.map { j in CommentItem(id:j["id"].int, postID:resourceID ?? 0, author:names[j["from_id"].int] ?? "VK", initials:Self.initials(names[j["from_id"].int] ?? "VK"), text:j["text"].string, dateLabel:Self.date(j["date"]), replyToID:j["reply_to_comment"].int == 0 ? nil : j["reply_to_comment"].int) }
        case "S14":
            guard !query.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { result = [ChatMessage](); break }
            let response = try await request("messages.search", ["q":query,"peer_id":"\(resourceID ?? 0)","count":"100","offset":"\(offset)"])
            result = response.list.map { j in ChatMessage(id:UUID(),serverID:j["id"].int,peerID:PeerID(raw:resourceID ?? 0),text:j["text"].string,timestamp:Date(timeIntervalSince1970:Double(j["date"].int)),isOutgoing:j["out"].flag,state:.received,randomID:nil,attachments:j["attachments"].chatAttachments,quotes:j.messageQuotes) }
        case "S11":
            let response = try await request("messages.getConversationsById",["peer_ids":"\(resourceID ?? 0)"])
            let members = try await request("messages.getConversationMembers",["peer_id":"\(resourceID ?? 0)","extended":"1","fields":"online,city,photo_100","count":"200"])
            result = ChatDetails(peerID:resourceID ?? 0,title:response.list.first?["chat_settings"]["title"].string ?? "Диалог",members:members["profiles"].items.map(Self.friend))
        case "S15":
            let response = try await request("users.get", ["user_ids":"\(resourceID ?? 0)", "fields":"city,online,status,photo_200,last_seen,sex"])
            guard let j = response.items.first else { throw AppError.network("Пользователь не найден.") }
            let person = Self.friend(j); people[person.id] = person; result = person
        case "S18", "S22":
            var parameters=["fields":"city,online,photo_100,last_seen,sex","count":"100","offset":"\(offset)"]
            let method:String
            if screen == "S18" {
                let text=query.trimmingCharacters(in:.whitespacesAndNewlines)
                method=text.isEmpty ? "friends.get" : "friends.search"
                if !text.isEmpty {parameters["q"]=text}
            } else {method="groups.getMembers";parameters["group_id"]="\(resourceID ?? 0)"}
            let response=try await request(method,parameters)
            let list = response.list.map(Self.friend); for person in list { people[person.id] = person }; result = list
        case "S19":
            async let incoming = request("friends.getRequests", ["extended":"1", "count":"1000"])
            async let outgoing = request("friends.getRequests", ["out":"1", "count":"1000"])
            let (ins,outs) = try await (incoming,outgoing)
            let incomingIDs = ins.list.map { $0["user_id"].int == 0 ? $0.int : $0["user_id"].int }
            let outgoingIDs = outs.list.map { $0["user_id"].int == 0 ? $0.int : $0["user_id"].int }
            var people: [Int64:Friend] = [:]
            let allIDs = Array(Set(incomingIDs + outgoingIDs))
            if !allIDs.isEmpty {
                let users = try await request("users.get",["user_ids":allIDs.prefix(1000).map(String.init).joined(separator:",")])
                for user in users.items { let friend = Self.friend(user); people[friend.id] = friend }
            }
            result = incomingIDs.map { id in FriendRequest(id:id,user:people[id] ?? Friend(id:id,displayName:"VK \(id)",initials:"VK",isOnline:false,city:nil),direction:.incoming,subtitle:"Входящая заявка") }
                + outgoingIDs.map { id in FriendRequest(id:id,user:people[id] ?? Friend(id:id,displayName:"VK \(id)",initials:"VK",isOnline:false,city:nil),direction:.outgoing,subtitle:"Исходящая заявка") }
        case "S20", "S21":
            let response = try await request(screen == "S20" ? "groups.getById" : "groups.get", screen == "S20" ? ["group_ids":"\(resourceID ?? 0)", "fields":"description,members_count,is_member,activity,verified,cover"] : ["extended":"1", "fields":"description,members_count,is_member,activity,verified", "count":"100","offset":"\(offset)"])
            let list = (screen == "S20" && !response["groups"].items.isEmpty ? response["groups"].items : response.list).map(Self.community)
            if screen == "S20" { guard let first = list.first else { throw AppError.network("Сообщество не найдено.") }; result = first } else { result = list }
        case "S23":
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { result = [SearchHit](); break }
            async let users = request("users.search", ["q":query, "count":"50", "fields":"photo_100,city"])
            async let groups = request("groups.search", ["q":query, "count":"50"])
            let (u,g) = try await (users, groups)
            result = u.list.map { j in SearchHit(id:"u\(j["id"].int)", kind:.person, title:Self.name(j), subtitle:j["city"]["title"].string, initials:Self.initials(Self.name(j)), avatarURL:Self.avatarURL(j)) } + g.list.map { j in SearchHit(id:"g\(j["id"].int)", kind:.community, title:j["name"].string, subtitle:"Сообщество", initials:Self.initials(j["name"].string), avatarURL:Self.avatarURL(j)) }
        case "S24":
            var parameters=["count":"100"]
            if append,let cursor=pageCursors[key] {parameters["start_from"]=cursor}
            let response=try await request("notifications.get",parameters)
            nextCursor=response["next_from"].string.isEmpty ? nil : response["next_from"].string
            result=response.list.enumerated().map {i,j in
                let type=j["type"].string,parent=j["parent"]
                let labels=["like_post":"Отметка «Нравится»","comment_post":"Новый комментарий","reply_comment":"Ответ на комментарий","follow":"Новый подписчик","friend_accepted":"Заявка принята"]
                let owner=parent["owner_id"].int == 0 ? parent["to_id"].int : parent["owner_id"].int
                let target:URL?=(type.contains("post") || type.contains("comment")) && owner != 0 && parent["id"].int != 0 ? URL(string:"https://vk.com/wall\(owner)_\(parent["id"].int)") : URL(string:"https://vk.com/feed?section=notifications")
                let category:NotificationItem.Category=type.hasPrefix("like") ? .reactions : (type.contains("comment") || type.hasPrefix("reply")) ? .comments : .other
                let symbol=category == .reactions ? "heart.fill" : category == .comments ? "bubble.left.fill" : type.hasPrefix("follow") || type.hasPrefix("friend") ? "person.fill" : "bell.fill"
                return NotificationItem(id:j["date"].int &* 1000 &+ Int64(offset+i),title:labels[type] ?? "Уведомление VK",body:j["feedback"]["text"].string,dateLabel:Self.date(j["date"]),symbol:symbol,isUnread:j["date"].int > response["last_viewed"].int,targetURL:target,category:category)
            }
        case "S26":
            let response = try await request("photos.getAlbums", ["need_system":"1","need_covers":"1","photo_sizes":"1","offset":"\(offset)","count":"100"])
            result = response.list.map { PhotoAlbum(id:$0["id"].int, title:$0["title"].string, count:Int($0["size"].int), coverURL:Self.photoURL($0) ?? $0["thumb_src"].url) }
        case "S27":
            let response = try await request(resourceID == nil ? "photos.getAll" : "photos.get", resourceID.map { ["album_id":"\($0)", "count":"100", "photo_sizes":"1","offset":"\(offset)"] } ?? ["count":"100", "photo_sizes":"1","offset":"\(offset)"])
            let list = response.list.map { j in PhotoItem(id:j["id"].int, albumID:j["album_id"].int, caption:j["text"].string, url:Self.photoURL(j), ownerID:j["owner_id"].int) }
            for photo in list { photos[photo.id] = photo }; result = list
        case "S29":
            let response = try await request("video.get", ["count":"100","offset":"\(offset)"])
            let list = response.list.map { j in VideoItem(id:j["id"].int, title:j["title"].string, durationLabel:"\(j["duration"].int / 60):\(String(format:"%02lld",j["duration"].int % 60))", author:"VK", streamURL:j["files"]["mp4_720"].url ?? j["files"]["mp4_480"].url, playerURL:j["player"].url, ownerID:j["owner_id"].int,
                previewURL:j["image"].items.max { $0["width"].int < $1["width"].int }?["url"].url, views:j["views"].int > 0 ? Int(j["views"].int) : nil, dateLabel:j["date"].int > 0 ? Self.date(j["date"]) : nil) }
            for video in list { videos[video.id] = video }; result = list
        case "S40":
            let response = try await request("fave.get", ["count":"100","offset":"\(offset)"])
            result = Self.mapBookmarks(response)
        default: throw AppError.capabilityUnavailable("Раздел \(screen) требует отдельного разрешения VK.")
        }
        guard let typed = result as? Value else { throw AppError.decoding }
        if pagedScreens.contains(screen) {
            let count=Mirror(reflecting:typed).children.count
            offsets[key]=offset+count
            morePages[key]=screen == "S24" ? nextCursor != nil : count == pageSize
            if let nextCursor {pageCursors[key]=nextCursor} else {pageCursors.removeValue(forKey:key)}
            let combined=append ? joinArrays(buffers[key] as? Value,typed) : typed
            buffers[key]=combined
            return combined
        }
        return typed
    }
    private static func bookmarkURL(_ j:VKJSON) -> URL? {
        let type=j["type"].string,value=j[j["type"].string]
        guard value["id"].int != 0,value["owner_id"].int != 0 else {return nil}
        let prefix:String
        switch type {case "post":prefix="wall";case "photo":prefix="photo";case "video":prefix="video";default:return nil}
        return URL(string:"https://vk.com/\(prefix)\(value["owner_id"].int)_\(value["id"].int)")
    }
}
