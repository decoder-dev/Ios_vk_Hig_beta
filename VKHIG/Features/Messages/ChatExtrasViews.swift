import SwiftUI

/// S10 — group chat (fixture peer ≥ 2_000_000_000).
struct GroupChatView: View {
    let chatID: Int64

    var body: some View {
        let conversation = Conversation(
            peerID: PeerID(raw: chatID),
            displayName: "Друзья",
            initials: "ДР",
            lastMessagePreview: "Групповой чат",
            lastUpdatedLabel: "—",
            unreadCount: 0,
            isOnline: false
        )
        ConversationView(conversation: conversation)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: AppRoute.chatInfo(chatID)) {
                        Image(systemName: "info.circle")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Chat info")
                }
            }
            .withAppRoutes()
    }
}

/// S11 — conversation info.
struct ChatInfoView: View {
    let peerID: Int64

    var body: some View {
        FixtureScreen(
            title: "Информация",
            screenID: "S11",
            emptyTitle: "Unavailable",
            emptySymbol: "person.crop.circle",
            emptyDetails: "messages.getConversationsById when scoped.",
            loadValue: { peerID }
        ) { id in
            List {
                Section {
                    HStack {
                        Spacer()
                        VKAvatar(initials: id >= 2_000_000_000 ? "ГР" : "ЧТ", size: 72, tint: .indigo)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                Section("Действия") {
                    NavigationLink(value: AppRoute.chatSearch(id)) {
                        Label("Поиск по чату", systemImage: "magnifyingglass")
                    }
                    NavigationLink(value: AppRoute.chatAttachments(id)) {
                        Label("Вложения", systemImage: "paperclip")
                    }
                    Toggle("Уведомления (local)", isOn: .constant(true))
                }
                Section("Участники") {
                    ForEach(CatalogFixtures.friends.prefix(3)) { friend in
                        Label(friend.displayName, systemImage: "person")
                    }
                }
            }
            .withAppRoutes()
        }
    }
}

/// S12 — attachment picker sheet content.
struct ChatAttachmentsView: View {
    let peerID: Int64
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("S12 · peer \(peerID)") {
                Label("Photo Library", systemImage: "photo.on.rectangle")
                Label("Camera", systemImage: "camera")
                Label("Document", systemImage: "doc")
                Label("Location", systemImage: "location")
            }
            Section {
                Text("Attachment uploads require verified permissions and upload endpoints. Nothing is sent from this sheet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Вложения")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }
}

/// S14 — in-chat search.
struct ChatSearchView: View {
    let peerID: Int64
    @State private var query = ""

    var body: some View {
        FixtureScreen(
            title: "Поиск в чате",
            screenID: "S14",
            emptyTitle: "No matches",
            emptySymbol: "magnifyingglass",
            emptyDetails: "messages.search when available.",
            isEmpty: { $0.isEmpty },
            loadValue: { FixtureStore.embedded.messagesByPeer[111] ?? [] }
        ) { messages in
            let visible = query.isEmpty ? messages : messages.filter { $0.text.localizedCaseInsensitiveContains(query) }
            List(visible) { message in
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.text)
                    Text(message.timestamp.formatted())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .searchable(text: $query, prompt: "Search messages")
        }
    }
}
