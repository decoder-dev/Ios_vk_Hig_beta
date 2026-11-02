import SwiftUI

struct VKInboxScreen: View {
    @State private var searchText = ""
    @State private var filter = "Все"
    private let conversations = ReferenceFixtures.conversations

    private var visible: [VKConversationPreview] {
        conversations.filter { item in
            let matchesText = searchText.isEmpty || item.displayName.localizedCaseInsensitiveContains(searchText) || item.lastMessage.localizedCaseInsensitiveContains(searchText)
            let matchesFilter = filter != "Непрочитанные" || item.unreadCount > 0
            return matchesText && matchesFilter
        }
    }

    var body: some View {
        List {
            Picker("Фильтр", selection: $filter) {
                Text("Все").tag("Все")
                Text("Непрочитанные").tag("Непрочитанные")
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            ForEach(visible) { conversation in
                NavigationLink(value: conversation) {
                    VKConversationRow(conversation: conversation)
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск по перепискам")
        .navigationTitle("Сообщения")
        .navigationDestination(for: VKConversationPreview.self) { conversation in
            VKConversationScreen(conversation: conversation)
        }
        .overlay {
            if visible.isEmpty {
                VKEmptyState(symbol: "bubble.left.and.bubble.right", title: "Нет диалогов", details: "Попробуйте другой запрос")
                    .allowsHitTesting(false)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { /* Agent: wire up compose/new chat flow. */ } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("Новое сообщение")
            }
        }
    }
}

struct VKConversationRow: View {
    let conversation: VKConversationPreview
    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                VKAvatar(initials: conversation.initials, size: 54, tint: .indigo)
                if conversation.online {
                    Circle().fill(Color.green).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(VKStyle.canvas, lineWidth: 2))
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(conversation.displayName).font(.headline).lineLimit(1)
                    Spacer(minLength: 6)
                    Text(conversation.lastUpdated).font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Text(conversation.lastMessage)
                        .font(.subheadline).foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if conversation.unreadCount > 0 {
                        Text(conversation.unreadCount.formatted())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(VKStyle.accent, in: Capsule())
                            .accessibilityLabel("Непрочитанных: \(conversation.unreadCount)")
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
