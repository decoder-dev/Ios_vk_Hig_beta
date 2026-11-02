import SwiftUI

struct VKConversationScreen: View {
    let conversation: VKConversationPreview
    @State private var messages: [VKChatMessage] = ReferenceFixtures.messages
    @State private var draft = ""
    @FocusState private var composerFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 9) {
                    Text("Сегодня").font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.top, 8)
                    ForEach(messages) { message in
                        VKMessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 14)
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: messages.count) { _, _ in
                guard let id = messages.last?.id else { return }
                // This is only a preview. A real chat needs an "is user near bottom" guard
                // and stable visual position when prepend-loading older pages.
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .bottom) }
            }
        }
        .background(VKStyle.canvas)
        .navigationTitle(conversation.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button { /* Agent: open attachment picker, after permissions check. */ } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Добавить вложение")

            TextField("Сообщение", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
                .focused($composerFocused)
                .accessibilityIdentifier("chat.composer")
                .padding(.vertical, 4)

            Button(action: addPendingPreviewOnly) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Отправить сообщение")
            .accessibilityIdentifier("chat.send")
        }
        .tint(VKStyle.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial)
    }

    private func addPendingPreviewOnly() {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        draft = ""
        messages.append(.init(id: UUID(), serverID: nil, text: content, time: Date.now.formatted(date: .omitted, time: .shortened), outgoing: true, state: .pending))
        // Never mark this fake pending message as sent. Integrate VKAPIClient
        // + MessageReconciler + request.random_id before shipping a real client.
    }
}

private struct VKMessageBubble: View {
    let message: VKChatMessage
    var body: some View {
        HStack {
            if message.outgoing { Spacer(minLength: 58) }
            VStack(alignment: .trailing, spacing: 5) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(message.outgoing ? Color.white : Color.primary)
                    .frame(maxWidth: 296, alignment: .leading)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(message.outgoing ? VKStyle.accent : VKStyle.cell,
                                in: RoundedRectangle(cornerRadius: VKStyle.Radius.bubble))
                HStack(spacing: 4) {
                    Text(message.time)
                    if message.state == .pending { Image(systemName: "clock") }
                    if message.state == .failed { Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red) }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            if !message.outgoing { Spacer(minLength: 58) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.outgoing ? "Исходящее" : "Входящее") сообщение: \(message.text)")
    }
}
