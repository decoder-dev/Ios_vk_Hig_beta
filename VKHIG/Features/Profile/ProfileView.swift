import SwiftUI

/// S15 profile + S23 settings entry.
struct ProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: ProfileViewModel?

    var body: some View {
        Group {
            if let model {
                profileBody(model)
            } else {
                VKLoadingState(title: "Loading…")
            }
        }
        .navigationTitle("Профиль")
        .task {
            if model == nil {
                let vm = ProfileViewModel(environment: env)
                model = vm
                await vm.load()
            }
        }
    }

    @ViewBuilder
    private func profileBody(_ model: ProfileViewModel) -> some View {
        LoadableContainer(
            state: model.state,
            titleForEmpty: "No profile",
            emptySymbol: "person.crop.circle",
            emptyDetails: "users.get will populate this after VK ID.",
            onRetry: { Task { await model.load() } }
        ) { profile in
            List {
                if model.usesFixtures {
                    Section {
                        FixtureBanner()
                            .listRowBackground(Color.clear)
                    }
                }

                Section {
                    HStack(spacing: VKStyle.Spacing.sm) {
                        VKAvatar(initials: profile.initials, size: VKStyle.Size.avatarListLarge, tint: VKStyle.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.displayName).font(.headline)
                            if let city = profile.city {
                                Text(city).font(.subheadline).foregroundStyle(.secondary)
                            }
                            if let status = profile.statusText {
                                Text(status).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Разделы") {
                    Label("Фотографии", systemImage: "photo.on.rectangle.angled")
                    Label("Друзья", systemImage: "person.2")
                    Label("Сообщества", systemImage: "person.3")
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Настройки", systemImage: "gearshape")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        env.signOut()
                    } label: {
                        Text(env.isLiveVKSession ? "Sign out" : "Leave UI shell")
                    }
                }
            }
            .refreshable { await model.load() }
        }
    }
}

struct SettingsView: View {
    @AppStorage("vkhig.notifications.enabled") private var notificationsEnabled = false
    @AppStorage("vkhig.cellular.download") private var cellularDownload = false
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Form {
            Section("Аккаунт") {
                Label(
                    env.isLiveVKSession ? "VK ID session" : "Fixture shell session",
                    systemImage: "person.crop.circle"
                )
                Label("Privacy", systemImage: "lock.shield")
            }
            Section("Уведомления") {
                Toggle("In-app notifications (local preference)", isOn: $notificationsEnabled)
            }
            Section("Данные") {
                Toggle("Cellular download (local preference)", isOn: $cellularDownload)
                Label("Cache management (not wired)", systemImage: "externaldrive")
            }
            Section("Data source") {
                Text(env.dataMode == .fixtures
                     ? "Repositories use bundled fixtures. Live VK calls are gated."
                     : "Live mode selected — features still require verified scopes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Настройки")
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environment(AppEnvironment())
    }
}
