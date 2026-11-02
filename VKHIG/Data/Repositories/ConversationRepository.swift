import Foundation

/// Inbox + conversation history.
actor ConversationRepository {
    private let fixtures: FixtureStore
    private var reconciler = MessageReconciler()
    private var localOutgoing: [Int64: [ChatMessage]] = [:]
    private let apiClient: VKAPIClient

    init(fixtures: FixtureStore, apiClient: VKAPIClient = VKAPIClient()) {
        self.fixtures = fixtures
        self.apiClient = apiClient
    }

    func fetchInbox(
        dataMode: DataMode,
        capabilities: CapabilityRegistry,
        isNetworkReachable: Bool,
        accessToken: String? = nil
    ) async -> Result<[Conversation], AppError> {
        if !isNetworkReachable { return .failure(.offline) }

        if capabilities.canUseLiveAPI(.inbox) {
            guard let accessToken, !accessToken.isEmpty else {
                return .failure(.notAuthenticated)
            }
            do {
                let response: VKCountItemsDTO<VKConversationItemDTO> = try await apiClient.call(
                    method: "messages.getConversations",
                    parameters: ["count": "20", "extended": "1"],
                    accessToken: accessToken,
                    apiVersion: AppSecrets.vkAPIVersion
                )
                let mapped = (response.items ?? []).compactMap { Self.mapConversation($0) }
                return mapped.isEmpty ? .success([]) : .success(mapped)
            } catch let error as VKAPITransportError {
                return .failure(.network(error.localizedDescription))
            } catch {
                return .failure(.decoding)
            }
        }

        switch dataMode {
        case .fixtures:
            return .success(fixtures.conversations)
        case .live:
            if accessToken == nil || accessToken?.isEmpty == true {
                return .failure(.notAuthenticated)
            }
            return .failure(.capabilityUnavailable("Inbox requires verified messages scope in CapabilityRegistry"))
        }
    }

    func fetchHistory(
        peerID: PeerID,
        dataMode: DataMode,
        capabilities: CapabilityRegistry,
        isNetworkReachable: Bool,
        accessToken: String? = nil
    ) async -> Result<[ChatMessage], AppError> {
        if !isNetworkReachable { return .failure(.offline) }

        if capabilities.canUseLiveAPI(.conversation) {
            guard let accessToken, !accessToken.isEmpty else {
                return .failure(.notAuthenticated)
            }
            return .failure(.capabilityUnavailable("messages.getHistory mapping pending verification"))
        }

        switch dataMode {
        case .fixtures:
            let base = fixtures.messagesByPeer[peerID.raw] ?? []
            let pending = localOutgoing[peerID.raw] ?? []
            return .success(base + pending)
        case .live:
            if accessToken == nil || accessToken?.isEmpty == true {
                return .failure(.notAuthenticated)
            }
            return .failure(.capabilityUnavailable("Conversation history requires verified messages scope"))
        }
    }

    func enqueueOutgoing(
        peerID: PeerID,
        text: String,
        dataMode: DataMode,
        capabilities: CapabilityRegistry,
        accessToken: String? = nil
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
            guard let accessToken, !accessToken.isEmpty else {
                await reconciler.markFailed(localID: pending.id)
                return .failure(.notAuthenticated)
            }
            await reconciler.markFailed(localID: pending.id)
            return .failure(.capabilityUnavailable("messages.send mapping pending verification"))
        }

        switch dataMode {
        case .fixtures:
            var list = localOutgoing[peerID.raw] ?? []
            list.append(message)
            localOutgoing[peerID.raw] = list
            return .success(message)
        case .live:
            await reconciler.markFailed(localID: pending.id)
            if accessToken == nil || accessToken?.isEmpty == true {
                return .failure(.notAuthenticated)
            }
            return .failure(.capabilityUnavailable("Send requires verified messages scope"))
        }
    }

    private static func mapConversation(_ dto: VKConversationItemDTO) -> Conversation? {
        guard let peerID = dto.conversation?.peer?.id else { return nil }
        let name: String
        if peerID >= 2_000_000_000 {
            name = "Chat \(peerID)"
        } else {
            name = "User \(peerID)"
        }
        let initials = String(name.suffix(2)).uppercased()
        return Conversation(
            peerID: PeerID(raw: peerID),
            displayName: name,
            initials: initials,
            lastMessagePreview: dto.last_message?.text ?? "",
            lastUpdatedLabel: "—",
            unreadCount: dto.conversation?.unread_count ?? 0,
            isOnline: false
        )
    }
}
