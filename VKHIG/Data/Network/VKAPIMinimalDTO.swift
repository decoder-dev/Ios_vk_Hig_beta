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
    var int: Int64 { if case .number(let v) = self { return Int64(v) }; return Int64(string) ?? 0 }
    var flag: Bool { if case .bool(let v) = self { return v }; return int == 1 }
    var url: URL? { URL(string: string).flatMap { $0.scheme == "https" ? $0 : nil } }
    var chatAttachments: [ChatAttachment] {
        items.compactMap { item in
            let type = item["type"].string
            let value = item[type]
            let url: URL?
            let kind: ChatAttachment.Kind
            switch type {
            case "photo": kind = .photo; url = value["sizes"].items.max { $0["width"].int < $1["width"].int }?["url"].url
            case "doc": kind = .document; url = value["url"].url
            case "video": kind = .video; url = value["player"].url
            default: return nil
            }
            guard let url else { return nil }
            return ChatAttachment(id:"\(type)_\(value["owner_id"].int)_\(value["id"].int)",kind:kind,title:value["title"].string.isEmpty ? "Вложение" : value["title"].string,url:url)
        }
    }
    var list: [VKJSON] { if case .array = self { return items }; return self["items"].items }
}

@MainActor
@Observable
final class VKCatalogService {
    static let shared = VKCatalogService()
    private var feedCursor: String?
    private var feedFinished = false
    let api: VKAPIClient
    private(set) var posts: [Int64: FeedPost] = [:]
    private(set) var photos: [Int64: PhotoItem] = [:]
    private(set) var videos: [Int64: VideoItem] = [:]
    private(set) var people: [Int64: Friend] = [:]
    var notice: String?
    init(api: VKAPIClient = VKAPIClient()) { self.api = api }
    func clear() { feedCursor = nil; feedFinished = false; posts = [:]; photos = [:]; videos = [:]; people = [:]; notice = nil }
    func request(_ method: String, _ parameters: [String: String] = [:]) async throws -> VKJSON {
        let owner = VKIDAuthCoordinator.shared.userID
        guard let token = await VKIDAuthCoordinator.shared.freshAccessToken() else { throw AppError.notAuthenticated }
        do {
            let response: VKJSON = try await api.call(method:method,parameters:parameters,accessToken:token,apiVersion:AppSecrets.vkAPIVersion)
            guard owner == VKIDAuthCoordinator.shared.userID else { throw AppError.notAuthenticated }
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
    static func initials(_ name: String) -> String { name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined() }
    static func name(_ j: VKJSON) -> String { [j["first_name"].string, j["last_name"].string].filter { !$0.isEmpty }.joined(separator: " ") }
    static func friend(_ j: VKJSON) -> Friend {
        let name = name(j)
        return Friend(id: j["id"].int, displayName: name, initials: initials(name), isOnline: j["online"].flag, city: j["city"]["title"].string.isEmpty ? nil : j["city"]["title"].string)
    }
    static func date(_ j: VKJSON) -> String { Date(timeIntervalSince1970: Double(j.int)).formatted(date: .abbreviated, time: .shortened) }
    static func photoURL(_ j: VKJSON) -> URL? { j["sizes"].items.max { $0["width"].int < $1["width"].int }?["url"].url }
    func mapPosts(_ response: VKJSON) -> [FeedPost] {
        let profiles = Dictionary(response["profiles"].items.map { ($0["id"].int, Self.name($0)) }, uniquingKeysWith: { a,_ in a })
        let groups = Dictionary(response["groups"].items.map { (-$0["id"].int, $0["name"].string) }, uniquingKeysWith: { a,_ in a })
        return response.list.compactMap { j in
            let nativeID = j["post_id"].int == 0 ? j["id"].int : j["post_id"].int
            guard nativeID != 0 else { return nil }
            let ownerID = j["source_id"].int == 0 ? j["owner_id"].int : j["source_id"].int
            let key = ownerID &* 1_000_000_000 &+ nativeID
            let author = profiles[ownerID] ?? groups[ownerID] ?? "VK \(ownerID)"
            let media = j["attachments"].items.compactMap { Self.photoURL($0["photo"]) }.first
            let post = FeedPost(id:key, authorName:author, authorInitials:Self.initials(author), dateLabel:Self.date(j["date"]), text:j["text"].string,
                hasMedia:media != nil, reactionCount:Int(j["likes"]["count"].int), commentCount:Int(j["comments"]["count"].int), ownerID:ownerID, nativeID:nativeID, mediaURL:media)
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
    func load<Value>(_ screen: String, resourceID: Int64? = nil, query: String = "") async throws -> Value {
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
            let response = try await request("messages.search", ["q":query,"peer_id":"\(resourceID ?? 0)","count":"100"])
            result = response.list.map { j in ChatMessage(id:UUID(),serverID:j["id"].int,peerID:PeerID(raw:resourceID ?? 0),text:j["text"].string,timestamp:Date(timeIntervalSince1970:Double(j["date"].int)),isOutgoing:j["out"].flag,state:.received,randomID:nil) }
        case "S11":
            let response = try await request("messages.getConversationsById",["peer_ids":"\(resourceID ?? 0)"])
            let members = try await request("messages.getConversationMembers",["peer_id":"\(resourceID ?? 0)","extended":"1","fields":"online,city","count":"200"])
            result = ChatDetails(peerID:resourceID ?? 0,title:response.list.first?["chat_settings"]["title"].string ?? "Диалог",members:members["profiles"].items.map(Self.friend))
        case "S15":
            let response = try await request("users.get", ["user_ids":"\(resourceID ?? 0)", "fields":"city,online,status"])
            guard let j = response.items.first else { throw AppError.network("Пользователь не найден.") }
            let person = Self.friend(j); people[person.id] = person; result = person
        case "S18", "S22":
            let response = try await request(screen == "S18" ? "friends.get" : "groups.getMembers", screen == "S18" ? ["fields":"city,online", "count":"5000"] : ["group_id":"\(resourceID ?? 0)", "fields":"city,online", "count":"1000"])
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
            let response = try await request(screen == "S20" ? "groups.getById" : "groups.get", screen == "S20" ? ["group_ids":"\(resourceID ?? 0)", "fields":"description,members_count,is_member"] : ["extended":"1", "fields":"description,members_count,is_member", "count":"1000"])
            let list = (screen == "S20" && !response["groups"].items.isEmpty ? response["groups"].items : response.list).map { j in Community(id:j["id"].int, name:j["name"].string, initials:Self.initials(j["name"].string), membersCount:Int(j["members_count"].int), description:j["description"].string, isMember:j["is_member"].flag) }
            if screen == "S20" { guard let first = list.first else { throw AppError.network("Сообщество не найдено.") }; result = first } else { result = list }
        case "S23":
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { result = [SearchHit](); break }
            async let users = request("users.search", ["q":query, "count":"50"])
            async let groups = request("groups.search", ["q":query, "count":"50"])
            let (u,g) = try await (users, groups)
            result = u.list.map { j in SearchHit(id:"u\(j["id"].int)", kind:.person, title:Self.name(j), subtitle:"", initials:Self.initials(Self.name(j))) } + g.list.map { j in SearchHit(id:"g\(j["id"].int)", kind:.community, title:j["name"].string, subtitle:"", initials:Self.initials(j["name"].string)) }
        case "S24":
            let response = try await request("notifications.get", ["count":"100"])
            result = response.list.enumerated().map { i,j in NotificationItem(id:j["date"].int &* 1000 &+ Int64(i), title:j["type"].string, body:j["text"].string, dateLabel:Self.date(j["date"]), symbol:"bell", isUnread:false) }
        case "S26":
            let response = try await request("photos.getAlbums", ["need_system":"1"])
            result = response.list.map { PhotoAlbum(id:$0["id"].int, title:$0["title"].string, count:Int($0["size"].int)) }
        case "S27":
            let response = try await request(resourceID == nil ? "photos.getAll" : "photos.get", resourceID.map { ["album_id":"\($0)", "count":"100", "photo_sizes":"1"] } ?? ["count":"100", "photo_sizes":"1"])
            let list = response.list.map { j in PhotoItem(id:j["id"].int, albumID:j["album_id"].int, caption:j["text"].string, url:Self.photoURL(j), ownerID:j["owner_id"].int) }
            for photo in list { photos[photo.id] = photo }; result = list
        case "S29":
            let response = try await request("video.get", ["count":"100"])
            let list = response.list.map { j in VideoItem(id:j["id"].int, title:j["title"].string, durationLabel:"\(j["duration"].int / 60):\(String(format:"%02lld",j["duration"].int % 60))", author:"VK", streamURL:j["files"]["mp4_720"].url ?? j["files"]["mp4_480"].url, playerURL:j["player"].url, ownerID:j["owner_id"].int) }
            for video in list { videos[video.id] = video }; result = list
        case "S40":
            let response = try await request("fave.get", ["count":"100"])
            result = response.list.enumerated().map { i,j in BookmarkItem(id:Int64(i), title:j["link"]["title"].string.isEmpty ? j["type"].string : j["link"]["title"].string, subtitle:j["link"]["url"].string, symbol:"bookmark") }
        default: throw AppError.capabilityUnavailable("Раздел \(screen) требует отдельного разрешения VK.")
        }
        guard let typed = result as? Value else { throw AppError.decoding }
        return typed
    }
}
