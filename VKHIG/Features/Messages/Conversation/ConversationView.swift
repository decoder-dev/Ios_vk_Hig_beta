import SwiftUI
import UIKit

/// S09 — history + composer. Outgoing stays `.pending` without live API ACK.
struct ConversationView: View {
    let conversation: Conversation
    @Environment(AppEnvironment.self) private var env
    @State private var model: ConversationViewModel?
    @FocusState private var composerFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var editing: ChatMessage?
    @State private var editedText = ""
    @State private var deleting: ChatMessage?
    @State private var forwarding: ChatMessage?
    @State private var pinning:ChatMessage?
    @State private var canPin=false

    var body: some View {
        Group {
            if let model {
                conversationBody(model)
            } else {
                VKLoadingState(title: "Загрузка…")
            }
        }
        .navigationTitle(conversation.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                NavigationLink(value: AppRoute.chatInfo(conversation.peerID.raw)) {
                    HStack(spacing: 8) {
                        VKAvatar(initials: conversation.initials, url: conversation.avatarURL, size: 34)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(conversation.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if let status = headerStatus {
                                Text(status)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(conversation.displayName), информация о диалоге")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.chatSearch(conversation.peerID.raw)) {
                    Image(systemName: "magnifyingglass")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Поиск по диалогу")
                if conversation.kind == .user {
                    NavigationLink(value: AppRoute.incomingCall) {
                        Image(systemName: "phone")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Звонок VK")
                }
            }
        }
        .toolbar(.hidden, for:.tabBar)
        .confirmationDialog("Удалить сообщение у себя?",isPresented:Binding(get:{deleting != nil},set:{if !$0 {deleting = nil}})) {
            Button("Удалить",role:.destructive) { if let message = deleting { Task { await model?.delete(message) } }; deleting = nil }
        }
        .confirmationDialog("Закрепить сообщение в беседе?",isPresented:Binding(get:{pinning != nil},set:{if !$0 {pinning=nil}})) {
            Button("Закрепить") {
                if let id=pinning?.serverID {Task {
                    do {
                        let result=try await env.catalog.request("messages.pin",["peer_id":String(conversation.id),"message_id":String(id)])
                        guard result["id"].int>0 else {throw AppError.decoding}
                        env.catalog.notice="Сообщение закреплено"
                    } catch {env.catalog.notice=error.localizedDescription}
                }}
                pinning=nil
            }
        }
        .sheet(item:$editing) { message in
            NavigationStack {
                Form { TextField("Сообщение",text:$editedText,axis:.vertical).lineLimit(4...12) }
                    .navigationTitle("Редактировать")
                    .toolbar {
                        ToolbarItem(placement:.cancellationAction) { Button("Отмена") { editing = nil } }
                        ToolbarItem(placement:.confirmationAction) { Button("Сохранить") { Task { await model?.edit(message,text:editedText); editing = nil } }.disabled(editedText.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty) }
                    }
            }
        }
        .sheet(item:$forwarding) {message in
            RecipientPickerView {peer in await model?.forward(message,to:peer.id) == true}
        }
        .withAppRoutes()
        .task(id:scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                if model != nil,env.isLiveVKSession { await model?.poll() }
                do { try await Task.sleep(for:.seconds(20)) } catch { return }
            }
        }
        .task {
            if model == nil {
                let vm = ConversationViewModel(conversation: conversation, environment: env)
                model = vm
                await vm.load()
                if env.isLiveVKSession,scenePhase == .active {
                    _ = try? await env.catalog.request("messages.markAsRead",["peer_id":"\(conversation.id)","mark_conversation_as_read":"1"])
                    if conversation.id>2_000_000_000,let response=try? await env.catalog.request("messages.getConversationsById",["peer_ids":String(conversation.id)]) {canPin=response.list.first?["chat_settings"]["acl"]["can_change_pin"].flag == true}
                }
            }
        }
    }

    private var headerStatus: String? {
        switch conversation.kind {
        case .user: return conversation.isOnline ? "онлайн" : nil
        case .chat: return "беседа"
        case .community: return "сообщество"
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
                titleForEmpty: "Нет сообщений",
                emptySymbol: "text.bubble",
                emptyDetails: "Здесь появятся сообщения этого диалога.",
                onRetry: { Task { await model.load() } }
            ) { messages in
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            if !model.reachedStart { Button("Загрузить предыдущие") { Task { await model.loadOlder() } }.disabled(model.loadingOlder).frame(minHeight:44) }
                            ForEach(messages) { message in
                                MessageBubble(message: message, onReply:{model.replyingTo = message; composerFocused = true}, onForward:{forwarding = message}, onDelete:{deleting = message}, onRetry:{Task { await model.retry(message) }},onEdit:{editedText = message.text; editing = message},canPin:canPin,onPin:{pinning=message})
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 14)
                    }
                    .onAppear { if let id = messages.last?.id { proxy.scrollTo(id,anchor:.bottom) } }
                    .onChange(of:model.scrollToMessage) { _, id in
                        guard let id else { return }
                        if reduceMotion { proxy.scrollTo(id,anchor:.bottom) }
                        else { withAnimation(.easeOut(duration:0.2)) { proxy.scrollTo(id,anchor:.bottom) } }
                    }
                }
            }

            if let reply = model.replyingTo {
                HStack(spacing: 10) {
                    Rectangle().fill(VKStyle.accent).frame(width: 3).clipShape(Capsule())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ответ").font(.caption.weight(.semibold)).foregroundStyle(VKStyle.accent)
                        Text(reply.text).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button { model.replyingTo = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Отменить ответ")
                }
                .frame(height: 44)
                .padding(.leading, 16)
                .background(.bar)
            }
            composer(model)
        }
        .background(VKStyle.canvas)
    }

    private func composer(_ model: ConversationViewModel) -> some View {
        @Bindable var model = model
        let canSend = !model.isSending && !model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(alignment: .bottom, spacing: 6) {
            NavigationLink(value: AppRoute.chatAttachments(model.conversation.peerID.raw)) {
                Image(systemName: "plus")
                    .font(.title2.weight(.regular))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Добавить вложение")

            TextField("Сообщение", text: $model.draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($composerFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(minHeight: 38)
                .background(VKStyle.chipFill, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                .padding(.vertical, 3)
                .onChange(of:model.draft) { _,_ in model.persistDraft() }

            Button {
                Task { await model.send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .symbolRenderingMode(.hierarchical)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.45)
            .accessibilityLabel("Отправить сообщение")
        }
        .tint(VKStyle.accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let onReply: () -> Void
    let onForward: () -> Void
    let onDelete: () -> Void
    let onRetry: () -> Void
    let onEdit: () -> Void
    var canPin=false
    let onPin:()->Void

    private var timeLabel: String {
        message.timestamp.formatted(date: .omitted, time: .shortened)
    }

    private var bubbleColor: Color { message.isOutgoing ? VKStyle.accent : Color(uiColor: .secondarySystemBackground) }
    private var metaColor: Color { message.isOutgoing ? Color.white.opacity(0.78) : Color.secondary }

    /// Time + delivery glyph shown inside the bubble's bottom-trailing corner.
    private var meta: Text {
        var text = Text(timeLabel)
        if message.isOutgoing {
            switch message.state {
            case .pending: text = text + Text(" ") + Text(Image(systemName: "clock"))
            case .failed: text = text + Text(" ") + Text(Image(systemName: "exclamationmark.circle.fill"))
            case .sent, .received: text = text + Text(" ") + Text(Image(systemName: "checkmark"))
            }
        }
        return text
    }

    var body: some View {
        HStack(alignment: .bottom) {
            if message.isOutgoing { Spacer(minLength: 52) }
            VStack(alignment: message.isOutgoing ? .trailing : .leading, spacing: 4) {
                ForEach(message.quotes) {quote in
                    HStack(spacing: 8) {
                        Rectangle().fill(VKStyle.accent).frame(width: 3).clipShape(Capsule())
                        VStack(alignment:.leading,spacing:4) {
                            Text(quote.title).font(.caption.bold()).foregroundStyle(VKStyle.accent)
                            if !quote.text.isEmpty {Text(quote.text).font(.callout).lineLimit(4)}
                            ForEach(quote.attachments) {AttachmentPreview(attachment:$0)}
                        }
                    }
                    .padding(10).frame(maxWidth:280,alignment:.leading)
                    .background(Color(uiColor: .secondarySystemBackground),in:RoundedRectangle(cornerRadius:14,style:.continuous))
                }
                ForEach(message.attachments) {AttachmentPreview(attachment:$0)}
                if !message.text.isEmpty {
                    // The clear copy of `meta` reserves room so the visible time sits on the last line when it fits.
                    (Text(message.text) + Text("   ") + meta.foregroundColor(.clear))
                        .font(.body)
                        .foregroundColor(message.isOutgoing ? Color.white : Color.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottomTrailing) {
                            meta
                                .font(.caption2)
                                .foregroundColor(message.state == .failed ? Color.red : metaColor)
                                .padding(.trailing, 10)
                                .padding(.bottom, 6)
                        }
                        .background(bubbleColor, in: RoundedRectangle(cornerRadius: VKStyle.Radius.bubble, style: .continuous))
                        .frame(maxWidth: 300, alignment: message.isOutgoing ? .trailing : .leading)
                } else {
                    meta.font(.caption2).foregroundColor(message.state == .failed ? Color.red : Color.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            if !message.isOutgoing { Spacer(minLength: 52) }
        }
        .accessibilityElement(children: .combine)
        .contextMenu {
            // S13 — message actions; destructive paths need confirmation when live.
            Button("Копировать") { UIPasteboard.general.string = message.text }
            Button("Ответить",action:onReply)
            if canPin && message.serverID != nil {Button("Закрепить",action:onPin)}
            if message.isOutgoing,message.serverID != nil { Button("Редактировать",action:onEdit) }
            Button("Переслать",action:onForward)
                .disabled(message.serverID == nil)
            Divider()
            Button("Удалить",role:.destructive,action:onDelete)
            if message.state == .failed { Button("Повторить",action:onRetry) }
        }
    }
}
