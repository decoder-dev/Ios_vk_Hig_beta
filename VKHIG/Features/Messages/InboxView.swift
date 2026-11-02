import SwiftUI

/// S08 — conversation list with loading/empty/error/offline.
struct InboxView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: InboxViewModel?

    var body: some View {
        Group {
            if let model {
                inboxBody(model)
            } else {
                VKLoadingState(title: "Loading…")
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
            titleForEmpty: "No conversations",
            emptySymbol: "bubble.left.and.bubble.right",
            emptyDetails: "Inbox is empty, or messages scope is not granted yet.",
            onRetry: { Task { await model.load() } }
        ) { _ in
            List {
                if model.usesFixtures {
                    Section {
                        FixtureBanner()
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                }

                Picker("Filter", selection: $model.unreadOnly) {
                    Text("Все").tag(false)
                    Text("Непрочитанные").tag(true)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                ForEach(model.visibleConversations) { conversation in
                    NavigationLink(value: conversation) {
                        ConversationRow(conversation: conversation)
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if model.visibleConversations.isEmpty, case .loaded = model.state {
                    VKEmptyState(
                        symbol: "magnifyingglass",
                        title: "Nothing found",
                        details: "Try another search or filter."
                    )
                    .allowsHitTesting(false)
                }
            }
        }
        .searchable(text: $model.searchText, prompt: "Search conversations")
        .navigationDestination(for: Conversation.self) { conversation in
            ConversationView(conversation: conversation)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {} label: {
                    Image(systemName: "square.and.pencil")
                        .frame(minWidth: VKStyle.Size.tapTargetMin, minHeight: VKStyle.Size.tapTargetMin)
                }
                .accessibilityLabel("New message")
                .disabled(true)
            }
        }
        .refreshable { await model.load() }
    }
}

private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: VKStyle.Spacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                VKAvatar(initials: conversation.initials, size: VKStyle.Size.avatarListLarge, tint: .indigo)
                if conversation.isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(VKStyle.canvas, lineWidth: 2))
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(conversation.displayName).font(.headline).lineLimit(1)
                    Spacer(minLength: 6)
                    Text(conversation.lastUpdatedLabel).font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Text(conversation.lastMessagePreview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if conversation.unreadCount > 0 {
                        Text(conversation.unreadCount.formatted())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(VKStyle.accent, in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        InboxView()
            .environment(AppEnvironment())
    }
}
