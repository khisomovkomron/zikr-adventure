// WebContentView.swift
// SwiftUI-обёртка для показа определённого раздела веб-приложения.
// Использует существующий WebAppViewController, но добавляет возможность переключения
// между разделами (s-zikr, s-map, s-path, s-info, s-settings) через JavaScript.
// Это позволяет во время миграции сохранить полную функциональность веб-приложения
// (счётчик, сохранение, мосты для haptic, keepAwake и т.д.) в каждой нативной вкладке.

import SwiftUI
import WebKit

struct WebContentView: UIViewControllerRepresentable {
    let sectionID: String
    
    func makeUIViewController(context: Context) -> WebAppViewController {
        let controller = WebAppViewController()
        // Контроллер загрузит веб-приложение; после загрузки переключим на нужный раздел
        return controller
    }
    
    func updateUIViewController(_ controller: WebAppViewController, context: Context) {
        // Переключаем на нужный раздел при изменении вкладки
        controller.showSection(sectionID)
    }
}
