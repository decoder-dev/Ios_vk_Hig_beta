import SwiftUI

/// Primary tab shell: Лента / Сервисы / Сообщения / Музыка / Профиль.
enum AppTab: Hashable {
    case feed
    case services
    case messages
    case music
    case profile
}

struct RootTabView: View {
    @State private var selected: AppTab = .messages

    var body: some View {
        TabView(selection: $selected) {
            NavigationStack {
                FeedView()
            }
            .tabItem { Label("Лента", systemImage: "house") }
            .tag(AppTab.feed)

            NavigationStack {
                ServicesPlaceholderView()
            }
            .tabItem { Label("Сервисы", systemImage: "square.grid.2x2") }
            .tag(AppTab.services)

            NavigationStack {
                InboxView()
            }
            .tabItem { Label("Сообщения", systemImage: "bubble.left.and.bubble.right") }
            .tag(AppTab.messages)

            NavigationStack {
                MusicPlaceholderView()
            }
            .tabItem { Label("Музыка", systemImage: "music.note") }
            .tag(AppTab.music)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Профиль", systemImage: "person.crop.circle") }
            .tag(AppTab.profile)
        }
        .tint(VKStyle.accent)
    }
}

#Preview {
    RootTabView()
        .environment(AppEnvironment())
}
