import SwiftUI

/// S06 — comments list (fixture).
struct CommentsView: View {
    let postID: Int64
    @State private var draft = ""

    var body: some View {
        FixtureScreen(
            title: "Комментарии",
            screenID: "S06",
            emptyTitle: "No comments",
            emptySymbol: "text.bubble",
            emptyDetails: "wall.getComments wires here when available.",
            isEmpty: { $0.isEmpty },
            loadValue: {
                CatalogFixtures.comments.filter { $0.postID == postID || postID == 0 }
            }
        ) { comments in
            List(comments) { item in
                HStack(alignment: .top, spacing: 12) {
                    VKAvatar(initials: item.initials, size: 36, tint: .indigo)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.author).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(item.dateLabel).font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(item.text).font(.body)
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
                    TextField("Write a comment", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)
                    Button {} label: {
                        Image(systemName: "arrow.up.circle.fill").font(.title2)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Send comment (fixture — not live)")
                }
                .padding(10)
                .background(.regularMaterial)
            }
        }
    }
}
