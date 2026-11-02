import SwiftUI

@main
struct VKHIGApp: App {
    @State private var environment = AppEnvironment()
    @AppStorage("vkhig.appearance.mode") private var appearanceMode = "system"

    var body: some Scene {
        WindowGroup {
            Group {
                if environment.isAuthenticated {
                    RootTabView()
                } else {
                    AuthStubView()
                }
            }
            .environment(environment)
            .onOpenURL { url in
                guard url.scheme == "vkhig", let host = url.host else { return }
                let id = url.pathComponents.compactMap(Int64.init).first
                switch host {
                case "messages": if let id { environment.pendingRoute = .conversation(id) }
                case "user": if let id { environment.pendingRoute = .userProfile(id) }
                case "community": if let id { environment.pendingRoute = .community(id) }
                case "search": environment.pendingRoute = .globalSearch
                default: break
                }
            }
            .tint(VKStyle.accent)
            .preferredColorScheme(colorScheme)
        }
    }

    private var colorScheme: ColorScheme? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            if ProcessInfo.processInfo.arguments.contains("--dark") { return .dark }
            if ProcessInfo.processInfo.arguments.contains("--light") { return .light }
        }
        #endif
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
