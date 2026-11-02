import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// S10 — group chat (fixture peer ≥ 2_000_000_000).
struct GroupChatView: View {
    let chatID: Int64

    var body: some View {
        let conversation = Conversation(
            peerID: PeerID(raw: chatID),
            displayName: "Друзья",
            initials: "ДР",
            lastMessagePreview: "Групповой чат",
            lastUpdatedLabel: "—",
            unreadCount: 0,
            isOnline: false
        )
        ConversationView(conversation: conversation)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: AppRoute.chatInfo(chatID)) {
                        Image(systemName: "info.circle")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Информация о диалоге")
                }
            }
            .withAppRoutes()
    }
}

/// S11 — conversation info.
struct ChatInfoView: View {
    @Environment(AppEnvironment.self) private var env
    let peerID: Int64

    var body: some View {
        FixtureScreen(
            title: "Информация",
            screenID: "S11",
            resourceID:peerID,
            emptyTitle: "Unavailable",
            emptySymbol: "person.crop.circle",
            emptyDetails: "messages.getConversationsById when scoped.",
            loadValue: { ChatDetails(peerID:peerID,title:"Диалог",members:Array(CatalogFixtures.friends.prefix(3))) }
        ) { details in
            let id = details.peerID
            List {
                Section {
                    HStack {
                        Spacer()
                        VStack { VKAvatar(initials: id >= 2_000_000_000 ? "ГР" : "ЧТ", size: 72, tint: .indigo); Text(details.title).font(.headline) }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section("Действия") {
                    NavigationLink(value: AppRoute.chatSearch(id)) {
                        Label("Поиск по чату", systemImage: "magnifyingglass")
                    }
                    NavigationLink(value: AppRoute.chatAttachments(id)) {
                        Label("Вложения", systemImage: "paperclip")
                    }
                    Text("Настройки уведомлений доступны в официальном VK.").font(.footnote)
                }
                Section("Участники") {
                    ForEach(details.members) { friend in
                        Label(friend.displayName, systemImage: "person")
                    }
                }
            }
            .withAppRoutes()
        }
    }
}

/// S12 — attachment picker sheet content.
struct ChatAttachmentsView: View {
    let peerID: Int64
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var selection: PhotosPickerItem?
    @State private var showDocument = false
    @State private var data: Data?
    @State private var isPhoto = false
    @State private var busy = false
    @State private var notice: String?
    @State private var caption = ""
    @State private var attachment: String?
    @State private var randomID = Int64.random(in:1...Int64(Int32.max))
    var body: some View {
        Form {
            Section("Вложение") {
                PhotosPicker(selection:$selection,matching:.images) { Label("Выбрать фотографию",systemImage:"photo") }
                Button { showDocument = true } label: { Label("Выбрать документ",systemImage:"doc") }
                if let data { Text("Выбрано: \(ByteCountFormatter.string(fromByteCount:Int64(data.count),countStyle:.file))").font(.caption) }
            }.disabled(busy)
            TextField("Подпись",text:$caption,axis:.vertical)
            if let notice { Text(notice).font(.footnote) }
            Button(busy ? "Отправка…" : "Отправить") { Task { await send() } }
                .disabled(busy || data == nil || !env.isLiveVKSession)
            if !env.isLiveVKSession { Text("В деморежиме вложения не отправляются.").font(.footnote) }
        }
        .navigationTitle("Вложения")
        .fileImporter(isPresented:$showDocument,allowedContentTypes:[.data]) { result in
            do {
                let url = try result.get(); let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
                guard size <= 20_000_000 else { notice = "Максимальный размер — 20 МБ."; return }
                data = try Data(contentsOf:url); isPhoto = false; attachment = nil; randomID = Int64.random(in:1...Int64(Int32.max))
            } catch { notice = "Не удалось прочитать документ." }
        }
        .task(id:selection) {
            guard let selection else { return }
            do {
                guard let raw = try await selection.loadTransferable(type:Data.self), raw.count <= 20_000_000,
                      let image = UIImage(data:raw), let jpeg = image.jpegData(compressionQuality:0.8) else { notice = "Не удалось прочитать фото (лимит 20 МБ)."; return }
                data = jpeg; isPhoto = true; attachment = nil; randomID = Int64.random(in:1...Int64(Int32.max))
            } catch { notice = "Не удалось открыть фотографию." }
        }
    }
    private func send() async {
        guard let data, env.isLiveVKSession else { return }
        busy = true; defer { busy = false }
        do {
            let user = VKIDAuthCoordinator.shared.userID
            if attachment == nil {
                attachment = try await env.catalog.upload(data,photo:isPhoto,peerID:peerID)
            }
            guard env.isLiveVKSession, user == VKIDAuthCoordinator.shared.userID, let attachment else { throw AppError.notAuthenticated }
            let result = try await env.catalog.request("messages.send",["peer_id":"\(peerID)","random_id":"\(randomID)","attachment":attachment,"message":caption])
            guard result.int > 0 else { throw AppError.decoding }
            env.catalog.notice = "Вложение отправлено"; dismiss()
        } catch { notice = error.localizedDescription }
    }
}

extension VKCatalogService {
    func upload(_ data:Data,photo:Bool,peerID:Int64,wall:Bool = false) async throws -> String {
        guard data.count <= 20_000_000 else { throw AppError.network("Максимальный размер — 20 МБ.") }
        let server = try await request(wall ? "photos.getWallUploadServer" : (photo ? "photos.getMessagesUploadServer" : "docs.getMessagesUploadServer"),wall ? [:] : (photo ? ["peer_id":"\(peerID)"] : ["peer_id":"\(peerID)","type":"doc"]))
        guard let url = server["upload_url"].url else { throw AppError.decoding }
        let boundary = "VK-" + UUID().uuidString
        var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(photo ? "photo" : "file")\"; filename=\"\(photo ? "photo.jpg" : "document.bin")\"\r\nContent-Type: \(photo ? "image/jpeg" : "application/octet-stream")\r\n\r\n".utf8)
        body.append(data); body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        var req = URLRequest(url:url); req.httpMethod = "POST"; req.timeoutInterval = 60
        req.setValue("multipart/form-data; boundary=\(boundary)",forHTTPHeaderField:"Content-Type")
        let (response,http) = try await URLSession.shared.upload(for:req,from:body)
        guard let http = http as? HTTPURLResponse,(200...299).contains(http.statusCode) else { throw AppError.network("Загрузка вложения не завершена.") }
        let payload = try JSONDecoder().decode(VKJSON.self,from:response)
        if photo {
            var parameters = ["photo":payload["photo"].string,"server":"\(payload["server"].int)","hash":payload["hash"].string]
            if wall,let userID = VKIDAuthCoordinator.shared.userID { parameters["user_id"] = "\(userID)" }
            let saved = try await request(wall ? "photos.saveWallPhoto" : "photos.saveMessagesPhoto",parameters)
            guard let first = saved.items.first, first["id"].int != 0 else { throw AppError.decoding }
            return "photo\(first["owner_id"].int)_\(first["id"].int)"
        }
        guard !payload["file"].string.isEmpty else { throw AppError.decoding }
        let saved = try await request("docs.save",["file":payload["file"].string,"title":"Документ"])
        let doc = saved["doc"]
        guard doc["id"].int != 0 else { throw AppError.decoding }
        return "doc\(doc["owner_id"].int)_\(doc["id"].int)"
    }
}

/// S14 — in-chat search.
struct ChatSearchView: View {
    let peerID: Int64
    @State private var query = ""

    var body: some View {
        FixtureScreen(
            title: "Поиск в чате",
            screenID: "S14",
            resourceID:peerID,
            query:query,
            emptyTitle: "No matches",
            emptySymbol: "magnifyingglass",
            emptyDetails: "messages.search when available.",
            isEmpty: { $0.isEmpty },
            loadValue: { FixtureStore.embedded.messagesByPeer[peerID] ?? [] }
        ) { messages in
            let visible = query.isEmpty ? messages : messages.filter { $0.text.localizedCaseInsensitiveContains(query) }
            List(visible) { message in
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.text)
                    Text(message.timestamp.formatted())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .searchable(text: $query, prompt: "Поиск сообщений")
        }
    }
}
