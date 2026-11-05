import SwiftUI

enum AppTab: Hashable {
    case feed, services, messages, music, profile
}

struct RootTabView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var selected: AppTab = .messages
    @State private var feedPath: [AppRoute] = []
    @State private var servicesPath: [AppRoute] = []
    @State private var messagesPath: [AppRoute] = []
    @State private var musicPath: [AppRoute] = []
    @State private var profilePath: [AppRoute] = []

    var body: some View {
        TabView(selection: $selected) {
            NavigationStack(path:$feedPath) {
                FeedView()
                    .withAppRoutes()
            }
            .modifier(MusicMiniPlayerTabInset())
            .tabItem { Label("Лента", systemImage: "house") }
            .tag(AppTab.feed)

            NavigationStack(path:$servicesPath) {
                ServicesHubView()
            }
            .modifier(MusicMiniPlayerTabInset())
            .tabItem { Label("Сервисы", systemImage: "square.grid.2x2") }
            .tag(AppTab.services)

            NavigationStack(path:$messagesPath) {
                InboxView()
                    .withAppRoutes()
            }
            .modifier(MusicMiniPlayerTabInset())
            .tabItem { Label("Сообщения", systemImage: "bubble.left.and.bubble.right") }
            .tag(AppTab.messages)

            NavigationStack(path:$musicPath) {
                MusicLibraryView()
            }
            .modifier(MusicMiniPlayerTabInset())
            .tabItem { Label("Музыка", systemImage: "music.note") }
            .tag(AppTab.music)

            NavigationStack(path:$profilePath) {
                ProfileView()
                    .withAppRoutes()
            }
            .modifier(MusicMiniPlayerTabInset())
            .tabItem { Label("Профиль", systemImage: "person.crop.circle") }
            .tag(AppTab.profile)
        }
        .modifier(MusicMiniPlayerModifier())
        .disabled(env.isSigningOut)
        .overlay {if env.isSigningOut {ProgressView("Выход из аккаунта…").padding(24).background(.regularMaterial,in:RoundedRectangle(cornerRadius:16))}}
        .tint(VKStyle.accent)
        .onAppear { if env.isLiveVKSession,!env.capabilities.canUseLiveAPI(.inbox) { selected = .profile };openPendingRoute() }
        .alert("VK HIG",isPresented:Binding(get:{env.catalog.notice != nil},set:{if !$0 {env.catalog.notice = nil}})) {
            Button("ОК") { env.catalog.notice = nil }
        } message: { Text(env.catalog.notice ?? "") }
        .onChange(of:env.pendingRoute) { _,_ in openPendingRoute() }
    }
    private func openPendingRoute() {
        guard let route=env.pendingRoute else {return}
        switch route {
        case .conversation,.groupChat,.chatInfo,.chatSearch:selected = .messages;messagesPath.append(route)
        case .postDetail,.comments:selected = .feed;feedPath.append(route)
        default:selected = .services;servicesPath.append(route)
        }
        env.pendingRoute=nil
    }

}

#Preview {
    RootTabView()
        .environment(AppEnvironment())
}
