import SwiftUI
import UIKit

/// S05 — post detail from fixtures.
struct PostDetailView: View {
    let postID: Int64
    @Environment(AppEnvironment.self) private var env
    @State private var showShare = false
    @State private var liked = false

    var body: some View {
        FixtureScreen(
            title: "Запись",
            screenID: "S05",
            resourceID: postID,
            emptyTitle: "Запись не найдена",
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
                    guard let post = posts.first(where: { $0.id == postID }) else {
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
                    if !post.attachments.isEmpty {ForEach(post.attachments) {AttachmentPreview(attachment:$0)}}
                    else if post.hasMedia {
                        AsyncImage(url:post.mediaURL) { image in image.resizable().scaledToFit() } placeholder: { ProgressView().frame(height:220) }
                    }
                    HStack(spacing: 20) {
                        Button { Task {
                            guard env.isLiveVKSession else { liked.toggle(); return }
                            if await env.catalog.perform(liked ? "likes.delete" : "likes.add",["type":"post","owner_id":"\(post.ownerID)","item_id":"\(post.nativeID ?? post.id)"]) { liked.toggle() }
                        } } label: { Label((post.reactionCount + (liked ? 1 : 0)).formatted(),systemImage:liked ? "heart.fill" : "heart") }
                        NavigationLink(value: AppRoute.comments(post.id)) {
                            Label(post.commentCount.formatted(), systemImage: "bubble.right")
                        }
                        Button {Task {
                            if env.isLiveVKSession {_ = await env.catalog.perform("fave.addPost",["owner_id":String(post.ownerID),"id":String(post.nativeID ?? post.id)])}
                            else {env.catalog.notice="Деморежим: запись не добавлена в VK."}
                        }} label:{Image(systemName:"bookmark").frame(width:44,height:44)}.accessibilityLabel("Сохранить запись")
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
                Button("Копировать ссылку") { UIPasteboard.general.string = "https://vk.com/wall\(post.ownerID)_\(post.nativeID ?? post.id)" }
                Button("Cancel", role: .cancel) {}
            }
        }
        .withAppRoutes()
    }
}
