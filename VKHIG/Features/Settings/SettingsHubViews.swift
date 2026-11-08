import SwiftUI

/// S34 — settings hub, board 02 / 04: profile card, accent glyph rows with trailing values, search.
struct SettingsHubView: View {
    @Environment(AppEnvironment.self) private var env
    @AppStorage("vkhig.appearance.mode") private var appearance = "system"
    @State private var query = ""
    @State private var profile: UserProfile?

    private struct Entry: Identifiable {
        let title: String
        let symbol: String
        var value: String? = nil
        let route: AppRoute?
        var id: String { title }
    }

    private var appearanceLabel: String {
        switch appearance {
        case "light": return "Светлая"
        case "dark": return "Тёмная"
        default: return "Системная"
        }
    }

    private var cacheLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(URLCache.shared.currentDiskUsage + URLCache.shared.currentMemoryUsage), countStyle: .file)
    }

    private var accountEntries: [Entry] {[
        Entry(title: "Аккаунт и безопасность", symbol: "person.crop.circle", value: env.isLiveVKSession ? "VK ID" : "Демо", route: .accountSettings),
        Entry(title: "Конфиденциальность", symbol: "lock.shield", route: .privacySettings),
        Entry(title: "Уведомления", symbol: "bell", value: "Выкл.", route: .notificationSettings)
    ]}

    private var appEntries: [Entry] {[
        Entry(title: "Оформление", symbol: "circle.lefthalf.filled", value: appearanceLabel, route: .appearanceSettings),
        Entry(title: "Данные и память", symbol: "externaldrive", value: cacheLabel, route: .storageSettings)
    ]}

    private func matches(_ title: String) -> Bool {
        query.isEmpty || title.localizedCaseInsensitiveContains(query)
    }

    var body: some View {
        List {
            if query.isEmpty {
                Section {
                    NavigationLink(value: AppRoute.editProfile) {
                        HStack(spacing: VKStyle.Spacing.sm) {
                            VKAvatar(initials: profile?.initials ?? "VK", url: profile?.avatarURL, size: 60)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile?.displayName ?? (env.isLiveVKSession ? "Аккаунт VK" : "Демо-пользователь"))
                                    .font(.title3.weight(.semibold))
                                    .lineLimit(1)
                                Text("Мой профиль")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            let account = accountEntries.filter { matches($0.title) }
            let showsSwitcher = matches("Аккаунты")
            if !account.isEmpty || showsSwitcher {
                Section {
                    ForEach(account) { entry($0) }
                    if showsSwitcher {
                        NavigationLink {
                            AccountSwitcherView()
                        } label: {
                            VKIconRow(title: "Аккаунты", symbol: "person.2")
                        }
                    }
                }
            }

            let app = appEntries.filter { matches($0.title) }
            if !app.isEmpty {
                Section { ForEach(app) { entry($0) } }
            }

            if matches("Проверка доступа VK") {
                Section {
                    NavigationLink {
                        VKConnectionCheckView()
                    } label: {
                        VKIconRow(title: "Проверка доступа VK", symbol: "checkmark.shield")
                    }
                }
            }

            #if DEBUG
            if query.isEmpty {
                Section("Разработка") {
                    NavigationLink(value: AppRoute.onboarding) {
                        VKIconRow(title: "Онбординг", symbol: "sparkles")
                    }
                    LabeledContent("VK client id") {
                        Text(AppSecrets.hasVKIDCredentials ? "Настроен" : "Не настроен")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            #endif
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: "Поиск в настройках")
        .navigationTitle("Настройки")
        .withAppRoutes()
        .task {
            guard profile == nil else { return }
            let token = await env.tokenProvider.accessToken()
            if case .success(let value) = await env.profileRepository.fetchProfile(
                dataMode: env.dataMode,
                capabilities: env.capabilities,
                isNetworkReachable: env.isNetworkReachable,
                accessToken: token
            ) {
                profile = value
            }
        }
    }

    @ViewBuilder
    private func entry(_ entry: Entry) -> some View {
        if let route = entry.route {
            NavigationLink(value: route) {
                VKIconRow(title: entry.title, symbol: entry.symbol, value: entry.value)
            }
        }
    }
}

struct NotificationSettingsView:View {
    var body:some View {
        ContentUnavailableView("Push-уведомления отключены",systemImage:"bell.slash",description:Text("Эта версия работает без push-уведомлений."))
            .navigationTitle("Уведомления")
    }
}

/// S36
struct PrivacySettingsView: View {
    var body: some View {
        Form {
            Section { Text("Настройки приватности аккаунта изменяются в официальном VK. Приложение не имитирует скрытый онлайн или закрытие профиля.") }
            Link("Открыть настройки приватности VK",destination:URL(string:"https://vk.com/settings?act=privacy")!)
        }.navigationTitle("Конфиденциальность")
    }
}

/// S37
struct AppearanceSettingsView: View {
    @AppStorage("vkhig.appearance.mode") private var mode = "system"

    var body: some View {
        Form {
            Section("S37") {
                Picker("Тема", selection: $mode) {
                    Text("Системная").tag("system")
                    Text("Светлая").tag("light")
                    Text("Тёмная").tag("dark")
                }
            }
            Section {
                Text("Размер текста и уменьшение движения учитывают настройки iOS.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Оформление")
    }
}

/// S38
struct StorageSettingsView: View {
    @State private var cleared = false
    @AppStorage("vkhig.cellular.download") private var cellular = false

    var body: some View {
        Form {
            Section("S38") {
                LabeledContent("Кэш изображений",value:ByteCountFormatter.string(fromByteCount:Int64(URLCache.shared.currentDiskUsage + URLCache.shared.currentMemoryUsage),countStyle:.file))
                Toggle("Загрузка по сотовой сети", isOn: $cellular)
                Button("Очистить кэш", role: .destructive) {
                    URLCache.shared.removeAllCachedResponses()
                    cleared = true
                }
            }
            if cleared {
                Section {
                    Text("Кэш изображений очищен. Сообщения и черновики сохранены.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Данные и память")
    }
}

/// S39
struct AccountSettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var confirmLogout = false

    var body: some View {
        Form {
            Section("Сессия") {
                NavigationLink("Проверить доступ к VK") {VKConnectionCheckView()}
                LabeledContent("Режим") {
                    Text(env.isLiveVKSession ? (VKSession.activeAccount != nil ? "Аккаунт VK" : "VK ID") : "Демоверсия")
                }
                LabeledContent("VK ID client") {
                    Text(AppSecrets.hasVKIDCredentials ? "Настроен" : "Не настроен")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Redirect URI", value: AppSecrets.vkRedirectURI)
                LabeledContent("Выданные права",value:env.capabilities.grantedScopes.sorted().joined(separator:", "))
                LabeledContent("Секретный ключ") {
                    Text("Не используется (PKCE)")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Button("Выйти", role: .destructive) {
                    confirmLogout = true
                }
            }
        }
        .navigationTitle("Аккаунт")
        .confirmationDialog("Выйти из оболочки?", isPresented: $confirmLogout) {
            Button("Выйти", role: .destructive) { env.signOut() }
            Button("Отмена", role: .cancel) {}
        }
    }
}

struct VKConnectionCheckView:View {
    @Environment(AppEnvironment.self) private var env
    @State private var running=false
    @State private var results:[String]=[]
    @State private var checkedAt:Date?
    var body:some View {
        List {
            Section {
                Text("Проверка читает данные аккаунта и доступность разделов. Записи и сообщения не отправляются.").font(.footnote)
                Button(running ? "Проверка…" : "Проверить доступ") {Task {await check()}}.disabled(running || !env.isLiveVKSession)
                if running {ProgressView()}
                if let checkedAt {Text(checkedAt.formatted()).font(.caption)}
            }
            ForEach(Array(results.enumerated()),id:\.offset) {_,text in Text(text).font(.callout)}
            Section("Push") {Text("Push-уведомления отключены в этой версии.")}
            if !results.isEmpty {Button("Скопировать отчёт") {UIPasteboard.general.string=(["VK HIG · "+(checkedAt?.formatted() ?? "")]+results).joined(separator:"\n")}}
        }.navigationTitle("Проверка VK")
    }
    private func check() async {
        guard env.isLiveVKSession,!running else {return};running=true;results=[];checkedAt=Date();defer {running=false}
        let token=await env.tokenProvider.accessToken()
        let profile=await env.profileRepository.fetchProfile(dataMode:.live,capabilities:env.capabilities,isNetworkReachable:env.isNetworkReachable,accessToken:token)
        switch profile {case .success:results.append("Профиль VK ID: доступен");case .failure(let error):results.append("Профиль VK ID: "+error.localizedDescription)}
        let checks:[(String,String,[String:String])]=[
            ("Переписка","messages.getConversations",["count":"1"]),
            ("Лента","newsfeed.get",["count":"1"]),
            ("Истории","stories.get",[:]),
            ("Фото","photos.getAlbums",["count":"1"]),
            ("Сохранённое","fave.get",["count":"1"])
        ]
        for (name,method,parameters) in checks {
            do {_ = try await env.catalog.request(method,parameters);results.append(name+": доступен")}
            catch {results.append(name+": "+error.localizedDescription)}
        }
        if env.capabilities.grantedScopes.contains("audio") {
            do {_ = try await env.catalog.request("audio.get",["count":"1"]);results.append("Музыка VK: доступна")}
            catch {results.append("Музыка VK: "+error.localizedDescription)}
        } else {results.append("Музыка VK: право audio не выдано")}
    }
}
