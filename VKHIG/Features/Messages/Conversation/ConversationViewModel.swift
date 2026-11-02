import Foundation
import Observation

@MainActor
@Observable
final class ConversationViewModel {
    let conversation: Conversation
    private let environment: AppEnvironment
    var state: LoadState<[ChatMessage]> = .idle
    var draft = ""
    var usesFixtures = false
    var sendNotice: String?
    var replyingTo: ChatMessage?
    var scrollToMessage: UUID?
    var isSending = false
    var loadingOlder = false
    var reachedStart = false
    private var serverOffset = 0
    private var loading = false
    private struct Pending: Codable {
        let id: UUID
        let randomID: Int64
        let text: String
        let created: Date
        let replyTo: Int64?
    }
    private var pending: [Pending] = []
    private let owner: String
    private var draftKey: String { "vkhig.draft.\(owner).\(conversation.id)" }
    private var outboxURL: URL {
        FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
            .appendingPathComponent("VKOutbox",isDirectory:true).appendingPathComponent("\(owner)_\(conversation.id).json")
    }
    init(conversation: Conversation, environment: AppEnvironment) {
        self.conversation = conversation; self.environment = environment
        self.owner = String(VKIDAuthCoordinator.shared.userID ?? 0)
        draft = UserDefaults.standard.string(forKey:draftKey) ?? ""
        if let data = try? Data(contentsOf:outboxURL), let saved = try? JSONDecoder().decode([Pending].self,from:data) { pending = saved }
    }
    func persistDraft() { UserDefaults.standard.set(draft, forKey:draftKey) }
    private func saveOutbox() {
        do {
            try FileManager.default.createDirectory(at:outboxURL.deletingLastPathComponent(),withIntermediateDirectories:true)
            try JSONEncoder().encode(pending).write(to:outboxURL,options:[.atomic,.completeFileProtectionUnlessOpen])
        } catch { sendNotice = "Не удалось сохранить очередь. Не закрывайте приложение до повторной отправки." }
    }
    private func pendingMessages() -> [ChatMessage] {
        pending.map { ChatMessage(id:$0.id,serverID:nil,peerID:conversation.peerID,text:$0.text,timestamp:$0.created,isOutgoing:true,state:.failed,randomID:$0.randomID) }
    }
    func load(quiet: Bool = false) async {
        guard !loading else { return }; loading = true; defer { loading = false }
        if !quiet { state = .loading }
        usesFixtures = !environment.isLiveVKSession
        let token = await environment.liveAPIGate.accessTokenIfLiveReady()
        let result = await environment.conversationRepository.fetchHistory(peerID:conversation.peerID,dataMode:environment.dataMode,
            capabilities:environment.capabilities,isNetworkReachable:environment.isNetworkReachable,accessToken:token)
        switch result {
        case .success(let items):
            serverOffset = items.count
            let acknowledged = Set(items.compactMap(\.randomID))
            pending.removeAll { acknowledged.contains($0.randomID) }; saveOutbox()
            var merged: [ChatMessage] = []
            if quiet, case .loaded(let old) = state { merged = old }
            var byID = Dictionary(merged.map { ($0.id,$0) },uniquingKeysWith:{_,b in b})
            for item in items + pendingMessages() { byID[item.id] = item }
            let sorted = byID.values.sorted { $0.timestamp < $1.timestamp }
            state = sorted.isEmpty ? .empty : .loaded(sorted)
        case .failure(let error):
            if quiet { sendNotice = error.localizedDescription }
            else if !pending.isEmpty { state = .loaded(pendingMessages()); sendNotice = error.localizedDescription }
            else { state = error == .offline ? .offline : .failed(error) }
        }
    }
    func loadOlder() async {
        guard !loadingOlder, !reachedStart, case .loaded(let current) = state else { return }
        loadingOlder = true; defer { loadingOlder = false }
        let token = await environment.liveAPIGate.accessTokenIfLiveReady()
        let result = await environment.conversationRepository.fetchHistory(peerID:conversation.peerID,dataMode:environment.dataMode,
            capabilities:environment.capabilities,isNetworkReachable:environment.isNetworkReachable,accessToken:token,offset:serverOffset)
        switch result {
        case .success(let page):
            serverOffset += page.count; reachedStart = page.count < 50
            var seen = Set(current.map(\.id)); let older = page.filter { seen.insert($0.id).inserted }
            state = .loaded(older + current)
        case .failure(let error): sendNotice = error.localizedDescription
        }
    }
    func send() async {
        let text = draft.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        let request = Pending(id:UUID(),randomID:Int64.random(in:1...Int64(Int32.max)),text:text,created:Date(),replyTo:replyingTo?.serverID)
        pending.append(request); saveOutbox()
        draft = ""; persistDraft(); replyingTo = nil
        await transmit(request)
    }
    func retry(_ message: ChatMessage) async {
        guard let request = pending.first(where:{$0.id == message.id}), !isSending else { return }
        await transmit(request)
    }
    private func upsert(_ message: ChatMessage) {
        var items: [ChatMessage] = []; if case .loaded(let existing) = state { items = existing }
        if let index = items.firstIndex(where:{$0.id == message.id}) { items[index] = message } else { items.append(message) }
        state = .loaded(items)
    }
    private func transmit(_ request: Pending) async {
        isSending = true; defer { isSending = false }
        var optimistic = ChatMessage(id:request.id,serverID:nil,peerID:conversation.peerID,text:request.text,timestamp:request.created,isOutgoing:true,state:.pending,randomID:request.randomID)
        upsert(optimistic); scrollToMessage = request.id
        let token = await environment.liveAPIGate.accessTokenIfLiveReady()
        let result = await environment.conversationRepository.enqueueOutgoing(peerID:conversation.peerID,text:request.text,dataMode:environment.dataMode,
            capabilities:environment.capabilities,accessToken:token,randomID:request.randomID,localID:request.id,replyTo:request.replyTo)
        guard environment.isAuthenticated, owner == String(VKIDAuthCoordinator.shared.userID ?? 0) else { return }
        switch result {
        case .success(let message):
            upsert(message)
            if message.state == .sent { pending.removeAll {$0.id == request.id}; saveOutbox(); sendNotice = nil }
            else { sendNotice = "Деморежим: сообщение сохранено локально и не отправлено в VK." }
        case .failure(let error): optimistic.state = .failed; upsert(optimistic); sendNotice = error.localizedDescription
        }
    }
    func poll() async {
        guard environment.isLiveVKSession,environment.capabilities.canUseLiveAPI(.conversation) else { return }
        do {
            let server = try await environment.catalog.request("messages.getLongPollServer",["lp_version":"3"])
            let raw = server["server"].string
            guard var url = URLComponents(string:raw.hasPrefix("https://") ? raw : "https://" + raw),url.scheme == "https",url.host != nil else { throw AppError.decoding }
            var timestamp = server["ts"].string.isEmpty ? "\(server["ts"].int)" : server["ts"].string
            while !Task.isCancelled,environment.isLiveVKSession {
                url.queryItems = [URLQueryItem(name:"act",value:"a_check"),.init(name:"key",value:server["key"].string),.init(name:"ts",value:timestamp),.init(name:"wait",value:"25"),.init(name:"mode",value:"2"),.init(name:"version",value:"3")]
                guard let address = url.url else { throw AppError.decoding }
                var request = URLRequest(url:address); request.timeoutInterval = 35
                let (data,response) = try await URLSession.shared.data(for:request)
                guard let response = response as? HTTPURLResponse,response.statusCode == 200 else { throw AppError.network("Соединение с VK прервано.") }
                let update = try JSONDecoder().decode(VKJSON.self,from:data)
                if update["failed"].int > 1 { return }
                timestamp = update["ts"].string.isEmpty ? "\(update["ts"].int)" : update["ts"].string
                if !update["updates"].items.isEmpty { await load(quiet:true) }
            }
        } catch is CancellationError { return }
        catch let error as URLError where error.code == .cancelled { return }
        catch { sendNotice = "Обновление сообщений: " + error.localizedDescription }
    }
    func edit(_ message: ChatMessage,text:String) async {
        guard let serverID = message.serverID,!text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return }
        if await environment.catalog.perform("messages.edit",["peer_id":"\(conversation.id)","message_id":"\(serverID)","message":text,"keep_forward_messages":"1"]) { await load(quiet:true) }
    }
    func delete(_ message: ChatMessage) async {
        if let serverID = message.serverID, environment.isLiveVKSession {
            guard await environment.catalog.perform("messages.delete", ["message_ids":"\(serverID)","delete_for_all":"0"]) else { return }
        }
        pending.removeAll {$0.id == message.id}; saveOutbox()
        if case .loaded(var items) = state { items.removeAll {$0.id == message.id}; state = items.isEmpty ? .empty : .loaded(items) }
    }
    func forward(_ message: ChatMessage, to peerID: Int64) async {
        guard let serverID = message.serverID, environment.isLiveVKSession else { sendNotice = "Пересылка доступна для сообщений VK."; return }
        let token = await environment.liveAPIGate.accessTokenIfLiveReady()
        let result = await environment.conversationRepository.enqueueOutgoing(peerID:PeerID(raw:peerID),text:"",dataMode:.live,
            capabilities:environment.capabilities,accessToken:token,forward:"\(serverID)")
        switch result { case .success: sendNotice = "Сообщение переслано"; case .failure(let error): sendNotice = error.localizedDescription }
    }
}
