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
            .tint(VKStyle.accent)
            .preferredColorScheme(colorScheme)
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
