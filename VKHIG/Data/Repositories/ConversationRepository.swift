import Foundation

actor ConversationRepository {
    private let fixtures: FixtureStore
    private var localOutgoing: [Int64: [ChatMessage]] = [:]
    private let apiClient: VKAPIClient
    private var ids: [String: UUID] = [:]
    init(fixtures: FixtureStore, apiClient: VKAPIClient = VKAPIClient()) { self.fixtures = fixtures; self.apiClient = apiClient }
    private func request(_ method: String, _ parameters: [String: String], token: String?) async throws -> VKJSON {
        guard let token, !token.isEmpty else { throw AppError.notAuthenticated }
        return try await apiClient.call(method:method, parameters:parameters, accessToken:token, apiVersion:AppSecrets.vkAPIVersion)
    }
    func fetchInbox(dataMode: DataMode, capabilities: CapabilityRegistry, isNetworkReachable: Bool, accessToken: String? = nil, offset: Int = 0) async -> Result<[Conversation], AppError> {
        guard isNetworkReachable else { return .failure(.offline) }
        if dataMode == .fixtures { return .success(offset == 0 ? fixtures.conversations : []) }
        guard capabilities.canUseLiveAPI(.inbox) else { return .failure(.capabilityUnavailable("VK не выдал этому приложению доступ к сообщениям.")) }
        do {
            let response = try await request("messages.getConversations", ["count":"30", "offset":"\(offset)", "extended":"1", "fields":"online"], token:accessToken)
            var names = Dictionary(response["profiles"].items.map { j in (j["id"].int, [j["first_name"].string,j["last_name"].string].joined(separator:" ")) }, uniquingKeysWith:{ a,_ in a })
            for group in response["groups"].items { names[-group["id"].int] = group["name"].string }
            return .success(response.list.map { item in
                let c = item["conversation"], id = c["peer"]["id"].int
                let name = c["chat_settings"]["title"].string.isEmpty ? names[id] ?? "VK \(id)" : c["chat_settings"]["title"].string
                return Conversation(peerID:PeerID(raw:id), displayName:name, initials:String(name.prefix(2)).uppercased(), lastMessagePreview:item["last_message"]["text"].string,
                    lastUpdatedLabel:Date(timeIntervalSince1970:Double(item["last_message"]["date"].int)).formatted(date:.omitted,time:.shortened), unreadCount:Int(c["unread_count"].int), isOnline:false)
            })
        } catch { return .failure(Self.map(error)) }
    }
    func fetchHistory(peerID: PeerID, dataMode: DataMode, capabilities: CapabilityRegistry, isNetworkReachable: Bool, accessToken: String? = nil, offset: Int = 0) async -> Result<[ChatMessage], AppError> {
        guard isNetworkReachable else { return .failure(.offline) }
        if dataMode == .fixtures { return .success(offset == 0 ? (fixtures.messagesByPeer[peerID.raw] ?? []) + (localOutgoing[peerID.raw] ?? []) : []) }
        guard capabilities.canUseLiveAPI(.conversation) else { return .failure(.capabilityUnavailable("VK не выдал этому приложению доступ к истории сообщений.")) }
        do {
            let response = try await request("messages.getHistory", ["peer_id":"\(peerID.raw)","count":"50","offset":"\(offset)","rev":"0"], token:accessToken)
            return .success(response.list.reversed().map { j in
                let serverID = j["id"].int, key = "\(peerID.raw)_\(serverID)"
                let localID = ids[key] ?? UUID(); ids[key] = localID
                return ChatMessage(id:localID, serverID:serverID, peerID:peerID, text:j["text"].string.isEmpty && !j["attachments"].items.isEmpty ? "Вложение" : j["text"].string,
                    timestamp:Date(timeIntervalSince1970:Double(j["date"].int)), isOutgoing:j["out"].flag, state:j["out"].flag ? .sent : .received, randomID:j["random_id"].int == 0 ? nil : j["random_id"].int, attachments:j["attachments"].chatAttachments,quotes:j.messageQuotes)
            })
        } catch { return .failure(Self.map(error)) }
    }
    /// The caller owns randomID/localID and reuses them for every retry, including lost ACKs.
    func enqueueOutgoing(peerID: PeerID, text: String, dataMode: DataMode, capabilities: CapabilityRegistry, accessToken: String? = nil,
                         randomID: Int64 = Int64.random(in:1...Int64(Int32.max)), localID: UUID = UUID(), replyTo: Int64? = nil, forward: String? = nil, attachment: String? = nil) async -> Result<ChatMessage, AppError> {
        let trimmed = text.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !trimmed.isEmpty || attachment != nil || forward != nil else { return .failure(.network("Введите сообщение.")) }
        var message = ChatMessage(id:localID,serverID:nil,peerID:peerID,text:trimmed,timestamp:Date(),isOutgoing:true,state:.pending,randomID:randomID)
        if dataMode == .fixtures {
            var list = localOutgoing[peerID.raw] ?? []; list.removeAll { $0.id == localID }; list.append(message); localOutgoing[peerID.raw] = list
            return .success(message)
        }
        guard capabilities.canUseLiveAPI(.sendMessage) else { return .failure(.capabilityUnavailable("VK не выдал этому приложению доступ к отправке сообщений.")) }
        var parameters = ["peer_id":"\(peerID.raw)","message":trimmed,"random_id":"\(randomID)"]
        if let replyTo { parameters["reply_to"] = "\(replyTo)" }
        if let forward { parameters["forward_messages"] = forward }
        if let attachment { parameters["attachment"] = attachment }
        do {
            let response = try await request("messages.send", parameters, token:accessToken)
            guard response.int > 0 else { return .failure(.decoding) }
            ids["\(peerID.raw)_\(response.int)"] = localID
            message = ChatMessage(id:localID,serverID:response.int,peerID:peerID,text:trimmed,timestamp:message.timestamp,isOutgoing:true,state:.sent,randomID:randomID)
            return .success(message)
        } catch { return .failure(Self.map(error)) }
    }
    static func map(_ error: Error) -> AppError {
        if let app = error as? AppError { return app }
        if let network = error as? URLError, [.notConnectedToInternet,.networkConnectionLost].contains(network.code) { return .offline }
        if let vk = error as? VKAPITransportError {
            if case .remote(5, _) = vk { return .notAuthenticated }
            if case .remote(let code, _) = vk, [7,15,200,201,203,917].contains(code) { return .capabilityUnavailable("VK отказал в доступе (\(code)).") }
        }
        return .network(error.localizedDescription)
    }
}
