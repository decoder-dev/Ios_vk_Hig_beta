import SwiftUI

/// S16 — my profile + links into social/media/settings.
struct ProfileView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: ProfileViewModel?
    @State private var confirmSignOut = false

    var body: some View {
        Group {
            if let model {
                profileBody(model)
            } else {
                VKLoadingState(title: "Загрузка…")
            }
        }
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.settings) {
                    Image(systemName: "gearshape")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Настройки")
            }
        }
        .confirmationDialog(env.isLiveVKSession ? "Выйти из аккаунта?" : "Выйти из демоверсии?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Выйти", role: .destructive) { env.signOut() }
            Button("Отмена", role: .cancel) {}
        }
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
            ScrollView {
                VStack(spacing: VKStyle.Spacing.md) {
                    header(profile)

                    if model.usesFixtures {
                        FixtureBanner()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, VKStyle.Size.contentMargin)
                    }

                    stats(profile.counters)
                        .padding(.horizontal, VKStyle.Size.contentMargin)

                    VStack(spacing: 0) {
                        row("Сохранённое", "bookmark", route: .bookmarks)
                        divider
                        row("Музыка", "music.note", route: .musicLibrary)
                        divider
                        NavigationLink { StoriesListView() } label: { rowLabel("Истории", "clock.arrow.circlepath") }
                            .buttonStyle(VKRowButtonStyle())
                        divider
                        row("Фотоальбомы", "rectangle.stack", route: .photoAlbums)
                        divider
                        row("Изменить профиль", "pencil", route: .editProfile)
                        divider
                        row("Настройки", "gearshape", route: .settings)
                    }
                    .vkCard(radius: VKStyle.Radius.card)
                    .clipShape(RoundedRectangle(cornerRadius: VKStyle.Radius.card, style: .continuous))
                    .padding(.horizontal, VKStyle.Size.contentMargin)

                    Button(role: .destructive) {
                        confirmSignOut = true
                    } label: {
                        Text(env.isLiveVKSession ? "Выйти" : "Выйти из демоверсии")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(VKStyle.error)
                    .vkCard(radius: VKStyle.Radius.card)
                    .padding(.horizontal, VKStyle.Size.contentMargin)
                }
                .padding(.bottom, VKStyle.Spacing.xl)
            }
            .ignoresSafeArea(.container, edges: .top)
            .background(VKStyle.groupedCanvas)
            .refreshable { await model.load() }
        }
    }

    /// Cover, overlapping avatar and the identity card from board 01.
    private func header(_ profile: UserProfile) -> some View {
        VStack(spacing: 0) {
            VKCoverBackground(seed: profile.displayName)
                .frame(height: 210)

            VStack(spacing: VKStyle.Spacing.xs) {
                VKAvatar(initials: profile.initials, url: profile.avatarURL, size: VKStyle.Size.avatarProfile, isOnline: profile.isOnline)
                    .padding(4)
                    .background(VKStyle.cell, in: Circle())
                    .padding(.top, -(VKStyle.Size.avatarProfile / 2 + 24))

                Text(profile.displayName)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                if profile.isOnline {
                    Text("онлайн").font(.subheadline).foregroundStyle(.secondary)
                }
                if let status = profile.statusText, !status.isEmpty {
                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                if profile.university != nil || profile.city != nil {
                    HStack(spacing: VKStyle.Spacing.md) {
                        if let university = profile.university {
                            Label(university, systemImage: "graduationcap")
                        }
                        if let city = profile.city {
                            Label(city, systemImage: "mappin.and.ellipse")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                HStack(spacing: VKStyle.Spacing.xs) {
                    NavigationLink(value: AppRoute.editProfile) {
                        Text("Редактировать")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(VKStyle.accent)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(VKStyle.accentWash, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    if env.isLiveVKSession, let url = URL(string: "https://vk.com/id\(profile.id)") {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(VKStyle.accent)
                                .frame(width: 44, height: 44)
                                .background(VKStyle.accentWash, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .accessibilityLabel("Поделиться профилем")
                    }
                }
                .padding(.top, VKStyle.Spacing.xs)
            }
            .padding(.horizontal, VKStyle.Size.contentMargin)
            .padding(.bottom, VKStyle.Size.contentMargin)
            .frame(maxWidth: .infinity)
            .background(
                VKStyle.cell,
                in: UnevenRoundedRectangle(topLeadingRadius: VKStyle.Radius.large, bottomLeadingRadius: VKStyle.Radius.large, bottomTrailingRadius: VKStyle.Radius.large, topTrailingRadius: VKStyle.Radius.large, style: .continuous)
            )
            .padding(.top, -VKStyle.Radius.large)
            .padding(.horizontal, VKStyle.Spacing.xs)
        }
    }

    private func stats(_ counters: ProfileCounters?) -> some View {
        HStack(spacing: VKStyle.Spacing.xs) {
            NavigationLink(value: AppRoute.friends) {
                VKStatTile(symbol: "person", value: counters?.friends, caption: "друзья")
            }
            NavigationLink(value: AppRoute.communities) {
                VKStatTile(symbol: "person.3", value: counters?.communities, caption: "сообщества")
            }
            NavigationLink(value: AppRoute.photos) {
                VKStatTile(symbol: "photo", value: counters?.photos, caption: "фото")
            }
            NavigationLink(value: AppRoute.videoList) {
                VKStatTile(symbol: "play.rectangle", value: counters?.videos, caption: "видео")
            }
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(VKStyle.separator)
            .frame(height: 0.5)
            .padding(.leading, VKStyle.Size.contentMargin + 28 + VKStyle.Spacing.sm)
    }

    private func row(_ title: String, _ symbol: String, route: AppRoute) -> some View {
        NavigationLink(value: route) { rowLabel(title, symbol) }
            .buttonStyle(VKRowButtonStyle())
    }

    private func rowLabel(_ title: String, _ symbol: String) -> some View {
        HStack(spacing: 0) {
            VKIconRow(title: title, symbol: symbol)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, VKStyle.Size.contentMargin)
        .padding(.vertical, 2)
    }
}
