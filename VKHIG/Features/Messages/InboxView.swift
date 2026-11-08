import SwiftUI

/// S08 — conversation list with loading/empty/error/offline.
struct InboxView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: InboxViewModel?

    private let filters: [VKChip<InboxViewModel.Filter>] = [
        VKChip(value: .all, title: "Все"),
        VKChip(value: .unread, title: "Непрочитанные"),
        VKChip(value: .personal, title: "Личные"),
        VKChip(value: .chats, title: "Беседы"),
        VKChip(value: .communities, title: "Сообщества")
    ]

    var body: some View {
        Group {
            if let model {
                inboxBody(model)
            } else {
                VKLoadingState(title: "Загрузка…")
            }
        }
        .navigationTitle("Сообщения")
        .task {
            if model == nil {
                let vm = InboxViewModel(environment: env)
                model = vm
                await vm.load()
            }
        }
    }

    @ViewBuilder
    private func inboxBody(_ model: InboxViewModel) -> some View {
        @Bindable var model = model
        LoadableContainer(
            state: model.state,
            titleForEmpty: "Нет диалогов",
            emptySymbol: "bubble.left.and.bubble.right",
            emptyDetails: "Диалогов нет или доступ к сообщениям ещё не выдан.",
            onRetry: { Task { await model.load() } }
        ) { _ in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if model.usesFixtures {
                        FixtureBanner()
                            .padding(.horizontal, VKStyle.Size.contentMargin)
                            .padding(.bottom, VKStyle.Spacing.xs)
                    }

                    VKChipBar(chips: filters, selection: $model.filter)
                        .padding(.bottom, VKStyle.Spacing.xxs)

                    let conversations = model.visibleConversations
                    if conversations.isEmpty {
                        VKEmptyState(
                            symbol: "magnifyingglass",
                            title: "Ничего не найдено",
                            details: "Попробуйте другой запрос или фильтр."
                        )
                        .padding(.top, VKStyle.Spacing.xxl)
                    }
                    ForEach(conversations) { conversation in
                        Group {
                            if conversation.kind == .chat {
                                NavigationLink(value: AppRoute.groupChat(conversation.peerID.raw)) {
                                    ConversationRow(conversation: conversation)
                                }
                            } else {
                                NavigationLink(value: conversation) {
                                    ConversationRow(conversation: conversation)
                                }
                            }
                        }
                        .buttonStyle(VKRowButtonStyle())
                    }
                    if let error = model.pageError {
                        Text(error).font(.footnote).foregroundStyle(.red)
                            .padding(.horizontal, VKStyle.Size.contentMargin)
                    }
                    if !model.reachedEnd {
                        Button("Загрузить ещё") { Task { await model.loadMore() } }
                            .disabled(model.isLoadingMore)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding(.bottom, VKStyle.Spacing.md)
            }
            .background(VKStyle.canvas)
        }
        .searchable(text: $model.searchText, prompt: "Поиск")
        .navigationDestination(for: Conversation.self) { conversation in
            ConversationView(conversation: conversation)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.globalSearch) {
                    Image(systemName: "square.and.pencil")
                        .frame(minWidth: VKStyle.Size.tapTargetMin, minHeight: VKStyle.Size.tapTargetMin)
                }
                .accessibilityLabel("Новое сообщение")
                .disabled(true)
            }
        }
        .refreshable { await model.load() }
    }
}

/// Inbox row from board 01: 52pt avatar, name with mute glyph, time, one-line preview and badge.
private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: VKStyle.Spacing.sm) {
            VKAvatar(
                initials: conversation.initials,
                url: conversation.avatarURL,
                size: VKStyle.Size.avatarRow,
                isOnline: conversation.isOnline
            )
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(conversation.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if conversation.isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Без звука")
                    }
                    Spacer(minLength: 6)
                    Text(conversation.lastUpdatedLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .top, spacing: 6) {
                    Text(conversation.lastMessagePreview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if conversation.unreadCount > 0 {
                        VKBadge(count: conversation.unreadCount, muted: conversation.isMuted)
                    }
                }
            }
        }
        .padding(.horizontal, VKStyle.Size.contentMargin)
        .padding(.vertical, VKStyle.Spacing.xs)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(VKStyle.separator)
                .frame(height: 0.5)
                .padding(.leading, VKStyle.Size.contentMargin + VKStyle.Size.avatarRow + VKStyle.Spacing.sm)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        InboxView()
            .environment(AppEnvironment())
    }
}
