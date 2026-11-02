import SwiftUI

struct VKFeedScreen: View {
    @State private var filter = "Для вас"
    @State private var entries = ReferenceFixtures.feed

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                Picker("Раздел", selection: $filter) {
                    ForEach(["Для вас", "Друзья", "Сообщества"], id: \.self) { item in
                        Text(item).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(["Ваша история", "Анастасия", "Дмитрий", "Мария"], id: \.self) { name in
                            VStack(spacing: 6) {
                                VKAvatar(initials: String(name.prefix(1)), size: 58, tint: .blue)
                                Text(name).font(.caption2).lineLimit(1)
                            }
                            .frame(width: 78)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .accessibilityLabel("Истории — только при наличии разрешённого VK API")

                ForEach(entries) { post in
                    VKPostPreviewCard(post: post)
                }
            }
            .padding(.vertical, 12)
        }
        .background(VKStyle.groupedCanvas)
        .navigationTitle("Лента")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { /* Agent: connect actual Notifications route. */ } label: {
                    Image(systemName: "bell")
                }
                .accessibilityLabel("Уведомления")
            }
        }
    }
}

struct VKPostPreviewCard: View {
    let post: VKFeedPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VKAvatar(initials: post.initials, size: 40, tint: .teal)
                VStack(alignment: .leading, spacing: 3) {
                    Text(post.author).font(.headline)
                    Text(post.dateDescription).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            Text(post.content).font(.body)
            if post.hasMedia {
                ZStack {
                    LinearGradient(colors: [.indigo.opacity(0.7), .cyan.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(height: 205)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel("Иллюстрация — превью, не фото из VK")
            }
            HStack(spacing: 20) {
                Label(post.reactions.formatted(), systemImage: "heart")
                Label(post.comments.formatted(), systemImage: "bubble.right")
                Image(systemName: "arrowshape.turn.up.right")
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityHint("Реакции и репосты подключаются только после проверки VK API")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VKStyle.canvas, in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 12)
    }
}
