// AppLanguage.swift
// Хранит текущий язык приложения и локализованные названия вкладок,
// получаемые от веб-приложения через мост lang.change.

import SwiftUI

@MainActor
class AppLanguage: ObservableObject {
    @Published var currentLang: String = UserDefaults.standard.string(forKey: "app.language") ?? "ru"
    @Published var tabTitles: [String: String] = [:]
    
    init() {
        loadTabTitles()
    }
    
    /// Обновить язык и названия вкладок из веб-приложения
    func update(lang: String, titles: [String: String]) {
        currentLang = lang
        tabTitles = titles
        
        // Сохраняем для следующего запуска
        UserDefaults.standard.set(lang, forKey: "app.language")
        if let data = try? JSONEncoder().encode(titles) {
            UserDefaults.standard.set(data, forKey: "app.tabTitles")
        }
    }
    
    /// Получить название вкладки
    func title(for tab: TabItem) -> String {
        return tabTitles[tab.webID] ?? tab.fallbackTitle
    }
    
    private func loadTabTitles() {
        guard let data = UserDefaults.standard.data(forKey: "app.tabTitles"),
              let titles = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        tabTitles = titles
    }
}
