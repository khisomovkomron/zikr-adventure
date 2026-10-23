// TabsView.swift
// Главная структура приложения с нативной навигацией по вкладкам.
// Использует единственный WebAppViewController через WebViewManager,
// который переиспользуется между всеми вкладками.

import SwiftUI

struct TabsView: View {
    @State private var selectedTab: TabItem = .zikr
    @StateObject private var appLanguage = AppLanguage()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(TabItem.allCases) { tab in
                WebContentView(tab: tab)
                    .ignoresSafeArea()
                    .tabItem {
                        Label(appLanguage.title(for: tab), systemImage: tab.systemImage)
                    }
                    .tag(tab)
            }
        }
        .tint(Color("AccentColor"))
        .environmentObject(appLanguage)
    }
}
