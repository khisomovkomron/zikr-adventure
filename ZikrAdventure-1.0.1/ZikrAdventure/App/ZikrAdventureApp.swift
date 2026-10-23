// ZikrAdventureApp.swift
// Точка входа приложения ZIKR ADVENTURE.
// SwiftUI App lifecycle: TabsView держит один shared WKWebView и нативный tab bar.
// Интерфейс приложения встроен в сборку (папка Web) и работает полностью офлайн:
// без интернета, регистрации, рекламы и аналитики.
// Версия 1.1.0 добавляет необязательную авторизацию через Google и Apple.

import SwiftUI
import FirebaseCore

@main
struct ZikrAdventureApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var container: AppContainer

    init() {
        let container = AppContainer.live()
        _container = StateObject(wrappedValue: container)
        // ZKR-49/ZKR-61: зеркало подключается до того, как TabsView создаст WKWebView и страница
        // загрузится, — первый снимок (didFinish) и первые "save" не пропускаются.
        if AppContainer.isWebMirrorEnabled {
            WebViewManager.attachStateMirrorEarly(container.webStateMirror)
        }
    }

    var body: some Scene {
        WindowGroup {
            TabsView()
                .background(Theme.Color.bg.ignoresSafeArea())
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
