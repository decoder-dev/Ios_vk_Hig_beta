import SwiftUI

/// S34 — settings hub (replaces/extends simple settings).
struct SettingsHubView: View {
    var body: some View {
        List {
            Section("Аккаунт") {
                NavigationLink(value: AppRoute.accountSettings) {
                    Label("Аккаунт и безопасность", systemImage: "person.crop.circle")
                }
                NavigationLink(value: AppRoute.privacySettings) {
                    Label("Конфиденциальность", systemImage: "lock.shield")
                }
            }
            Section("Приложение") {
                NavigationLink(value: AppRoute.appearanceSettings) {
                    Label("Оформление", systemImage: "paintbrush")
                }
                NavigationLink(value: AppRoute.storageSettings) {
                    Label("Данные и память", systemImage: "externaldrive")
                }
            }
            #if DEBUG
            Section("Разработка") {
                NavigationLink(value: AppRoute.onboarding) {
                    Label("Онбординг", systemImage: "sparkles")
                }
                LabeledContent("VK client id") {
                    Text(AppSecrets.hasVKIDCredentials ? "Настроен" : "Не настроен")
                        .foregroundStyle(.secondary)
                }
            }
            #endif
        }
        .navigationTitle("Настройки")
        .withAppRoutes()
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
                    Text(env.isLiveVKSession ? "VK ID" : "Демоверсия")
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
