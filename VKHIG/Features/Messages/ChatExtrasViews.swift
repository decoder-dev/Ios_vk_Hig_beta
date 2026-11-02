import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Observation
import CoreLocation

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

@MainActor
@Observable
final class ChatAdministrationModel {
    let peerID:Int64
    var title="Диалог"
    var members:[Friend]=[]
    var removable:Set<Int64>=[]
    var canEdit=false
    var canInvite=false
    var canPin=false
    var busy=false
    var loading=false
    var hasMore=false
    var error:String?
    var notice:String?
    private var offset=0
    private var selfID:Int64 {VKIDAuthCoordinator.shared.userID ?? 0}
    private let request:(String,[String:String]) async throws -> VKJSON
    init(peerID:Int64,request:((String,[String:String]) async throws -> VKJSON)?=nil) {
        self.peerID=peerID;self.request=request ?? {try await VKCatalogService.shared.request($0,$1)}
    }
    func load(reset:Bool=true) async {
        guard !loading else {return};loading=true;error=nil;defer {loading=false}
        do {
            if reset {
                canEdit=false;canInvite=false;canPin=false
                let response=try await request("messages.getConversationsById",["peer_ids":String(peerID)])
                guard let conversation=response.list.first else {throw AppError.decoding}
                let settings=conversation["chat_settings"]
                title=settings["title"].string.isEmpty ? "Диалог" : settings["title"].string
                offset=0;members=[];removable=[]
                if peerID <= 2_000_000_000 {hasMore=false;return}
                let permissions=settings["permissions"]
                let own=selfID != 0 && settings["owner_id"].int == selfID
                // Current-user role is read below, never inferred from the peer number.
                let first=try await request("messages.getConversationMembers",["peer_id":String(peerID),"extended":"1","count":"100","offset":"0","fields":"city,online"])
                let myself=first.list.first {$0["member_id"].int==selfID}
                let admin=myself?["is_admin"].flag == true || (selfID != 0 && settings["admin_ids"].items.contains {$0.int==selfID})
                let owner=own || myself?["is_owner"].flag == true
                func allowed(_ aclKey:String,_ policyKey:String) -> Bool {
                    let value=settings["acl"][aclKey]
                    if case .null=value {return owner || VKAction.allows(permissions[policyKey].string,isOwner:owner,isAdmin:admin)}
                    return value.flag
                }
                canEdit=allowed("can_change_info","change_info")
                canInvite=allowed("can_invite","invite")
                canPin=allowed("can_change_pin","change_pin")
                append(first)
            } else {
                let response=try await request("messages.getConversationMembers",["peer_id":String(peerID),"extended":"1","count":"100","offset":String(offset),"fields":"city,online"])
                append(response)
            }
        } catch {self.error=error.localizedDescription}
    }
    private func append(_ response:VKJSON) {
        let profiles=Dictionary(response["profiles"].items.map {($0["id"].int,VKCatalogService.friend($0))},uniquingKeysWith:{a,_ in a})
        var ids=Set(members.map(\.id))
        for item in response.list {
            let id=item["member_id"].int
            if item["can_kick"].flag && id != selfID {removable.insert(id)}
            if ids.insert(id).inserted {members.append(profiles[id] ?? Friend(id:id,displayName:"Участник \(id)",initials:"VK",isOnline:false,city:nil))}
        }
        offset+=response.list.count;hasMore=response.list.count==100
    }
    func rename(_ name:String) async -> Bool {
        guard canEdit else {error="VK не разрешил менять название беседы.";return false}
        guard !name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else {return false}
        return await execute("messages.editChat",["title":name])
    }
    func add(_ friend:Friend) async -> Bool {
        guard canInvite else {error="VK не разрешил приглашать участников.";return false}
        return await execute("messages.addChatUser",["user_id":String(friend.id)])
    }
    func remove(_ friend:Friend) async -> Bool {
        guard removable.contains(friend.id) else {error="VK не разрешил исключать этого участника.";return false}
        return await execute("messages.removeChatUser",["member_id":String(friend.id)])
    }
    func leave() async -> Bool {
        guard selfID != 0 else {return false}
        return await execute("messages.removeChatUser",["member_id":String(selfID)])
    }
    func unpin() async {
        guard canPin,!busy else {return};busy=true;error=nil;defer {busy=false}
        do {_ = try await request("messages.unpin",["peer_id":String(peerID)]);notice="Закрепление снято"} catch {self.error=error.localizedDescription}
    }
    private func execute(_ method:String,_ values:[String:String]) async -> Bool {
        guard !busy else {return false};busy=true;error=nil;defer {busy=false}
        do {
            let action=try VKAction.chat(method,peerID:peerID,values:values)
            let response=try await request(action.method,action.parameters)
            guard response.int==1 else {throw AppError.decoding}
            notice="Изменения подтверждены VK"
            await load();return true
        } catch {self.error=error.localizedDescription;return false}
    }
}
struct ChatInfoView:View {
    let peerID:Int64
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var model:ChatAdministrationModel?
    @State private var renamed=""
    @State private var adding=false
    @State private var removing:Friend?
    @State private var leaving=false
    var body:some View {
        Group {if let model {form(model)} else {ProgressView()}}
            .navigationTitle("Информация о беседе")
            .task {
                guard model==nil else {return}
                let vm=ChatAdministrationModel(peerID:peerID);model=vm
                if env.isLiveVKSession {await vm.load();renamed=vm.title}
                else {vm.title="Демонстрационная беседа";vm.members=Array(CatalogFixtures.friends.prefix(3))}
            }
            .sheet(isPresented:$adding) {VKUserPicker {friend in await model?.add(friend) == true}}
            .confirmationDialog("Исключить участника?",isPresented:Binding(get:{removing != nil},set:{if !$0 {removing=nil}})) {
                Button("Исключить",role:.destructive) {if let friend=removing {Task {_ = await model?.remove(friend)}};removing=nil}
            }
            .confirmationDialog("Выйти из беседы?",isPresented:$leaving) {Button("Выйти",role:.destructive) {Task {if await model?.leave() == true {dismiss()}}}}
    }
    private func form(_ model:ChatAdministrationModel) -> some View {
        Form {
            if !env.isLiveVKSession {FixtureBanner()}
            Section {
                Text(model.title).font(.headline)
                if model.loading || model.busy {ProgressView()}
                if let error=model.error {Text(error).foregroundStyle(.red);Button("Повторить загрузку") {Task {await model.load()}}}
                if let notice=model.notice {Text(notice).font(.footnote)}
            }
            if model.canEdit {
                Section("Название беседы") {TextField("Название",text:$renamed);Button("Сохранить название") {Task {_ = await model.rename(renamed)}}.disabled(model.busy)}
            }
            Section("Действия") {
                NavigationLink("Поиск по переписке",value:AppRoute.chatSearch(peerID))
                NavigationLink("Отправить вложение",value:AppRoute.chatAttachments(peerID))
                if model.canInvite {Button("Добавить участника") {adding=true}}
                if model.canPin {Button("Снять закреплённое сообщение") {Task {await model.unpin()}}.disabled(model.busy)}
            }
            Section("Участники") {
                ForEach(model.members) {person in
                    HStack {
                        NavigationLink(person.displayName,value:AppRoute.userProfile(person.id))
                        if model.removable.contains(person.id) {Button("Исключить",role:.destructive) {removing=person}.disabled(model.busy)}
                    }
                }
                if model.hasMore {Button("Загрузить ещё участников") {Task {await model.load(reset:false)}}.disabled(model.loading)}
            }
            if env.isLiveVKSession && peerID > 2_000_000_000 {Button("Выйти из беседы",role:.destructive) {leaving=true}.disabled(model.busy)}
        }.withAppRoutes()
    }
}

