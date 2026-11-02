import SwiftUI

/// S16 — my profile + links into social/media/settings.
struct ProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: ProfileViewModel?

    var body: some View {
        Group {
            if let model {
                profileBody(model)
            } else {
                VKLoadingState(title: "Загрузка…")
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
            titleForEmpty: "Нет профиля",
            emptySymbol: "person.crop.circle",
            emptyDetails: "Войдите через VK ID для загрузки профиля.",
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
                    NavigationLink(value: AppRoute.editProfile) {
                        Label("Редактировать профиль", systemImage: "pencil")
                    }
                    NavigationLink(value: AppRoute.friends) {
                        Label("Друзья", systemImage: "person.2")
                    }
                    NavigationLink(value: AppRoute.communities) {
                        Label("Сообщества", systemImage: "person.3")
                    }
                    NavigationLink(value: AppRoute.photoAlbums) {
                        Label("Альбомы", systemImage: "rectangle.stack")
                    }
                    NavigationLink(value: AppRoute.photos) {
                        Label("Фотографии", systemImage: "photo.on.rectangle.angled")
                    }
                    NavigationLink(value: AppRoute.bookmarks) {
                        Label("Сохранённое", systemImage: "bookmark")
                    }
                    NavigationLink(value: AppRoute.settings) {
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
