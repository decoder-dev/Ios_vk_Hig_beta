import SwiftUI
import UserNotifications

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
            .task {
                // Migration from builds that registered for remote notifications.
                UserDefaults.standard.set(false,forKey:"vkhig.notifications.enabled")
                UIApplication.shared.unregisterForRemoteNotifications()
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            }
            .modifier(UITestingTextSize())
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

private struct UITestingTextSize:ViewModifier {
    @ViewBuilder func body(content:Content) -> some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") && ProcessInfo.processInfo.arguments.contains("--large-type") {content.dynamicTypeSize(.accessibility3)} else {content}
        #else
        content
        #endif
    }
}
