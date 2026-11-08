import SwiftUI
import UIKit

/// S04 — feed with stories entry + navigation to S05/S06/S07/S24/S41.
struct FeedView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: FeedViewModel?
    @State private var showCompose = false
    @State private var source: FeedSource = .all

    enum FeedSource: Hashable { case all, people, communities }
    private let sources: [VKChip<FeedSource>] = [
        VKChip(value: .all, title: "Для вас"),
        VKChip(value: .people, title: "Друзья"),
        VKChip(value: .communities, title: "Сообщества")
    ]

    var body: some View {
        Group {
            if let model {
                feedBody(model)
            } else {
                VKLoadingState(title: "Загрузка…")
            }
        }
        .navigationTitle("Лента")
        .task {
            if model == nil {
                let vm = FeedViewModel(environment: env)
                model = vm
                await vm.load()
            }
        }
        .sheet(isPresented: $showCompose) {
            ComposePostView()
        }
    }

    /// newsfeed.get mixes people (positive source_id) and communities (negative); the chips split them locally.
    private func visible(_ posts: [FeedPost]) -> [FeedPost] {
        switch source {
        case .all: return posts
        case .people: return posts.filter { $0.ownerID > 0 }
        case .communities: return posts.filter { $0.ownerID < 0 }
        }
    }

    @ViewBuilder
    private func feedBody(_ model: FeedViewModel) -> some View {
        LoadableContainer(
            state: model.state,
            titleForEmpty: "Лента пуста",
            emptySymbol: "newspaper",
            emptyDetails: "Обновите ленту или проверьте доступ приложения к новостям.",
            onRetry: { Task { await model.load() } }
        ) { posts in
            ScrollView {
                LazyVStack(spacing: VKStyle.Spacing.xs) {
                    VStack(alignment: .leading, spacing: VKStyle.Spacing.sm) {
                        if model.usesFixtures {
                            FixtureBanner()
                                .padding(.horizontal, VKStyle.Size.contentMargin)
                        }
                        VKChipBar(chips: sources, selection: $source)
                        if model.usesFixtures { storiesRow } else { LiveStoriesStrip() }
                    }
                    .padding(.bottom, VKStyle.Spacing.xs)

                    let shown = visible(posts)
                    if shown.isEmpty {
                        Text(source == .people ? "В загруженной ленте нет записей друзей." : "В загруженной ленте нет записей сообществ.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(VKStyle.Spacing.xl)
                    }
                    ForEach(shown) { post in
                        NavigationLink(value: AppRoute.postDetail(post.id)) {
                            PostCard(post: post)
                        }
                        .buttonStyle(.plain)
                    }
                    if let error = model.pageError { Text(error).font(.footnote).foregroundStyle(.red) }
                    if !model.reachedEnd {
                        Button("Загрузить ещё") { Task { await model.loadMore() } }
                            .disabled(model.isLoadingMore)
                            .frame(minHeight: 44)
                    }
                }
                .padding(.vertical, VKStyle.Spacing.xs)
            }
            .background(VKStyle.groupedCanvas)
            .refreshable { await model.load() }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.globalSearch) {
                    Image(systemName: "magnifyingglass")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Поиск")
                Button { showCompose = true } label: {
                    Image(systemName: "plus")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Новая запись")
                NavigationLink(value: AppRoute.notifications) {
                    Image(systemName: "bell")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Уведомления")
            }
        }
    }

    private var storiesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VKStyle.Spacing.sm) {
                ForEach(CatalogFixtures.stories) { story in
                    NavigationLink(value: AppRoute.story(story.id)) {
                        VKStoryBubble(title: story.author, initials: story.initials, seen: story.id == 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, VKStyle.Size.contentMargin)
        }
        .accessibilityLabel("Истории")
    }
}

/// Feed post section from board 01: author row, text, edge-to-edge media, counters.
/// Display-only inside the feed; likes and saving live in S05 where VK confirms them.
struct PostCard: View {
    let post: FeedPost

    var body: some View {
        VStack(alignment: .leading, spacing: VKStyle.Spacing.sm) {
            HStack(spacing: 10) {
                VKAvatar(initials: post.authorInitials, url: post.avatarURL, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(post.dateLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let url = post.webURL {
                    Menu {
                        ShareLink(item: url) { Label("Поделиться", systemImage: "square.and.arrow.up") }
                        Button { UIPasteboard.general.url = url } label: { Label("Копировать ссылку", systemImage: "link") }
                        if !post.text.isEmpty {
                            Button { UIPasteboard.general.string = post.text } label: { Label("Копировать текст", systemImage: "doc.on.doc") }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Действия с записью")
                }
            }
            .padding(.horizontal, VKStyle.Size.contentMargin)

            if !post.text.isEmpty {
                Text(post.text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(8)
                    .padding(.horizontal, VKStyle.Size.contentMargin)
            }

            media
                .padding(.horizontal, VKStyle.Spacing.xs)

            counters
                .padding(.horizontal, VKStyle.Size.contentMargin)
        }
        .padding(.vertical, VKStyle.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VKStyle.cell)
    }

    private var photoAttachments: [ChatAttachment] { post.attachments.filter { $0.kind == .photo } }
    private var otherAttachments: [ChatAttachment] { post.attachments.filter { $0.kind != .photo } }

    @ViewBuilder
    private var media: some View {
        if let first = photoAttachments.first {
            AsyncImage(url: first.url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Rectangle().fill(VKStyle.chipFill).overlay { ProgressView() }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: VKStyle.Radius.medium, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if photoAttachments.count > 1 {
                    Text("1 / \(photoAttachments.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.black.opacity(0.45), in: Capsule())
                        .padding(10)
                }
            }
            .accessibilityLabel(first.title)
        } else if post.hasMedia {
            Group {
                if let url = post.mediaURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() }
                        else { VKMediaPlaceholder(seed: post.authorName) }
                    }
                } else {
                    VKMediaPlaceholder(symbol: "mountain.2.fill", seed: post.authorName)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: VKStyle.Radius.medium, style: .continuous))
        }
        ForEach(otherAttachments) { attachment in
            AttachmentPreview(attachment: attachment)
        }
    }

    private var counters: some View {
        HStack(spacing: VKStyle.Spacing.xs) {
            counter("heart", post.reactionCount, label: "Нравится")
            counter("bubble.right", post.commentCount, label: "Комментарии")
            counter("arrowshape.turn.up.right", post.repostCount, label: "Репосты")
            Spacer(minLength: 4)
            if let views = post.viewCount {
                Label(VKFormat.compact(views), systemImage: "eye")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Просмотров: \(views)")
            }
        }
    }

    private func counter(_ symbol: String, _ value: Int, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
            if value > 0 { Text(VKFormat.compact(value)).monospacedDigit() }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(minHeight: 32)
        .background(VKStyle.chipFill, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}