struct SelectedCoordinate:Equatable {let latitude:Double;let longitude:Double}
@MainActor
@Observable
final class CurrentLocationRequest:NSObject,CLLocationManagerDelegate {
    var value:SelectedCoordinate?
    var error:String?
    var loading=false
    @ObservationIgnored private let manager=CLLocationManager()
    override init() {super.init();manager.delegate=self;manager.desiredAccuracy=kCLLocationAccuracyHundredMeters}
    func request() {
        error=nil;loading=true
        switch manager.authorizationStatus {
        case .notDetermined:manager.requestWhenInUseAuthorization()
        case .authorizedAlways,.authorizedWhenInUse:manager.requestLocation()
        default:loading=false;error="Разрешите геопозицию в настройках iOS."
        }
    }
    func locationManagerDidChangeAuthorization(_ manager:CLLocationManager) {
        if loading && (manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways) {manager.requestLocation()}
        else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {loading=false;error="Доступ к геопозиции запрещён."}
    }
    func locationManager(_ manager:CLLocationManager,didUpdateLocations locations:[CLLocation]) {
        loading=false
        guard let coordinate=locations.last?.coordinate,CLLocationCoordinate2DIsValid(coordinate) else {error="Не удалось определить местоположение.";return}
        value=SelectedCoordinate(latitude:coordinate.latitude,longitude:coordinate.longitude)
    }
    func locationManager(_ manager:CLLocationManager,didFailWithError error:Error) {loading=false;self.error=error.localizedDescription}
}
struct CameraCapture:UIViewControllerRepresentable {
    let select:(UIImage?)->Void
    func makeCoordinator() -> Coordinator {Coordinator(select:select)}
    func makeUIViewController(context:Context) -> UIImagePickerController {
        let picker=UIImagePickerController();picker.sourceType = .camera;picker.delegate=context.coordinator;return picker
    }
    func updateUIViewController(_ controller:UIImagePickerController,context:Context) {}
    final class Coordinator:NSObject,UIImagePickerControllerDelegate,UINavigationControllerDelegate {
        let select:(UIImage?)->Void
        init(select:@escaping (UIImage?)->Void) {self.select=select}
        func imagePickerController(_ picker:UIImagePickerController,didFinishPickingMediaWithInfo info:[UIImagePickerController.InfoKey:Any]) {select(info[.originalImage] as? UIImage);picker.dismiss(animated:true)}
        func imagePickerControllerDidCancel(_ picker:UIImagePickerController) {select(nil);picker.dismiss(animated:true)}
    }
}
struct ChatAttachmentsView:View {
    let peerID:Int64
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var selection:PhotosPickerItem?
    @State private var showDocument=false
    @State private var camera=false
    @State private var importKind="doc"
    @State private var kind="doc"
    @State private var filename="Документ"
    @State private var data:Data?
    @State private var selectingMedia=false
    @State private var sendTask:Task<Void,Never>?
    @State private var busy=false
    @State private var notice:String?
    @State private var caption=""
    @State private var attachment:String?
    @State private var randomID=Int64.random(in:1...Int64(Int32.max))
    @State private var location=CurrentLocationRequest()
    var body:some View {
        Form {
            Section("Вложение") {
                PhotosPicker(selection:$selection,matching:.images) {Label("Фотография из медиатеки",systemImage:"photo")}
                if UIImagePickerController.isSourceTypeAvailable(.camera) {Button("Снять фотографию",systemImage:"camera") {camera=true}}
                Button("Документ",systemImage:"doc") {importKind="doc";showDocument=true}
                Button("Видеофайл",systemImage:"video") {importKind="video";showDocument=true}
                Button("Голосовой файл OGG",systemImage:"waveform") {importKind="audio_message";showDocument=true}
                if let data {Text("\(filename) · \(ByteCountFormatter.string(fromByteCount:Int64(data.count),countStyle:.file))").font(.caption);Button("Убрать файл",role:.destructive) {self.data=nil;attachment=nil}}
            }.disabled(busy)
            Section("Геопозиция") {
                Button("Определить местоположение",systemImage:"location") {location.request()}.disabled(location.loading || busy || !env.isLiveVKSession)
                if location.loading {ProgressView()}
                if let value=location.value {Text(String(format:"%.4f, %.4f",value.latitude,value.longitude));Button("Убрать геопозицию",role:.destructive) {location.value=nil}}
                if let error=location.error {Text(error).font(.caption).foregroundStyle(.red);Link("Настройки iOS",destination:URL(string:UIApplication.openSettingsURLString)!)}
            }
            TextField("Подпись",text:$caption,axis:.vertical).disabled(busy)
            if let notice {Text(notice).foregroundStyle(.red)}
            Button(busy ? "Отправка…" : "Отправить") {sendTask=Task {await send()}}.disabled(busy || selectingMedia || location.loading || (data==nil && location.value==nil) || !env.isLiveVKSession)
            if !env.isLiveVKSession {Text("В деморежиме вложения не отправляются.").font(.footnote)}
        }.navigationTitle("Вложения")
        .onDisappear {sendTask?.cancel()}
        .onChange(of:caption) {_,_ in if !busy {randomID=Int64.random(in:1...Int64(Int32.max))}}
        .onChange(of:location.value) {_,_ in if !busy {randomID=Int64.random(in:1...Int64(Int32.max))}}
        .sheet(isPresented:$camera) {CameraCapture {image in camera=false;if let image {selectPhoto(image)}}}
        .fileImporter(isPresented:$showDocument,allowedContentTypes:importKind=="video" ? [.movie,.video] : [.data]) {result in
            do {
                let url=try result.get(),scope=url.startAccessingSecurityScopedResource();defer {if scope {url.stopAccessingSecurityScopedResource()}}
                let limit=importKind=="video" ? 100_000_000 : 20_000_000
                guard (try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0)<=limit else {notice="Файл слишком большой: до 100 МБ для видео и 20 МБ для остальных файлов.";return}
                if importKind=="audio_message" && url.pathExtension.lowercased() != "ogg" {notice="Для голосового сообщения выберите файл OGG/Opus. Другой аудиофайл можно отправить документом.";return}
                data=try Data(contentsOf:url);kind=importKind;filename=url.lastPathComponent;attachment=nil;notice=nil;randomID=Int64.random(in:1...Int64(Int32.max))
            } catch {notice=error.localizedDescription}
        }
        .task(id:selection) {
            guard let selection else {return}
            selectingMedia=true;defer {selectingMedia=false}
            do {
                guard let raw=try await selection.loadTransferable(type:Data.self),raw.count<=20_000_000,let image=UIImage(data:raw) else {notice="Фото недоступно или больше 20 МБ.";return}
                selectPhoto(image)
            } catch {notice=error.localizedDescription}
        }
    }
    private func selectPhoto(_ image:UIImage) {
        guard let jpeg=image.jpegData(compressionQuality:0.8),jpeg.count<=20_000_000 else {notice="Фото больше 20 МБ.";return}
        data=jpeg;kind="photo";filename="Фотография.jpg";attachment=nil;notice=nil;randomID=Int64.random(in:1...Int64(Int32.max))
    }
    private func send() async {
        guard env.isLiveVKSession,!busy else {return};busy=true;notice=nil;defer {busy=false}
        let owner=VKIDAuthCoordinator.shared.userID
        let coordinate=location.value,message=caption
        do {
            if let data,attachment==nil {
                if kind=="video" {attachment=try await env.catalog.uploadVideo(data,name:filename)}
                else {attachment=try await env.catalog.upload(data,photo:kind=="photo",peerID:peerID,documentType:kind=="audio_message" ? "audio_message" : "doc",title:filename)}
            }
            try Task.checkCancellation()
            guard env.isLiveVKSession,owner==VKIDAuthCoordinator.shared.userID else {throw AppError.notAuthenticated}
            var params=["peer_id":String(peerID),"random_id":String(randomID),"message":message]
            if let attachment {params["attachment"]=attachment}
            if let value=coordinate {params["lat"]=String(value.latitude);params["long"]=String(value.longitude)}
            let response=try await env.catalog.request("messages.send",params)
            guard response.int>0 else {throw AppError.decoding}
            env.catalog.notice="Вложение отправлено";dismiss()
        } catch {notice=error.localizedDescription}
    }
}

