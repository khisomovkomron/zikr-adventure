// TabsView.swift
// Главная структура приложения с нативной навигацией по вкладкам.
// WebView живёт вне TabView и управляется напрямую через onChange selection.

import SwiftUI

struct TabsView: View {
    @State private var selectedTab: TabItem = .zikr
    @StateObject private var appLanguage = AppLanguage()
    @StateObject private var webViewManager = WebViewManager.shared
    
    var body: some View {
        ZStack {
            // WebView всегда присутствует, под TabView
            WebHostView()
                .ignoresSafeArea()
            
            // Прозрачный TabView для навигации
            TabView(selection: $selectedTab) {
                ForEach(TabItem.allCases) { tab in
                    Color.clear
                        .tabItem {
                            Label(appLanguage.title(for: tab), systemImage: tab.systemImage)
                        }
                        .tag(tab)
                }
            }
            .tint(Color("AccentColor"))
        }
        .environmentObject(appLanguage)
        .onChange(of: selectedTab) { _, newTab in
            webViewManager.selectTab(newTab.webID)
        }
        .onAppear {
            webViewManager.initialize(appLanguage: appLanguage)
            webViewManager.setTabSelectionHandler { tabID in
                if let tab = TabItem.allCases.first(where: { $0.webID == tabID }) {
                    selectedTab = tab
                }
            }
            // Выбираем начальную вкладку
            webViewManager.selectTab(selectedTab.webID)
        }
    }
}

/// Хост для WebView, живёт постоянно
struct WebHostView: UIViewControllerRepresentable {
    @StateObject private var webViewManager = WebViewManager.shared
    
    func makeUIViewController(context: Context) -> WebAppViewController {
        return webViewManager.viewController ?? WebAppViewController()
    }
    
    func updateUIViewController(_ controller: WebAppViewController, context: Context) {
        // Ничего не делаем - управление через WebViewManager
    }
}
