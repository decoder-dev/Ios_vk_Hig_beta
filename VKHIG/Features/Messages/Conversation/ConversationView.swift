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
    @State private var forwardPeers: [Conversation] = []

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
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.chatSearch(conversation.peerID.raw)) {
                    Image(systemName: "magnifyingglass")
                        .frame(minWidth: 44, minHeight: 44)
                }
                NavigationLink(value: AppRoute.chatInfo(conversation.peerID.raw)) {
                    Image(systemName: "info.circle")
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .toolbar(.hidden, for:.tabBar)
        .confirmationDialog("Удалить сообщение у себя?",isPresented:Binding(get:{deleting != nil},set:{if !$0 {deleting = nil}})) {
            Button("Удалить",role:.destructive) { if let message = deleting { Task { await model?.delete(message) } }; deleting = nil }
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
        .sheet(item:$forwarding) { message in
            NavigationStack {
                List(forwardPeers) { peer in Button(peer.displayName) { Task { await model?.forward(message,to:peer.id); forwarding = nil } } }
                    .navigationTitle("Переслать в диалог")
                    .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Отмена") { forwarding = nil } } }
                    .task {
                        let token = await env.liveAPIGate.accessTokenIfLiveReady()
                        if case .success(let peers) = await env.conversationRepository.fetchInbox(dataMode:env.dataMode,capabilities:env.capabilities,isNetworkReachable:env.isNetworkReachable,accessToken:token) { forwardPeers = peers }
                    }
            }
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
                }
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
                titleForEmpty: "Нет сообщений",
                emptySymbol: "text.bubble",
                emptyDetails: "Здесь появятся сообщения этого диалога.",
                onRetry: { Task { await model.load() } }
            ) { messages in
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 9) {
                            if !model.reachedStart { Button("Загрузить предыдущие") { Task { await model.loadOlder() } }.disabled(model.loadingOlder).frame(minHeight:44) }
                            ForEach(messages) { message in
                                MessageBubble(message: message, onReply:{model.replyingTo = message; composerFocused = true}, onForward:{forwarding = message}, onDelete:{deleting = message}, onRetry:{Task { await model.retry(message) }},onEdit:{editedText = message.text; editing = message})
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 12)
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
                HStack { Text("Ответ: \(reply.text)").font(.caption).lineLimit(2); Spacer(); Button("Отмена") { model.replyingTo = nil } }.padding(.horizontal)
            }
            composer(model)
        }
        .background(VKStyle.canvas)
    }

    private func composer(_ model: ConversationViewModel) -> some View {
        @Bindable var model = model
        return HStack(alignment: .bottom, spacing: 10) {
            NavigationLink(value: AppRoute.chatAttachments(model.conversation.peerID.raw)) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Добавить вложение")

            TextField("Сообщение", text: $model.draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
                .focused($composerFocused)
                .onChange(of:model.draft) { _,_ in model.persistDraft() }

            Button {
                Task { await model.send() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(model.isSending || model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Отправить сообщение")
        }
        .tint(VKStyle.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial)
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let onReply: () -> Void
    let onForward: () -> Void
    let onDelete: () -> Void
    let onRetry: () -> Void
    let onEdit: () -> Void

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
                ForEach(message.attachments) { attachment in
                    if attachment.kind == .photo {
                        AsyncImage(url:attachment.url) { image in image.resizable().scaledToFit() } placeholder: { ProgressView() }
                            .frame(maxWidth:260,maxHeight:220).clipShape(RoundedRectangle(cornerRadius:12))
                    } else { Link(destination:attachment.url) { Label(attachment.title,systemImage:attachment.kind == .video ? "play.rectangle" : "doc") }.frame(minHeight:44) }
                }
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
        .contextMenu {
            // S13 — message actions; destructive paths need confirmation when live.
            Button("Copy") { UIPasteboard.general.string = message.text }
            Button("Ответить",action:onReply)
            if message.isOutgoing,message.serverID != nil { Button("Редактировать",action:onEdit) }
            Button("Переслать",action:onForward)
                .disabled(message.serverID == nil)
            Divider()
            Button("Удалить",role:.destructive,action:onDelete)
            if message.state == .failed { Button("Повторить",action:onRetry) }
        }
    }
}
