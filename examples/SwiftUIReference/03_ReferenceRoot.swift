import SwiftUI

/// UI showcase only. A real app must route auth and connect repositories.
enum VKReferenceTab: Hashable {
    case feed, services, messages, music, profile
}

struct VKReferenceRoot: View {
    @State private var selected: VKReferenceTab = .messages

    var body: some View {
        if #available(iOS 26.0, *) {
            tabs.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            tabs
        }
    }

    private var tabs: some View {
        TabView(selection: $selected) {
            NavigationStack {
                VKFeedScreen()
            }
            .tabItem { Label("Лента", systemImage: "house") }
            .tag(VKReferenceTab.feed)

            NavigationStack {
                VKServicesScreen()
            }
            .tabItem { Label("Сервисы", systemImage: "square.grid.2x2") }
            .tag(VKReferenceTab.services)

            NavigationStack {
                VKInboxScreen()
            }
            .tabItem { Label("Сообщения", systemImage: "bubble.left.and.bubble.right") }
            .tag(VKReferenceTab.messages)

            NavigationStack {
                VKMusicScreen()
            }
            .tabItem { Label("Музыка", systemImage: "music.note") }
            .tag(VKReferenceTab.music)

            NavigationStack {
                VKProfileScreen()
            }
            .tabItem { Label("Профиль", systemImage: "person.crop.circle") }
            .tag(VKReferenceTab.profile)
        }
        .tint(VKStyle.accent)
    }
}

#Preview("Reference / iOS") { VKReferenceRoot() }
