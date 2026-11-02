import Foundation

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
