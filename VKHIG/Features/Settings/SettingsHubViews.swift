import SwiftUI

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
                Text("System permission via UNUserNotificationCenter is requested on Mac/device builds when enabling push.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Уведомления")
    }
}

/// S36
struct PrivacySettingsView: View {
    @AppStorage("vkhig.privacy.hideOnline") private var hideOnline = false
    @AppStorage("vkhig.privacy.closedProfile") private var closedProfile = false

    var body: some View {
        Form {
            Section("S36 · Local preferences") {
                Toggle("Скрывать онлайн (local)", isOn: $hideOnline)
                Toggle("Закрытый профиль (local)", isOn: $closedProfile)
            }
            Section {
                Text("Server-side privacy account methods stay gated until verified.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Конфиденциальность")
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
                Text("App follows system Dynamic Type. Reduce Motion is respected by avoiding nonessential animation where possible.")
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
                LabeledContent("Кэш (оценка)", value: "12 MB fixture")
                Toggle("Загрузка по сотовой сети", isOn: $cellular)
                Button("Очистить кэш", role: .destructive) {
                    cleared = true
                }
            }
            if cleared {
                Section {
                    Text("Local cache clear simulated — no VK server side effect.")
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
                    Text(AppSecrets.hasVKIDCredentials ? "Configured (from build/env)" : "Missing")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Redirect URI", value: AppSecrets.vkRedirectURI)
                LabeledContent("Client secret in app") {
                    Text("No (PKCE / backend only)")
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
