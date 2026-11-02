import Foundation

@MainActor
@Observable
final class ConversationViewModel {
    let conversation: Conversation
    private let environment: AppEnvironment

    var state: LoadState<[ChatMessage]> = .idle
    var draft = ""
    var usesFixtures = false
    var sendNotice: String?

    init(conversation: Conversation, environment: AppEnvironment) {
        self.conversation = conversation
        self.environment = environment
    }

    func load() async {
        state = .loading
        usesFixtures = environment.dataMode == .fixtures && !environment.isLiveVKSession

        let token = await environment.liveAPIGate.accessTokenIfLiveReady()
        let result = await environment.conversationRepository.fetchHistory(
            peerID: conversation.peerID,
            dataMode: environment.dataMode,
            capabilities: environment.capabilities,
            isNetworkReachable: environment.isNetworkReachable,
            accessToken: token
        )
        switch result {
        case .success(let items):
            state = items.isEmpty ? .empty : .loaded(items)
        case .failure(.offline):
            state = .offline
        case .failure(let error):
            state = .failed(error)
        }
    }

    func send() async {
        let text = draft
        draft = ""
        sendNotice = nil

        let token = await environment.liveAPIGate.accessTokenIfLiveReady()
        let result = await environment.conversationRepository.enqueueOutgoing(
            peerID: conversation.peerID,
            text: text,
            dataMode: environment.dataMode,
            capabilities: environment.capabilities,
            accessToken: token
        )
        switch result {
        case .success(let message):
            if case .loaded(var items) = state {
                items.append(message)
                state = .loaded(items)
            } else {
                state = .loaded([message])
            }
            if message.state == .pending {
                sendNotice = usesFixtures
                    ? "Queued locally as pending — fixture mode never ACKs as live send."
                    : "Pending until messages.send is enabled."
            }
        case .failure(let error):
            sendNotice = error.localizedDescription
            draft = text
        }
    }
}