extension VKCatalogService {
    func upload(_ data:Data,photo:Bool,peerID:Int64,wall:Bool = false,documentType:String = "doc",title:String = "Документ") async throws -> String {
        let owner=VKIDAuthCoordinator.shared.userID
        guard data.count <= 20_000_000 else { throw AppError.network("Максимальный размер — 20 МБ.") }
        let server = try await request(wall ? "photos.getWallUploadServer" : (photo ? "photos.getMessagesUploadServer" : "docs.getMessagesUploadServer"),wall ? [:] : (photo ? ["peer_id":"\(peerID)"] : ["peer_id":"\(peerID)","type":documentType]))
        guard let url = server["upload_url"].url else { throw AppError.decoding }
        let boundary = "VK-" + UUID().uuidString
        let filename=photo ? "photo.jpg" : documentType=="audio_message" ? "voice.ogg" : VKUploadFile.safeName(title)
        let mime=photo ? "image/jpeg" : documentType=="audio_message" ? "audio/ogg" : "application/octet-stream"
        var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(photo ? "photo" : "file")\"; filename=\"\(filename)\"\r\nContent-Type: \(mime)\r\n\r\n".utf8)
        body.append(data); body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        var req = URLRequest(url:url); req.httpMethod = "POST"; req.timeoutInterval = 60
        req.setValue("multipart/form-data; boundary=\(boundary)",forHTTPHeaderField:"Content-Type")
        let (response,http) = try await URLSession.shared.upload(for:req,from:body)
        guard let http = http as? HTTPURLResponse,(200...299).contains(http.statusCode) else { throw AppError.network("Загрузка вложения не завершена.") }
        let payload = try JSONDecoder().decode(VKJSON.self,from:response)
        try Task.checkCancellation()
        guard owner==VKIDAuthCoordinator.shared.userID else {throw AppError.notAuthenticated}
        if photo {
            var parameters = ["photo":payload["photo"].string,"server":"\(payload["server"].int)","hash":payload["hash"].string]
            if wall,let userID = VKIDAuthCoordinator.shared.userID { parameters["user_id"] = "\(userID)" }
            let saved = try await request(wall ? "photos.saveWallPhoto" : "photos.saveMessagesPhoto",parameters)
            guard let first = saved.items.first, first["id"].int != 0 else { throw AppError.decoding }
            return "photo\(first["owner_id"].int)_\(first["id"].int)"
        }
        guard !payload["file"].string.isEmpty else { throw AppError.decoding }
        let saved = try await request("docs.save",["file":payload["file"].string,"title":title])
        let doc = saved[documentType]
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

@MainActor
@Observable
final class RecipientPickerModel {
    var peers:[Conversation]=[]
    var loading=false
    var hasMore=true
    var error:String?
    private var offset=0
    private var generation=UUID()
    private var seen:Set<Int64>=[]
    private let request:(String,[String:String]) async throws -> VKJSON
    init(request:((String,[String:String]) async throws -> VKJSON)?=nil) {
        self.request=request ?? {try await VKCatalogService.shared.request($0,$1)}
    }
    func load(query:String="",reset:Bool=true) async {
        if !reset && (loading || !hasMore) {return}
        if reset {generation=UUID();offset=0;seen=[];peers=[];hasMore=true}
        let ticket=generation;loading=true;error=nil
        defer {if ticket==generation {loading=false}}
        do {
            let text=query.trimmingCharacters(in:.whitespacesAndNewlines)
            if !text.isEmpty {try await Task.sleep(for:.milliseconds(300))}
            let method=text.isEmpty ? "messages.getConversations" : "messages.searchConversations"
            var parameters=["extended":"1","count":"100","fields":"photo_100"]
            if text.isEmpty {parameters["offset"]=String(offset)} else {parameters["q"]=text;parameters["count"]="200"}
            let response=try await request(method,parameters)
            try Task.checkCancellation();guard ticket==generation else {return}
            let names=Dictionary(response["profiles"].items.map {($0["id"].int,VKCatalogService.name($0))},uniquingKeysWith:{a,_ in a})
            let groups=Dictionary(response["groups"].items.map {(-$0["id"].int,$0["name"].string)},uniquingKeysWith:{a,_ in a})
            let page=response.list.compactMap {item -> Conversation? in
                let conversation=item["conversation"]["peer"]["id"].int != 0 ? item["conversation"] : item
                let id=conversation["peer"]["id"].int
                guard id != 0 else {return nil}
                let chatTitle=conversation["chat_settings"]["title"].string
                let name=chatTitle.isEmpty ? names[id] ?? groups[id] ?? "Диалог \(id)" : chatTitle
                return Conversation(peerID:PeerID(raw:id),displayName:name,initials:VKCatalogService.initials(name),lastMessagePreview:item["last_message"]["text"].string,lastUpdatedLabel:"",unreadCount:Int(conversation["unread_count"].int),isOnline:false)
            }
            offset+=response.list.count
            peers+=page.filter {seen.insert($0.id).inserted}
            hasMore=text.isEmpty && response.list.count==100
            if !text.isEmpty && response.list.count==200 {error="Показаны первые 200 совпадений. Уточните поиск."}
        } catch is CancellationError {} catch {if ticket==generation {self.error=error.localizedDescription}}
    }
}
struct RecipientPickerView:View {
    let select:(Conversation) async -> Bool
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var model=RecipientPickerModel()
    @State private var query=""
    @State private var selecting=false
    @State private var sendError:String?
    var body:some View {
        NavigationStack {
            List {
                if !env.isLiveVKSession {Text("Для пересылки войдите в VK ID.")}
                ForEach(model.peers) {peer in
                    Button(peer.displayName) {Task {
                        selecting=true;defer {selecting=false}
                        if await select(peer) {dismiss()} else {sendError="Пересылка не выполнена. Проверьте права и повторите."}
                    }}.disabled(selecting)
                }
                if model.loading {ProgressView()}
                if let error=sendError ?? model.error {Text(error).foregroundStyle(.red);Button("Повторить загрузку") {Task {await model.load(query:query)}}}
                if model.hasMore && !model.loading {Button("Загрузить ещё диалоги") {Task {await model.load(query:query,reset:false)}}}
            }.navigationTitle("Получатель").searchable(text:$query,prompt:"Найти диалог")
            .toolbar {ToolbarItem(placement:.cancellationAction) {Button("Отмена") {dismiss()}}}
            .task(id:query) {if env.isLiveVKSession {await model.load(query:query)}}
        }
    }
}

struct VKUserPicker:View {
    let select:(Friend) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var people:[Friend]=[]
    @State private var query=""
    @State private var error:String?
    @State private var busy=false
    @State private var offset=0
    @State private var more=true
    @State private var requestID=UUID()
    var body:some View {
        NavigationStack {
            List {
                ForEach(people) {person in Button(person.displayName) {Task {
                    busy=true;defer {busy=false}
                    if await select(person) {dismiss()} else {error="Не удалось выполнить действие. Проверьте права доступа."}
                }}.disabled(busy)}
                if busy {ProgressView()}
                if let error {Text(error).foregroundStyle(.red);Button("Повторить") {Task {await load(reset:true)}}}
                if more && !busy {Button("Загрузить ещё") {Task {await load(reset:false)}}}
            }.navigationTitle("Выбрать пользователя").searchable(text:$query,prompt:"Имя или фамилия")
            .toolbar {ToolbarItem(placement:.cancellationAction) {Button("Отмена") {dismiss()}}}
            .task(id:query) {await load(reset:true)}
        }
    }
    private func load(reset:Bool) async {
        if !reset && busy {return}
        if reset {requestID=UUID();offset=0;people=[];more=true}
        let ticket=requestID
        busy=true;error=nil;defer {if ticket==requestID {busy=false}}
        let text=query.trimmingCharacters(in:.whitespacesAndNewlines)
        do {
            try await Task.sleep(for:.milliseconds(300));try Task.checkCancellation()
            var params=["count":"30","offset":String(offset),"fields":"city,online"]
            if !text.isEmpty {params["q"]=text}
            let response=try await VKCatalogService.shared.request(text.isEmpty ? "friends.get" : "users.search",params)
            try Task.checkCancellation();guard ticket==requestID else {return}
            let page=response.list.map(VKCatalogService.friend)
            var ids=Set(people.map(\.id));people+=page.filter {ids.insert($0.id).inserted};offset+=page.count;more=page.count==30
        } catch is CancellationError {} catch {if ticket==requestID {self.error=error.localizedDescription}}
    }
}

extension VKCatalogService {
    func uploadVideo(_ data:Data,name:String) async throws -> String {
        guard data.count<=100_000_000 else {throw AppError.network("Видео больше 100 МБ.")}
        let owner=VKIDAuthCoordinator.shared.userID
        let saved=try await request("video.save",["name":name,"is_private":"1","wallpost":"0"])
        guard let url=saved["upload_url"].url else {throw AppError.decoding}
        let boundary="VKVideo-"+UUID().uuidString
        let filename=VKUploadFile.safeName(name)
        var body=Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"video_file\"; filename=\"\(filename)\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8)
        body.append(data);body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        var request=URLRequest(url:url);request.httpMethod="POST";request.timeoutInterval=180
        request.setValue("multipart/form-data; boundary=\(boundary)",forHTTPHeaderField:"Content-Type")
        let (payload,response)=try await URLSession.shared.upload(for:request,from:body)
        guard let response=response as? HTTPURLResponse,(200...299).contains(response.statusCode),owner==VKIDAuthCoordinator.shared.userID else {throw AppError.network("Загрузка видео не завершена.")}
        let result=try JSONDecoder().decode(VKJSON.self,from:payload)
        try Task.checkCancellation()
        switch result["error"] {
        case .null, .number(0), .bool(false): break
        default: throw AppError.network("VK не принял видео.")
        }
        let id=result["video_id"].int != 0 ? result["video_id"].int : saved["video_id"].int
        let ownerID=result["owner_id"].int != 0 ? result["owner_id"].int : saved["owner_id"].int
        guard id>0,ownerID != 0 else {throw AppError.decoding}
        let key=saved["access_key"].string
        return "video\(ownerID)_\(id)"+(key.isEmpty ? "" : "_"+key)
    }
}
