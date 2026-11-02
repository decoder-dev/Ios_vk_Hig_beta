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
                VKLoadingState(title: "Loading…")
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
            titleForEmpty: "Feed is empty",
            emptySymbol: "newspaper",
            emptyDetails: "newsfeed.get / wall.get will load here after scopes are verified.",
            onRetry: { Task { await model.load() } }
        ) { posts in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if model.usesFixtures {
                        FixtureBanner()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                    }

                    storiesRow

                    Picker("Section", selection: $model.filter) {
                        ForEach(["Для вас", "Друзья", "Сообщества"], id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    ForEach(posts) { post in
                        NavigationLink(value: AppRoute.postDetail(post.id)) {
                            PostCard(post: post)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
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
                .accessibilityLabel("New post")
                NavigationLink(value: AppRoute.notifications) {
                    Image(systemName: "bell")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Notifications")
                NavigationLink(value: AppRoute.globalSearch) {
                    Image(systemName: "magnifyingglass")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Search")
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
        .accessibilityLabel("Stories entry — official API gated")
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
            if post.hasMedia {
                RoundedRectangle(cornerRadius: VKStyle.Radius.medium)
                    .fill(VKStyle.groupedCanvas)
                    .frame(height: 160)
                    .overlay {
                        Label("Media placeholder", systemImage: "photo")
                            .foregroundStyle(.secondary)
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
