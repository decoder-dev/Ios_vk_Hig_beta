import SwiftUI
import UserNotifications

/// S34 — settings hub (replaces/extends simple settings).
struct SettingsHubView: View {
    var body: some View {
        List {
            Section("S34 · Аккаунт") {
                NavigationLink(value: AppRoute.accountSettings) {
                    Label("Аккаунт и безопасность", systemImage: "person.crop.circle")
                }
                NavigationLink(value: AppRoute.privacySettings) {
                    Label("Конфиденциальность", systemImage: "lock.shield")
                }
            }
            Section("Приложение") {
                NavigationLink(value: AppRoute.notificationSettings) {
                    Label("Уведомления", systemImage: "bell")
                }
                NavigationLink(value: AppRoute.appearanceSettings) {
                    Label("Оформление", systemImage: "paintbrush")
                }
                NavigationLink(value: AppRoute.storageSettings) {
                    Label("Данные и память", systemImage: "externaldrive")
                }
            }
            Section("Разработка") {
                NavigationLink(value: AppRoute.onboarding) {
                    Label("Онбординг", systemImage: "sparkles")
                }
                LabeledContent("VK client id") {
                    Text(AppSecrets.hasVKIDCredentials ? "Configured" : "Placeholder")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Настройки")
        .withAppRoutes()
    }
}

/// S35
struct NotificationSettingsView: View {
    @AppStorage("vkhig.notifications.enabled") private var enabled = false
    @State private var permission = ""
    @AppStorage("vkhig.notifications.messages") private var messages = true
    @AppStorage("vkhig.notifications.feedback") private var feedback = true

    var body: some View {
        Form {
            Section("S35") {
                Toggle("Уведомления в приложении", isOn: $enabled)
                Toggle("Сообщения", isOn: $messages)
                    .disabled(!enabled)
                Toggle("Лайки и комментарии", isOn: $feedback)
                    .disabled(!enabled)
            }
            Section {
                Text(permission.isEmpty ? "Разрешение iOS позволяет показывать уведомления. Доставка push от VK требует отдельно зарегистрированного сервиса." : permission)
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Уведомления")
        .onChange(of:enabled) { _,value in
            guard value else { return }
            Task {
                do {
                    let granted = try await UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound,.badge])
                    enabled = granted
                    permission = granted ? "Разрешение получено. Push-сервис ещё не зарегистрирован." : "Уведомления запрещены в настройках iOS."
                } catch { enabled = false; permission = "Не удалось запросить разрешение." }
            }
        }
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
            Section("S39 · Сессия") {
                LabeledContent("Режим") {
                    Text(env.isLiveVKSession ? "VK ID" : "Fixture shell")
                }
                LabeledContent("VK ID client") {
                    Text(AppSecrets.hasVKIDCredentials ? "Настроен" : "Не настроен")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Redirect URI", value: AppSecrets.vkRedirectURI)
                LabeledContent("Выданные права",value:env.capabilities.grantedScopes.sorted().joined(separator:", "))
                LabeledContent("Client secret in app") {
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
