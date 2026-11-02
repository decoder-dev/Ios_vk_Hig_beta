import SwiftUI

enum AppTab: Hashable {
    case feed, services, messages, music, profile
}

struct RootTabView: View {
    @State private var selected: AppTab = .messages

    var body: some View {
        TabView(selection: $selected) {
            NavigationStack {
                FeedView()
                    .withAppRoutes()
            }
            .tabItem { Label("Лента", systemImage: "house") }
            .tag(AppTab.feed)

            NavigationStack {
                ServicesHubView()
            }
            .tabItem { Label("Сервисы", systemImage: "square.grid.2x2") }
            .tag(AppTab.services)

            NavigationStack {
                InboxView()
                    .withAppRoutes()
            }
            .tabItem { Label("Сообщения", systemImage: "bubble.left.and.bubble.right") }
            .tag(AppTab.messages)

            NavigationStack {
                MusicLibraryView()
            }
            .tabItem { Label("Музыка", systemImage: "music.note") }
            .tag(AppTab.music)

            NavigationStack {
                ProfileView()
                    .withAppRoutes()
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
