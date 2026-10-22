// ZikrAdventureApp.swift
// Точка входа приложения ZIKR ADVENTURE.
// Интерфейс приложения встроен в сборку (папка Web) и работает полностью офлайн:
// без интернета, регистрации, рекламы и аналитики.
// Версия 1.1.0 добавляет необязательную авторизацию через Google и Apple.

import SwiftUI
import FirebaseCore

@main
struct ZikrAdventureApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            WebAppView()
                .ignoresSafeArea()
                .background(Color("LaunchBackground").ignoresSafeArea())
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

/// Обёртка UIKit-контроллера для SwiftUI.
struct WebAppView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WebAppViewController {
        WebAppViewController()
    }

    func updateUIViewController(_ controller: WebAppViewController, context: Context) {}
}
