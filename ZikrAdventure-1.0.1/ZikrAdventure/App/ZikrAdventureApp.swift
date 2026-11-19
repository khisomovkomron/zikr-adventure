// ZKR-59: SwiftUI UI, native writer и однократная legacy-миграция.

import SwiftUI
import FirebaseCore

@main
struct ZikrAdventureApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var container: AppContainer

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
                .preferredColorScheme(Self.uiTestColorScheme)
                .task {
                    // ZKR-49: нативный слой данных в режиме «тени» (только зеркало веб-состояния).
                    await container.bootstrap()
                }
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
