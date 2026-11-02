import SwiftUI

/// S06 — comments list (fixture).
struct CommentsView: View {
    let postID: Int64
    @Environment(AppEnvironment.self) private var env
    @State private var revision = 0
    @State private var sending = false
    @State private var localComments: [CommentItem] = []
    @State private var replyTo: CommentItem?
    @State private var draft = ""

    var body: some View {
        FixtureScreen(
            title: "Комментарии",
            screenID: "S06",
            resourceID: postID,
            emptyTitle: "Нет комментариев",
            emptySymbol: "text.bubble",
            emptyDetails: "wall.getComments wires here when available.",
            isEmpty: { $0.isEmpty },
            loadValue: {
                CatalogFixtures.comments.filter { $0.postID == postID || postID == 0 }
            }
        ) { comments in
            List(comments + localComments) { item in
                HStack(alignment: .top, spacing: 12) {
                    VKAvatar(initials: item.initials, size: 36, tint: .indigo)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.author).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(item.dateLabel).font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(item.text).font(.body)
                        Button("Ответить") { replyTo = item }
                            .font(.caption).frame(minHeight:44)
                        if item.replyToID != nil {
                            Text("Reply")
                                .font(.caption)
                                .foregroundStyle(VKStyle.accent)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    TextField("Написать комментарий", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)
                    Button { Task {
                        let text = draft.trimmingCharacters(in:.whitespacesAndNewlines)
                        guard !text.isEmpty, !sending else { return }
                        sending = true; defer { sending = false }
                        if env.isLiveVKSession {
                            do {
                                let post = try env.catalog.post(postID)
                                var parameters = ["owner_id":"\(post.ownerID)","post_id":"\(post.nativeID ?? post.id)","message":text]
                                if let replyTo { parameters["reply_to_comment"] = "\(replyTo.id)" }
                                _ = try await env.catalog.request("wall.createComment",parameters)
                                draft = ""; replyTo = nil; revision += 1
                            } catch { env.catalog.notice = error.localizedDescription }
                        } else {
                            localComments.append(CommentItem(id:Int64(Date().timeIntervalSince1970 * 1000),postID:postID,author:"Вы (демо)",initials:"ВЫ",text:text,dateLabel:"Сейчас",replyToID:replyTo?.id))
                            draft = ""; replyTo = nil
                        }
                    } } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.title2)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .disabled(sending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Send comment (fixture — not live)")
                }
                .padding(10)
                .background(.regularMaterial)
            }
        }
        .id(revision)
        .safeAreaInset(edge:.top) {
            if let replyTo { HStack { Text("Ответ: \(replyTo.author)"); Button("Отмена") { self.replyTo = nil } }.font(.caption).padding(8) }
        }
    }
}
