// ZKR-59: SwiftUI UI, native writer и однократная legacy-миграция.

import SwiftUI
import FirebaseCore

@main
struct ZikrAdventureApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var container: AppContainer
    @AppStorage("app.appearance") private var appearance = "system"

    init() {
        let container = AppContainer.live()
        _container = StateObject(wrappedValue: container)

    }

    /// Явная тема для снимков UI-тестов; в обычном запуске и Release используется системная.
    private static var uiTestColorScheme: ColorScheme? {
#if DEBUG
        let process = ProcessInfo.processInfo
        guard process.environment["ZIKR_UITEST_AUTH"] == "guest",
              let index = process.arguments.firstIndex(of: "-AppleInterfaceStyle"),
              process.arguments.indices.contains(index + 1) else { return nil }
        switch process.arguments[index + 1] {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
#else
        return nil
#endif
    }

    var body: some Scene {
        WindowGroup {
            NativeRootView(container: container)
                .background(Theme.Color.bg.ignoresSafeArea())
                .preferredColorScheme(Self.uiTestColorScheme ?? selectedColorScheme)
        }
    }

    private var selectedColorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

/// Делегат приложения для инициализации Firebase
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
