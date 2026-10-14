// ZikrAdventureApp.swift
// Точка входа приложения ZIKR ADVENTURE.
// Интерфейс приложения встроен в сборку (папка Web) и работает полностью офлайн:
// без интернета, регистрации, рекламы и аналитики.

import SwiftUI

@main
struct ZikrAdventureApp: App {
    var body: some Scene {
        WindowGroup {
            WebAppView()
                .ignoresSafeArea()
                .background(Color("LaunchBackground").ignoresSafeArea())
        }
    }
}

/// Обёртка UIKit-контроллера для SwiftUI.
struct WebAppView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WebAppViewController {
        WebAppViewController()
    }

    func updateUIViewController(_ controller: WebAppViewController, context: Context) {}
}
