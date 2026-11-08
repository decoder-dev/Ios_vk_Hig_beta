import Foundation

struct Friend: Identifiable, Hashable, Sendable {
    let id: Int64
    let displayName: String
    let initials: String
    let isOnline: Bool
    let city: String?
    var avatarURL: URL? = nil
    /// "Был в сети 15 минут назад" when VK returned last_seen.
    var lastSeen: String? = nil
}

struct FriendRequest: Identifiable, Hashable, Sendable {
    enum Direction: String, Hashable, Sendable { case incoming, outgoing }
    let id: Int64
    let user: Friend
    let direction: Direction
    let subtitle: String
}

struct Community: Identifiable, Hashable, Sendable {
    let id: Int64
    let name: String
    let initials: String
    let membersCount: Int
    let description: String
    let isMember: Bool
    var avatarURL: URL? = nil
    var coverURL: URL? = nil
    var activity: String? = nil
    var isVerified = false
}

struct CommentItem: Identifiable, Hashable, Sendable {
    let id: Int64
    let postID: Int64
    let author: String
    let initials: String
    let text: String
    let dateLabel: String
    let replyToID: Int64?
    var authorID: Int64 = 0
    var attachments:[ChatAttachment] = []
}

struct NotificationItem: Identifiable, Hashable, Sendable {
    let id: Int64
    let title: String
    let body: String
    let dateLabel: String
    let symbol: String
    let isUnread: Bool
    var targetURL: URL? = nil
    var category: Category = .other

    enum Category: String, Hashable, Sendable { case reactions, comments, other }
}

struct SearchHit: Identifiable, Hashable, Sendable {
    enum Kind: String, Hashable, Sendable { case person, community, post }
    let id: String
    let kind: Kind
    let title: String
    let subtitle: String
    let initials: String
    var avatarURL: URL? = nil
}

struct PhotoAlbum: Identifiable, Hashable, Sendable {
    let id: Int64
    let title: String
    let count: Int
    var coverURL: URL? = nil
}

struct PhotoItem: Identifiable, Hashable, Sendable {
    let id: Int64
    let albumID: Int64
    let caption: String
    var url: URL? = nil
    var ownerID: Int64 = 0
}

struct VideoItem: Identifiable, Hashable, Sendable {
    let id: Int64
    let title: String
    let durationLabel: String
    let author: String
    var streamURL: URL? = nil
    var playerURL: URL? = nil
    var ownerID: Int64 = 0
    var previewURL: URL? = nil
    var views: Int? = nil
    var dateLabel: String? = nil
}

struct TrackItem: Identifiable, Hashable, Sendable {
    let id: Int64
    let title: String
    let artist: String
    let durationLabel: String
}

struct PlaylistItem: Identifiable, Hashable, Sendable {
    let id: Int64
    let title: String
    let trackCount: Int
}

struct BookmarkItem: Identifiable, Hashable, Sendable {
    let id: Int64
    let title: String
    let subtitle: String
    let symbol: String
    var targetURL: URL? = nil
    var kind:String = "link"
    var ownerID:Int64 = 0
    var itemID:Int64 = 0
    var linkID:String = ""
}

struct StoryItem: Identifiable, Hashable, Sendable {
    let id: Int64
    let author: String
    let initials: String
}

struct ChatDetails: Equatable, Sendable {
    let peerID: Int64
    let title: String
    let members: [Friend]
    var canManage=false
    var canInvite=false
    var currentUserID:Int64=0
}

struct VKAction:Equatable,Sendable {
    let method:String
    let parameters:[String:String]
    static func chat(_ method:String,peerID:Int64,values:[String:String]=[:]) throws -> VKAction {
        guard peerID > 2_000_000_000 else {throw AppError.network("Действие доступно только в беседе.")}
        guard ["messages.editChat","messages.addChatUser","messages.removeChatUser"].contains(method) else {throw AppError.decoding}
        var parameters=values;parameters["chat_id"]=String(peerID-2_000_000_000)
        return VKAction(method:method,parameters:parameters)
    }
    static func bookmarkRemoval(_ item:BookmarkItem) throws -> VKAction {
        switch item.kind {
        case "post","video","product":
            guard item.ownerID != 0,item.itemID > 0 else {throw AppError.decoding}
            let suffix=item.kind == "post" ? "Post" : item.kind == "video" ? "Video" : "Product"
            return VKAction(method:"fave.remove"+suffix,parameters:["owner_id":String(item.ownerID),"id":String(item.itemID)])
        case "article":
            guard item.ownerID != 0,item.itemID>0 else {throw AppError.decoding}
            return VKAction(method:"fave.removeArticle",parameters:["owner_id":String(item.ownerID),"article_id":String(item.itemID)])
        case "page":
            guard item.ownerID != 0,item.ownerID != Int64.min else {throw AppError.decoding}
            return VKAction(method:"fave.removePage",parameters:[item.ownerID>0 ? "user_id" : "group_id":String(abs(item.ownerID))])
        case "link":
            if !item.linkID.isEmpty {return VKAction(method:"fave.removeLink",parameters:["link_id":item.linkID])}
            guard let url=item.targetURL, url.scheme=="https" else {throw AppError.decoding}
            return VKAction(method:"fave.removeLink",parameters:["link":url.absoluteString])
        default:throw AppError.capabilityUnavailable("Удаление этого типа сохранённого недоступно.")
        }
    }
    static func allows(_ policy:String,isOwner:Bool,isAdmin:Bool) -> Bool {
        switch policy {case "all":return true;case "owner_and_admins":return isOwner || isAdmin;case "owner":return isOwner;default:return false}
    }
}

extension BookmarkItem {
    static func stableID(_ value:String) -> Int64 {
        var hash:UInt64=14695981039346656037
        for byte in value.utf8 {hash=(hash ^ UInt64(byte)) &* 1099511628211}
        return Int64(bitPattern:hash)
    }
}
extension VKAction {
    static func bookmarkAddition(_ input:String) throws -> VKAction {
        guard let url=URL(string:input.trimmingCharacters(in:.whitespacesAndNewlines)),url.scheme=="https",url.host != nil,url.user==nil,url.password==nil else {throw AppError.network("Введите полную HTTPS-ссылку без логина и пароля.")}
        let hosts=["vk.com","www.vk.com","m.vk.com","vk.ru","www.vk.ru"]
        if hosts.contains(url.host?.lowercased() ?? "") {
            let path=url.path.trimmingCharacters(in:CharacterSet(charactersIn:"/"))
            for (prefix,method) in [("wall","fave.addPost"),("video","fave.addVideo")] where path.hasPrefix(prefix) {
                let values=path.dropFirst(prefix.count).split(separator:"_")
                if values.count==2,let owner=Int64(values[0]),let id=Int64(values[1]),owner != 0,id>0 {
                    var params=["owner_id":String(owner),"id":String(id)]
                    if let key=URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems?.first(where:{$0.name=="access_key"})?.value {params["access_key"]=key}
                    return VKAction(method:method,parameters:params)
                }
            }
        }
        return VKAction(method:"fave.addLink",parameters:["link":url.absoluteString])
    }
}
