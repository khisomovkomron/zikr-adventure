// TabsView.swift
// Корневой экран: один shared WKWebView сверху и нативный tab bar снизу.
// TabView не используется — его непрозрачный фон перекрывал web view и перехватывал нажатия.

import SwiftUI

struct TabsView: View {
    @State private var selectedTab: TabItem = .zikr
    @StateObject private var appLanguage = AppLanguage()

    var body: some View {
        VStack(spacing: 0) {
            WebHostView(selectedTab: $selectedTab, appLanguage: appLanguage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .top)

            NativeTabBar(selectedTab: $selectedTab, appLanguage: appLanguage)
        }
        .onChange(of: selectedTab) { newTab in
            WebViewManager.shared.selectTab(newTab.webID)
        }
    }
}

/// Хост единственного WebAppViewController. Контроллер уже создан в WebViewManager.init.
struct WebHostView: UIViewControllerRepresentable {
    @Binding var selectedTab: TabItem
    var appLanguage: AppLanguage

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedTab: $selectedTab)
    }

    func makeUIViewController(context: Context) -> WebAppViewController {
        let manager = WebViewManager.shared
        let controller = manager.viewController
        controller.appLanguage = appLanguage
        controller.webViewManager = manager
        let coordinator = context.coordinator
        manager.setTabSelectionHandler { tabID in
            coordinator.handleTabChange(tabID)
        }
        manager.selectTab(selectedTab.webID)
        return controller
    }

    func updateUIViewController(_ controller: WebAppViewController, context: Context) {
        context.coordinator.selectedTab = $selectedTab
        controller.appLanguage = appLanguage
    }

    final class Coordinator {
        var selectedTab: Binding<TabItem>

        init(selectedTab: Binding<TabItem>) {
            self.selectedTab = selectedTab
        }

        func handleTabChange(_ tabID: String) {
            guard let tab = TabItem.allCases.first(where: { $0.webID == tabID }) else { return }
            if selectedTab.wrappedValue != tab {
                selectedTab.wrappedValue = tab
            }
        }
    }
}

/// Нижняя панель вкладок. Сестра web view в VStack, не overlay.
struct NativeTabBar: View {
    @Binding var selectedTab: TabItem
    @ObservedObject var appLanguage: AppLanguage

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 21))
                        Text(appLanguage.title(for: tab))
                            .font(.system(size: 10))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(selectedTab == tab ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appLanguage.title(for: tab))
            }
        }
        .frame(height: 49)
        .padding(.top, 4)
        .background(
            Color(uiColor: .systemBackground)
                .shadow(color: Color.black.opacity(0.12), radius: 0, x: 0, y: -0.5)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
