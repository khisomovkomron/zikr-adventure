// TabsView.swift
// Главная структура приложения с нативной навигацией по вкладкам.
// WebView занимает весь экран, custom tab bar внизу.

import SwiftUI

struct TabsView: View {
    @State private var selectedTab: TabItem = .zikr
    @StateObject private var appLanguage = AppLanguage()
    @StateObject private var webViewManager = WebViewManager.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // WebView занимает весь экран
            WebHostView()
                .environmentObject(appLanguage)
                .ignoresSafeArea()
            
            // Custom tab bar внизу
            CustomTabBar(selectedTab: $selectedTab, appLanguage: appLanguage)
        }
        .onChange(of: selectedTab) { newTab in
            webViewManager.selectTab(newTab.webID)
        }
        .onAppear {
            webViewManager.setAppLanguage(appLanguage)
            webViewManager.setTabSelectionHandler { tabID in
                if let tab = TabItem.allCases.first(where: { $0.webID == tabID }) {
                    selectedTab = tab
                }
            }
            webViewManager.selectTab(selectedTab.webID)
        }
    }
}

/// Хост для WebView, всегда показывает один shared controller
struct WebHostView: UIViewControllerRepresentable {
    @EnvironmentObject var appLanguage: AppLanguage
    
    func makeUIViewController(context: Context) -> WebAppViewController {
        return WebViewManager.shared.viewController
    }
    
    func updateUIViewController(_ controller: WebAppViewController, context: Context) {
        // WebViewManager управляет всем, ничего здесь не делаем
    }
}

/// Custom tab bar, выглядит как native
struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    let appLanguage: AppLanguage
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 23))
                        Text(appLanguage.title(for: tab))
                            .font(.system(size: 10))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(selectedTab == tab ? Color("AccentColor") : .secondary)
                    .fontWeight(selectedTab == tab ? .semibold : .regular)
                }
            }
        }
        .frame(height: 49)
        .padding(.bottom, 0)
        .background(
            Color(uiColor: .systemBackground)
                .shadow(color: .black.opacity(0.1), radius: 0, x: 0, y: -0.5)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
