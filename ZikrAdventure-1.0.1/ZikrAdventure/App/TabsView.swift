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
/// Цвета — CSS-переменные веб-таббара: --surface, --divider, --accent, --text2.
struct NativeTabBar: View {
    @Binding var selectedTab: TabItem
    @ObservedObject var appLanguage: AppLanguage

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases) { tab in
                TabBarButton(
                    tab: tab,
                    title: appLanguage.title(for: tab),
                    isSelected: selectedTab == tab
                ) {
                    selectedTab = tab
                }
            }
        }
        .frame(height: 49)
        .padding(.top, 4)
        .background(
            Color("TabBarSurface")
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Color("TabBarDivider").frame(height: 1)
        }
    }
}

private struct TabBarButton: View {
    let tab: TabItem
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(tab.iconName)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 23, height: 23)
                Text(title)
                    .font(.system(size: 12))
                    .fontWeight(isSelected ? .bold : .regular)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .foregroundColor(isSelected ? Color.accentColor : Color("TabBarUnselected"))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityRemoveTraits(isSelected ? [] : .isSelected)
    }
}
