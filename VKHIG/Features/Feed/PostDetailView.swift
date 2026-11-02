import SwiftUI

/// S05 — post detail from fixtures.
struct PostDetailView: View {
    let postID: Int64
    @Environment(AppEnvironment.self) private var env
    @State private var showShare = false

    var body: some View {
        FixtureScreen(
            title: "Запись",
            screenID: "S05",
            emptyTitle: "Post not found",
            emptySymbol: "doc",
            emptyDetails: "wall.getById will resolve this after scopes are verified.",
            loadValue: {
                let feed = try await env.feedRepository.fetchFeed(
                    dataMode: env.dataMode,
                    capabilities: env.capabilities,
                    isNetworkReachable: env.isNetworkReachable
                )
                switch feed {
                case .success(let posts):
                    guard let post = posts.first(where: { $0.id == postID }) ?? posts.first else {
                        throw AppError.fixtureOnly("No fixture post")
                    }
                    return post
                case .failure(let error):
                    throw error
                }
            }
        ) { post in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        VKAvatar(initials: post.authorInitials, size: 44, tint: .teal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.authorName).font(.headline)
                            Text(post.dateLabel).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text(post.text).font(.body)
                    if post.hasMedia {
                        RoundedRectangle(cornerRadius: VKStyle.Radius.card)
                            .fill(VKStyle.cell)
                            .frame(height: 220)
                            .overlay { Label("Media", systemImage: "photo").foregroundStyle(.secondary) }
                    }
                    HStack(spacing: 20) {
                        Label(post.reactionCount.formatted(), systemImage: "heart")
                        NavigationLink(value: AppRoute.comments(post.id)) {
                            Label(post.commentCount.formatted(), systemImage: "bubble.right")
                        }
                        Button { showShare = true } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .confirmationDialog("Share", isPresented: $showShare) {
                Button("Copy link") {}
                Button("Cancel", role: .cancel) {}
            }
        }
        .withAppRoutes()
    }
}
