import Foundation

/// A simplified example of an idempotent local-UI message store.
/// Real VK peer/conversation IDs and API semantics must be verified.
struct VKPendingMessage: Identifiable, Equatable, Sendable {
    enum State: Equatable, Sendable { case pending, sent, failed }
    let id: UUID                       // stable local item identity
    let randomID: Int64                // distinct value for a send request
    let peerID: Int64
    let content: String
    var serverID: Int64?               // canonical ID only after VK confirms
    var state: State
}

actor VKMessageReconciler {
    private var byLocalID: [UUID: VKPendingMessage] = [:]
    private var byServerID: [Int64: UUID] = [:]
    private var byRequestKey: [String: UUID] = [:]

    func prepare(peerID: Int64, content: String, randomID: Int64) -> VKPendingMessage {
        let key = "\(peerID):\(randomID)"
        if let localID = byRequestKey[key], let existing = byLocalID[localID] { return existing }
        let item = VKPendingMessage(id: UUID(), randomID: randomID, peerID: peerID,
                                    content: content, serverID: nil, state: .pending)
        byLocalID[item.id] = item
        byRequestKey[key] = item.id
        return item
    }

    /// Repeated confirmations with the same server id must resolve to one item.
    @discardableResult
    func confirm(localID: UUID, serverID: Int64) -> VKPendingMessage? {
        guard var item = byLocalID[localID] else { return nil }
        if let owner = byServerID[serverID], owner != localID {
            // Converging local attempts must not create a duplicate on a server replay.
            byLocalID.removeValue(forKey: localID)
            byRequestKey.removeValue(forKey: "\(item.peerID):\(item.randomID)")
            return byLocalID[owner]
        }
        item.serverID = serverID
        item.state = .sent
        byLocalID[localID] = item
        byServerID[serverID] = localID
        return item
    }

    func markFailed(localID: UUID) {
        guard var item = byLocalID[localID] else { return }
        item.state = .failed
        byLocalID[localID] = item
    }

    func snapshot() -> [VKPendingMessage] {
        Array(byLocalID.values).sorted { $0.id.uuidString < $1.id.uuidString }
    }
}
