import SwiftUI

/// S04 — feed with stories entry + navigation to S05/S06/S07/S24/S41.
struct FeedView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: FeedViewModel?
    @State private var showCompose = false

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

    @ViewBuilder
    private func feedBody(_ model: FeedViewModel) -> some View {
        @Bindable var model = model
        LoadableContainer(
            state: model.state,
            titleForEmpty: "Лента пуста",
            emptySymbol: "newspaper",
            emptyDetails: "Обновите ленту или проверьте доступ приложения к новостям.",
            onRetry: { Task { await model.load() } }
        ) { posts in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if model.usesFixtures {
                        FixtureBanner()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                    }

                    if model.usesFixtures { storiesRow } else {LiveStoriesStrip()}

                    ForEach(posts) { post in
                        NavigationLink(value: AppRoute.postDetail(post.id)) {
                            PostCard(post: post)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }
                    if let error = model.pageError { Text(error).font(.footnote).foregroundStyle(.red) }
                    if !model.reachedEnd {
                        Button("Загрузить ещё") { Task { await model.loadMore() } }
                            .disabled(model.isLoadingMore)
                            .frame(minHeight:44)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(VKStyle.groupedCanvas)
            .refreshable { await model.load() }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showCompose = true } label: {
                    Image(systemName: "square.and.pencil")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Новая запись")
                NavigationLink(value: AppRoute.notifications) {
                    Image(systemName: "bell")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Уведомления")
                NavigationLink(value: AppRoute.globalSearch) {
                    Image(systemName: "magnifyingglass")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Поиск")
            }
        }
    }

    private var storiesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(CatalogFixtures.stories) { story in
                    NavigationLink(value: AppRoute.story(story.id)) {
                        VStack(spacing: 6) {
                            VKAvatar(initials: story.initials, size: 58, tint: .blue)
                            Text(story.author).font(.caption2).lineLimit(1)
                        }
                        .frame(width: 72)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .accessibilityLabel("Истории")
    }
}

private struct PostCard: View {
    let post: FeedPost

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VKAvatar(initials: post.authorInitials, size: 40, tint: .teal)
                VStack(alignment: .leading, spacing: 3) {
                    Text(post.authorName).font(.headline)
                    Text(post.dateLabel).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Text(post.text).font(.body)
                .foregroundStyle(.primary)
            if !post.attachments.isEmpty {ForEach(post.attachments) {AttachmentPreview(attachment:$0)}}
            else if post.hasMedia {
                if let url = post.mediaURL {
                    AsyncImage(url:url) { image in image.resizable().scaledToFit() } placeholder: { ProgressView().frame(height:160) }
                        .clipShape(RoundedRectangle(cornerRadius:VKStyle.Radius.medium))
                }
            }
            HStack(spacing: 16) {
                Label(post.reactionCount.formatted(), systemImage: "heart")
                Label(post.commentCount.formatted(), systemImage: "bubble.right")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(VKStyle.cell, in: RoundedRectangle(cornerRadius: VKStyle.Radius.card))
    }
}
