import Foundation

struct PendingSend: Identifiable, Equatable, Sendable {
    enum State: Equatable, Sendable { case pending, sent, failed }
    let id: UUID
    let randomID: Int64
    let peerID: Int64
    let content: String
    var serverID: Int64?
    var state: State
}

/// Idempotent local send ledger keyed by peer_id + random_id.
actor MessageReconciler {
    private var byLocalID: [UUID: PendingSend] = [:]
    private var byServerID: [Int64: UUID] = [:]
    private var byRequestKey: [String: UUID] = [:]

    func prepare(peerID: Int64, content: String, randomID: Int64) -> PendingSend {
        let key = "\(peerID):\(randomID)"
        if let localID = byRequestKey[key], let existing = byLocalID[localID] {
            return existing
        }
        let item = PendingSend(
            id: UUID(),
            randomID: randomID,
            peerID: peerID,
            content: content,
            serverID: nil,
            state: .pending
        )
        byLocalID[item.id] = item
        byRequestKey[key] = item.id
        return item
    }

    @discardableResult
    func confirm(localID: UUID, serverID: Int64) -> PendingSend? {
        guard var item = byLocalID[localID] else { return nil }
        if let owner = byServerID[serverID], owner != localID {
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

    func snapshot() -> [PendingSend] {
        Array(byLocalID.values).sorted { $0.id.uuidString < $1.id.uuidString }
    }
}
