import SwiftUI

/// S04 — feed list. Fixtures clearly labeled; live newsfeed gated.
struct FeedView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var model: FeedViewModel?

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

                    Picker("Section", selection: $model.filter) {
                        ForEach(["Для вас", "Друзья", "Сообщества"], id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    ForEach(posts) { post in
                        PostCard(post: post)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(VKStyle.groupedCanvas)
            .refreshable { await model.load() }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {} label: {
                    Image(systemName: "bell")
                        .frame(minWidth: VKStyle.Size.tapTargetMin, minHeight: VKStyle.Size.tapTargetMin)
                }
                .accessibilityLabel("Notifications")
                .disabled(true)
            }
        }
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
            if post.hasMedia {
                RoundedRectangle(cornerRadius: VKStyle.Radius.medium)
                    .fill(VKStyle.groupedCanvas)
                    .frame(height: 160)
                    .overlay {
                        Label("Media placeholder", systemImage: "photo")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Media placeholder")
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

#Preview {
    NavigationStack {
        FeedView()
            .environment(AppEnvironment())
    }
}
