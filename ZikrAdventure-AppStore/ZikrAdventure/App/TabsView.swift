// TabsView.swift
// Главная структура приложения с нативной навигацией по вкладкам.
// Каждая вкладка может быть нативной или показывать соответствующий раздел веб-приложения.
// Во время миграции все вкладки начинают с веб-версии; по мере выполнения задач
// (ZKR-50 Настройки, ZKR-48 Инфо, ZKR-52 Зикр, ZKR-53 Путь Сиры, ZKR-57 Карта)
// каждая вкладка будет заменена на нативную реализацию.

import SwiftUI

struct TabsView: View {
    @State private var selectedTab: TabItem = .zikr
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(TabItem.allCases) { tab in
                contentView(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
                    .tag(tab)
            }
        }
        .tint(Color("AccentColor"))
    }
    
    /// Возвращает представление для вкладки.
    /// Сейчас все вкладки показывают веб-контент; в будущем здесь будет switch
    /// для выбора нативной или веб-реализации каждой вкладки.
    @ViewBuilder
    private func contentView(for tab: TabItem) -> some View {
        // На данном этапе все вкладки показывают веб-версию.
        // В будущих задачах здесь появится логика выбора:
        // switch tab {
        // case .settings: NativeSettingsView()
        // case .info: NativeInfoView()
        // case .zikr: NativeZikrView()
        // case .path: NativePathView()
        // case .map: NativeMapView()
        // }
        WebContentView(sectionID: tab.webSectionID)
    }
}

#Preview {
    TabsView()
}
