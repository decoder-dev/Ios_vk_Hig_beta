import SwiftUI
import UserNotifications
import Observation

@main
struct VKHIGApp: App {
    @UIApplicationDelegateAdaptor(PushAppDelegate.self) private var appDelegate
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
            .onChange(of:PushRegistration.shared.pendingRoute) {_,route in
                if let route {environment.pendingRoute=route;PushRegistration.shared.pendingRoute=nil}
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

@MainActor
@Observable
final class PushRegistration {
    static let shared=PushRegistration()
    var status="Push не включён"
    var pendingRoute:AppRoute?
    private var token:String?
    private var registeredUser:Int64?
    private var registering=false
    private var revision=UUID()
    private var deviceID:String {
        if let value=UserDefaults.standard.string(forKey:"vkhig.push.device") {return value}
        let value=UUID().uuidString;UserDefaults.standard.set(value,forKey:"vkhig.push.device");return value
    }
    private var sandbox:String {
        #if DEBUG
        return "1"
        #else
        return "0"
        #endif
    }
    func enable() async {
        do {
            let granted=try await UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound,.badge])
            UserDefaults.standard.set(granted,forKey:"vkhig.notifications.enabled")
            guard granted else {status="Уведомления запрещены в настройках iOS";return}
            status="Регистрация в APNs…";UIApplication.shared.registerForRemoteNotifications()
        } catch {status=error.localizedDescription}
    }
    func received(_ data:Data) async {
        token=data.map {String(format:"%02x",$0)}.joined();registeredUser=nil
        await registerIfNeeded()
    }
    func registerIfNeeded() async {
        guard UserDefaults.standard.bool(forKey:"vkhig.notifications.enabled"),let token,let user=VKIDAuthCoordinator.shared.userID,registeredUser != user,!registering else {return}
        let ticket=revision;registering=true;defer {registering=false}
        do {
            let response=try await VKCatalogService.shared.request("account.registerDevice",["token":token,"device_id":deviceID,"device_model":UIDevice.current.model,"system_version":UIDevice.current.systemVersion,"sandbox":sandbox,"pushes_granted":"1"])
            guard ticket==revision else {return}
            guard response.int==1 else {throw AppError.decoding}
            registeredUser=user;status="Устройство зарегистрировано в VK"
        } catch {if ticket==revision {status="Регистрация VK: "+error.localizedDescription}}
    }
    func disable() async {
        UserDefaults.standard.set(false,forKey:"vkhig.notifications.enabled")
        revision=UUID()
        UIApplication.shared.unregisterForRemoteNotifications()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        pendingRoute=nil
        // Finish any in-flight registration before unregistering this installation.
        while registering {try? await Task.sleep(for:.milliseconds(50))}
        var failure:String?
        if token != nil,VKIDAuthCoordinator.shared.userID != nil {
            do {
                let response=try await VKCatalogService.shared.request("account.unregisterDevice",["device_id":deviceID,"sandbox":sandbox])
                guard response.int==1 else {throw AppError.decoding}
            } catch {failure="Push отключён на устройстве. VK: "+error.localizedDescription}
        }
        registeredUser=nil;status=failure ?? "Push отключён"
    }
    func route(_ payload:[AnyHashable:Any]) {
        // Never open arbitrary URLs from a notification payload.
        let raw=payload["peer_id"] ?? (payload["data"] as? [String:Any])?["peer_id"]
        if let raw,let peer=Int64(String(describing:raw)),peer != 0 {pendingRoute = .conversation(peer)}
        else {pendingRoute = .notifications}
    }
}

final class PushAppDelegate:NSObject,UIApplicationDelegate,UNUserNotificationCenterDelegate {
    func application(_ application:UIApplication,didFinishLaunchingWithOptions launchOptions:[UIApplication.LaunchOptionsKey:Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate=self
        if UserDefaults.standard.bool(forKey:"vkhig.notifications.enabled") {application.registerForRemoteNotifications()}
        return true
    }
    func application(_ application:UIApplication,didRegisterForRemoteNotificationsWithDeviceToken deviceToken:Data) {Task {@MainActor in await PushRegistration.shared.received(deviceToken)}}
    func application(_ application:UIApplication,didFailToRegisterForRemoteNotificationsWithError error:Error) {Task {@MainActor in PushRegistration.shared.status="APNs: "+error.localizedDescription}}
    func userNotificationCenter(_ center:UNUserNotificationCenter,willPresent notification:UNNotification,withCompletionHandler completionHandler:@escaping (UNNotificationPresentationOptions)->Void) {
        let enabled=UserDefaults.standard.bool(forKey:"vkhig.notifications.enabled")
        completionHandler(enabled ? [.banner,.sound,.badge] : [])
    }
    func userNotificationCenter(_ center:UNUserNotificationCenter,didReceive response:UNNotificationResponse,withCompletionHandler completionHandler:@escaping ()->Void) {
        let payload=response.notification.request.content.userInfo
        Task {@MainActor in PushRegistration.shared.route(payload);completionHandler()}
    }
}
