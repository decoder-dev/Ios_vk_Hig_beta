import SwiftUI

@main
struct VKHIGApp: App {
    @State private var environment = AppEnvironment()

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
        }
    }
}
