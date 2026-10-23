// TabsView.swift
// Корневой экран: один shared WKWebView сверху и нативный tab bar снизу.
// TabView не используется — его непрозрачный фон перекрывал web view и перехватывал нажатия.

import SwiftUI

struct TabsView: View {
    @State private var selectedTab: TabItem = .zikr
    @StateObject private var appLanguage = AppLanguage()
#if DEBUG
    @State private var showsUIKitGallery = false
#endif

    var body: some View {
        VStack(spacing: 0) {
            WebHostView(selectedTab: $selectedTab, appLanguage: appLanguage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .top)

#if DEBUG
            NativeTabBar(
                selectedTab: $selectedTab,
                appLanguage: appLanguage,
                onDebugLongPress: { showsUIKitGallery = true }
            )
#else
            NativeTabBar(selectedTab: $selectedTab, appLanguage: appLanguage)
#endif
        }
        .onChange(of: selectedTab) { newTab in
            WebViewManager.shared.selectTab(newTab.webID)
        }
#if DEBUG
        .sheet(isPresented: $showsUIKitGallery) {
            UIKitGallery()
        }
#endif
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
    var onDebugLongPress: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases) { tab in
                TabBarButton(
                    tab: tab,
                    title: appLanguage.title(for: tab),
                    isSelected: selectedTab == tab,
                    onDebugLongPress: onDebugLongPress
                ) {
                    selectedTab = tab
                }
            }
        }
        .frame(height: Theme.Size.tabBar)
        .padding(.top, Theme.Size.tabBarTopPadding)
        .background(
            Theme.Color.surface
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Theme.Color.divider.frame(height: Theme.Size.hairline)
        }
        .dynamicTypeSize(...DynamicTypeSize.large)
        .accessibilityElement(children: .contain)
    }
}

private struct TabBarButton: View {
    let tab: TabItem
    let title: String
    let isSelected: Bool
    var onDebugLongPress: (() -> Void)? = nil
    let action: () -> Void
#if DEBUG
    @State private var ignoreNextSelect = false
#endif

    var body: some View {
        Button(action: selectIfTap) {
            VStack(spacing: Theme.Size.tabGap) {
                Image(tab.iconName)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Theme.Size.iconTab, height: Theme.Size.iconTab)
                    .accessibilityHidden(true)
                Text(title)
                    .themeFont(isSelected ? .tabSelected : .tab)
                    .lineLimit(1)
                    .minimumScaleFactor(Theme.Scale.tabTitle)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .foregroundColor(isSelected ? Theme.Color.accent : Theme.Color.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityRemoveTraits(isSelected ? [] : .isSelected)
#if DEBUG
        .onLongPressGesture(minimumDuration: 1.2) {
            guard let onDebugLongPress else { return }
            ignoreNextSelect = true
            onDebugLongPress()
        }
#endif
    }

    private func selectIfTap() {
        _ = onDebugLongPress
#if DEBUG
        if ignoreNextSelect {
            ignoreNextSelect = false
            return
        }
#endif
        action()
    }
}

struct NativeTabBar_Previews: PreviewProvider {
    static var previews: some View {
        ThemePreview.pair(name: "NativeTabBar") {
            NativeTabBarPreviewHost()
        }
    }

    private struct NativeTabBarPreviewHost: View {
        @State private var selected: TabItem = .zikr
        @StateObject private var language = AppLanguage()

        var body: some View {
            VStack {
                Spacer()
                NativeTabBar(selectedTab: $selected, appLanguage: language)
            }
            .background(Theme.Color.bg)
        }
    }
}
