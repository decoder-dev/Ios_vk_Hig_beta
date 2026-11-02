import SwiftUI

/// S09 — history + composer. Outgoing stays `.pending` without live API ACK.
struct ConversationView: View {
    let conversation: Conversation
    @Environment(AppEnvironment.self) private var env
    @State private var model: ConversationViewModel?
    @FocusState private var composerFocused: Bool

    var body: some View {
        Group {
            if let model {
                conversationBody(model)
            } else {
                VKLoadingState(title: "Loading…")
            }
        }
        .navigationTitle(conversation.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil {
                let vm = ConversationViewModel(conversation: conversation, environment: env)
                model = vm
                await vm.load()
            }
        }
    }

    @ViewBuilder
    private func conversationBody(_ model: ConversationViewModel) -> some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            if model.usesFixtures {
                FixtureBanner()
                    .padding(.vertical, 6)
            }
            if let sendNotice = model.sendNotice {
                Text(sendNotice)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }

            LoadableContainer(
                state: model.state,
                titleForEmpty: "No messages",
                emptySymbol: "text.bubble",
                emptyDetails: "History appears after messages.getHistory is available.",
                onRetry: { Task { await model.load() } }
            ) { messages in
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 9) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 14)
                    }
                    .onChange(of: messages.count) { _, _ in
                        guard let id = messages.last?.id else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(id, anchor: .bottom)
                        }
                    }
                }
            }

            composer(model)
        }
        .background(VKStyle.canvas)
    }

    private func composer(_ model: ConversationViewModel) -> some View {
        @Bindable var model = model
        return HStack(alignment: .bottom, spacing: 10) {
            Button {} label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Add attachment")
            .disabled(true)

            TextField("Message", text: $model.draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
                .focused($composerFocused)

            Button {
                Task { await model.send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Send message")
        }
        .tint(VKStyle.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    private var timeLabel: String {
        message.timestamp.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 58) }
            VStack(alignment: .trailing, spacing: 5) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(message.isOutgoing ? Color.white : Color.primary)
                    .frame(maxWidth: 296, alignment: .leading)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(
                        message.isOutgoing ? VKStyle.accent : VKStyle.cell,
                        in: RoundedRectangle(cornerRadius: VKStyle.Radius.bubble)
                    )
                HStack(spacing: 4) {
                    Text(timeLabel)
                    if message.state == .pending { Image(systemName: "clock") }
                    if message.state == .failed {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            if !message.isOutgoing { Spacer(minLength: 58) }
        }
        .accessibilityElement(children: .combine)
    }
}
