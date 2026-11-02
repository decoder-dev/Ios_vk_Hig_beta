import SwiftUI

/// S40 — bookmarks / saved.
struct BookmarksView: View {
    var body: some View {
        FixtureScreen(
            title: "Сохранённое",
            screenID: "S40",
            emptyTitle: "Nothing saved",
            emptySymbol: "bookmark",
            emptyDetails: "fave.get when scoped.",
            isEmpty: { $0.isEmpty },
            loadValue: { CatalogFixtures.bookmarks }
        ) { items in
            List(items) { item in
                if let url=item.targetURL {Link(destination:url) {Label(item.title,systemImage:item.symbol)}}
                else {Label {
                    VStack(alignment: .leading) {
                        Text(item.title)
                        Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: item.symbol)
                }}
            }
        }
    }
}

/// S41 — stories viewer stub.
struct StoryViewerView: View {
    let storyID: Int64
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(colors: [.purple.opacity(0.6), .blue.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack {
                HStack {
                    let story = CatalogFixtures.stories.first(where: { $0.id == storyID })
                    VKAvatar(initials: story?.initials ?? "?", size: 36)
                    Text(story?.author ?? "Story")
                        .foregroundStyle(.white)
                        .font(.headline)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding()
                Spacer()
                Text("S41 · Stories only when official API exists.\nFixture full-bleed shell — not a live story.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding()
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
}

struct IncomingCallView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openURL) private var openURL
    @State private var link=""
    @State private var callID:String?
    @State private var busy=false
    @State private var error:String?
    @State private var confirmFinish=false
    private var joinURL:URL? {
        guard let url=URL(string:link.trimmingCharacters(in:.whitespacesAndNewlines)),url.scheme=="https",let host=url.host?.lowercased(),["vk.com","vk.ru","vk.me","calls.vk.com"].contains(host) else {return nil}
        return url
    }
    var body:some View {
        Form {
            Section("Конференция VK") {
                Button("Создать звонок",systemImage:"video.badge.plus") {Task {await create()}}.disabled(busy || !env.isLiveVKSession || callID != nil)
                TextField("Ссылка на звонок VK",text:$link).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                if let joinURL {
                    Button("Присоединиться",systemImage:"phone.fill") {openURL(joinURL)}
                    ShareLink(item:joinURL) {Label("Поделиться приглашением",systemImage:"square.and.arrow.up")}
                }
                if callID != nil {Button("Завершить для всех",role:.destructive) {confirmFinish=true}.disabled(busy)}
                if busy {ProgressView()}
                if let error {Text(error).foregroundStyle(.red)}
            }
            Section {
                Text("Создание и завершение конференции выполняет VK API. Аудио и видео открываются в официальном клиенте VK или браузере. Приём входящих звонков внутри приложения требует отдельного SDK и доступа VK.").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("Звонки")
        .confirmationDialog("Завершить звонок для всех участников?",isPresented:$confirmFinish) {Button("Завершить",role:.destructive) {Task {await finish()}}}
    }
    private func create() async {
        guard !busy else {return};busy=true;error=nil;defer {busy=false}
        do {
            let response=try await env.catalog.request("calls.start")
            guard let url=response["join_link"].url else {throw AppError.decoding}
            link=url.absoluteString
            let id=response["call_id"].string;callID=id.isEmpty ? nil : id
            guard joinURL != nil else {link="";throw AppError.decoding}
        } catch {self.error=error.localizedDescription}
    }
    private func finish() async {
        guard let callID,!busy else {return};busy=true;error=nil;defer {busy=false}
        do {
            let response=try await env.catalog.request("calls.forceFinish",["call_id":callID])
            guard response.int == 1 else {throw AppError.decoding}
            self.callID=nil;link=""
        } catch {self.error=error.localizedDescription}
    }
}

/// S43 — error / offline demo.
struct ErrorDemoView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var mode = "error"

    var body: some View {
        VStack {
            Picker("State", selection: $mode) {
                Text("Error").tag("error")
                Text("Offline").tag("offline")
                Text("Empty").tag("empty")
                Text("Permission").tag("permission")
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                switch mode {
                case "offline":
                    VKErrorState(message: "S43 · Offline", symbol: "wifi.slash", onRetry: {})
                case "empty":
                    VKEmptyState(symbol: "tray", title: "S43 · Empty", details: "Nothing here yet.")
                case "permission":
                    VKUnavailableState(title: "S43 · Permission", details: "Feature needs an official scope grant.")
                default:
                    VKErrorState(message: "S43 · Something went wrong", onRetry: {})
                }
            }
            Toggle("Simulate offline for app", isOn: Binding(
                get: { !env.isNetworkReachable },
                set: { env.isNetworkReachable = !$0 }
            ))
            .padding()
        }
        .navigationTitle("Состояния")
    }
}

/// S44 — confirmation / context menu demo.
struct ActionsDemoView: View {
    @State private var showConfirm = false
    @State private var showSheet = false
    @State private var result = "—"

    var body: some View {
        List {
            Section("S44") {
                Button("confirmationDialog") { showConfirm = true }
                Button("sheet") { showSheet = true }
                Text("Long-press row for contextMenu")
                    .contextMenu {
                        Button("Copy") { result = "Copy" }
                        Button("Share") { result = "Share" }
                        Button("Delete", role: .destructive) { result = "Delete" }
                    }
            }
            Section("Last action") {
                Text(result)
            }
        }
        .navigationTitle("Действия")
        .confirmationDialog("Выберите действие", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Primary") { result = "Primary" }
            Button("Destructive", role: .destructive) { result = "Destructive" }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showSheet) {
            NavigationStack {
                Text("System sheet content")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showSheet = false }
                        }
                    }
                    .navigationTitle("Sheet")
            }
            .presentationDetents([.medium])
        }
    }
}
