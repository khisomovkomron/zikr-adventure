// ZikrAdventureApp.swift
// Точка входа приложения ZIKR ADVENTURE.
// Приложение использует нативную SwiftUI-навигацию с TabView.
// Интерфейс приложения встроен в сборку (папка Web) и работает полностью офлайн:
// без интернета, регистрации, рекламы и аналитики.
// Во время миграции на нативные экраны вкладки постепенно заменяются с веб-версии
// на нативные SwiftUI-представления.

import SwiftUI

@main
struct ZikrAdventureApp: App {
    var body: some Scene {
        WindowGroup {
            TabsView()
                .background(Color("LaunchBackground").ignoresSafeArea())
        }
    }
}

/// Обёртка UIKit-контроллера для SwiftUI (используется в WebContentView).
struct WebAppView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WebAppViewController {
        WebAppViewController()
    }

    func updateUIViewController(_ controller: WebAppViewController, context: Context) {}
}
