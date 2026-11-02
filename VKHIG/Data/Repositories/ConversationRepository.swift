import Foundation

/// Inbox + conversation history. Live `messages.*` stays gated until scopes verified.
actor ConversationRepository {
    private let fixtures: FixtureStore
    private var reconciler = MessageReconciler()
    /// Local-only pending queue when fixtures mode simulates composer.
    private var localOutgoing: [Int64: [ChatMessage]] = [:]

    init(fixtures: FixtureStore) {
        self.fixtures = fixtures
    }

    func fetchInbox(
        dataMode: DataMode,
        capabilities: CapabilityRegistry,
        isNetworkReachable: Bool
    ) async -> Result<[Conversation], AppError> {
        if !isNetworkReachable { return .failure(.offline) }

        if capabilities.canUseLiveAPI(.inbox) {
            // TODO(live): messages.getConversations via VKAPIClient + token provider.
            return .failure(.capabilityUnavailable("messages.getConversations"))
        }

        switch dataMode {
        case .fixtures:
            let items = fixtures.conversations
            return .success(items)
        case .live:
            return .failure(.capabilityUnavailable("Inbox requires verified messages scope"))
        }
    }

    func fetchHistory(
        peerID: PeerID,
        dataMode: DataMode,
        capabilities: CapabilityRegistry,
        isNetworkReachable: Bool
    ) async -> Result<[ChatMessage], AppError> {
        if !isNetworkReachable { return .failure(.offline) }

        if capabilities.canUseLiveAPI(.conversation) {
            return .failure(.capabilityUnavailable("messages.getHistory"))
        }

        switch dataMode {
        case .fixtures:
            let base = fixtures.messagesByPeer[peerID.raw] ?? []
            let pending = localOutgoing[peerID.raw] ?? []
            return .success(base + pending)
        case .live:
            return .failure(.capabilityUnavailable("Conversation history requires verified messages scope"))
        }
    }

    /// Enqueues outgoing text. Fixture mode keeps `.pending` (never fake live ACK).
    func enqueueOutgoing(
        peerID: PeerID,
        text: String,
        dataMode: DataMode,
        capabilities: CapabilityRegistry
    ) async -> Result<ChatMessage, AppError> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.network("Empty message"))
        }

        let randomID = Int64.random(in: 1...Int64.max)
        let pending = await reconciler.prepare(peerID: peerID.raw, content: trimmed, randomID: randomID)
        let message = ChatMessage(
            id: pending.id,
            serverID: nil,
            peerID: peerID,
            text: trimmed,
            timestamp: Date(),
            isOutgoing: true,
            state: .pending,
            randomID: randomID
        )

        if capabilities.canUseLiveAPI(.sendMessage) {
            await reconciler.markFailed(localID: pending.id)
            return .failure(.capabilityUnavailable("messages.send"))
        }

        switch dataMode {
        case .fixtures:
            var list = localOutgoing[peerID.raw] ?? []
            list.append(message)
            localOutgoing[peerID.raw] = list
            return .success(message)
        case .live:
            await reconciler.markFailed(localID: pending.id)
            return .failure(.capabilityUnavailable("Send requires verified messages scope"))
        }
    }
}
