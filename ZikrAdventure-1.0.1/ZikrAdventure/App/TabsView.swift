// TabsView.swift
// Корневой экран: один shared WKWebView сверху и нативный tab bar снизу.
// TabView не используется — его непрозрачный фон перекрывал web view и перехватывал нажатия.
// ZKR-48: вкладка «Инфо» — нативный экран поверх web view (веб под ним остаётся на вкладке info).
// ZKR-50: так же устроена вкладка «Настройки»; язык интерфейса — LocalizationService из AppContainer.
// ZKR-52: и главная вкладка «Зикр» (счётчик); шестерёнка и «Карта» выбирают нативную вкладку.
// Пока показан веб-онбординг или его состояние неизвестно, видна веб-версия, как в 1.1.1.

import SwiftUI
import ZikrContent
import ZikrDomain

struct TabsView: View {
    @State private var selectedTab: TabItem = .zikr
    @ObservedObject private var localization: LocalizationService
    @StateObject private var infoViewModel: InfoViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    @StateObject private var zikrViewModel: ZikrViewModel
    @State private var webOnboarding = WebOnboardingTracker()
    private let auth: any AuthService
#if DEBUG
    @State private var showsUIKitGallery = false
#endif

    /// Интервал опроса веб-онбординга, пока его состояние не «завершён».
    private static let onboardingPollInterval: UInt64 = 500_000_000

    init(container: AppContainer) {
        localization = container.localization
        auth = container.auth
        _infoViewModel = StateObject(wrappedValue: container.makeInfoViewModel(
            language: container.localization.language.rawValue
        ))
        _settingsViewModel = StateObject(wrappedValue: container.makeSettingsViewModel())
        _zikrViewModel = StateObject(wrappedValue: container.makeZikrViewModel())
    }

    private var isNativeInfoAvailable: Bool {
        AppContainer.isNativeInfoEnabled && infoViewModel.isAvailable
    }

    /// ZKR-50: экран читает zikr-state.json, поэтому без зеркала остаётся веб-версия.
    private var isNativeSettingsAvailable: Bool {
        AppContainer.isWebMirrorEnabled && AppContainer.isNativeSettingsEnabled && settingsViewModel.isAvailable
    }

    /// ZKR-52: экран читает zikr-state.json, поэтому без зеркала остаётся веб-версия.
    private var isNativeZikrAvailable: Bool {
        AppContainer.isWebMirrorEnabled && AppContainer.isNativeZikrEnabled && zikrViewModel.isAvailable
    }

    private var showsNativeZikr: Bool {
        NativeScreenGate.shouldShowNativeScreen(
            isEnabled: isNativeZikrAvailable,
            isTabSelected: selectedTab == .zikr,
            isWebOnboardingVisible: webOnboarding.isVisible
        )
    }

    private var showsNativeInfo: Bool {
        NativeScreenGate.shouldShowNativeScreen(
            isEnabled: isNativeInfoAvailable,
            isTabSelected: selectedTab == .info,
            isWebOnboardingVisible: webOnboarding.isVisible
        )
    }

    private var showsNativeSettings: Bool {
        NativeScreenGate.shouldShowNativeScreen(
            isEnabled: isNativeSettingsAvailable,
            isTabSelected: selectedTab == .settings,
            isWebOnboardingVisible: webOnboarding.isVisible
        )
    }

    /// Опрос нужен, пока онбординг не завершён: при старте (состояние неизвестно)
    /// и пока выбрана нативная вкладка с открытым онбордингом.
    private var needsOnboardingPoll: Bool {
        guard isNativeInfoAvailable || isNativeSettingsAvailable || isNativeZikrAvailable,
              webOnboarding.isVisible != false else { return false }
        return webOnboarding.isVisible == nil
            || (selectedTab == .info && isNativeInfoAvailable)
            || (selectedTab == .settings && isNativeSettingsAvailable)
            || (selectedTab == .zikr && isNativeZikrAvailable)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                WebHostView(selectedTab: $selectedTab, auth: auth, localization: localization)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: .top)
                    .accessibilityHidden(showsNativeInfo || showsNativeSettings || showsNativeZikr)

                if showsNativeZikr {
                    ZikrView(viewModel: zikrViewModel) { tab in
                        selectedTab = tab
                    }
                }
                if showsNativeInfo {
                    InfoView(viewModel: infoViewModel)
                }
                if showsNativeSettings {
                    SettingsView(viewModel: settingsViewModel)
                }
            }

#if DEBUG
            NativeTabBar(
                selectedTab: $selectedTab,
                localization: localization,
                onDebugLongPress: { showsUIKitGallery = true },
                debugGalleryPresented: showsUIKitGallery
            )
#else
            NativeTabBar(selectedTab: $selectedTab, localization: localization)
#endif
        }
        .onChange(of: selectedTab) { newTab in
            WebViewManager.shared.selectTab(newTab.webID)
            if newTab == .info {
                Task { await infoViewModel.refreshSettings() }
            } else {
                infoViewModel.closeSheet()
            }
            if newTab != .zikr {
                // Лист «История» закрывается при уходе с вкладки (как лист «Инфо»).
                zikrViewModel.closeHistory()
            }
        }
        .onChange(of: localization.language) { language in
            infoViewModel.setLanguage(language.rawValue)
        }
        .task {
            // ZKR-50: настройки и аккаунт читаются всё время жизни экрана (не только на вкладке).
            await settingsViewModel.start()
        }
        .task {
            // ZKR-52: счётчик и настройки экрана «Зикр» читаются всё время жизни экрана.
            await zikrViewModel.start()
        }
        .task(id: needsOnboardingPoll) {
            guard needsOnboardingPoll else { return }
            while !Task.isCancelled {
                webOnboarding.record(await WebViewManager.shared.isOnboardingVisible())
                if webOnboarding.isVisible == false { break }
                try? await Task.sleep(nanoseconds: Self.onboardingPollInterval)
            }
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
    let auth: any AuthService
    let localization: LocalizationService

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedTab: $selectedTab)
    }

    func makeUIViewController(context: Context) -> WebAppViewController {
        let manager = WebViewManager.shared
        let controller = manager.viewController
        controller.localization = localization
        if controller.authService == nil {
            controller.authService = auth
        }
        // FirebaseApp.configure() уже выполнен в AppDelegate.
        auth.activate()
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
        controller.localization = localization
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
    @ObservedObject var localization: LocalizationService
    var onDebugLongPress: (() -> Void)? = nil
    var debugGalleryPresented: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases) { tab in
                TabBarButton(
                    tab: tab,
                    title: localization.tr(tab.titleKey),
                    isSelected: selectedTab == tab,
                    onDebugLongPress: onDebugLongPress,
                    debugGalleryPresented: debugGalleryPresented
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
    var debugGalleryPresented: Bool = false
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
        .accessibilityIdentifier("tab.\(tab.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityRemoveTraits(isSelected ? [] : .isSelected)
#if DEBUG
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 1.2).onEnded { _ in
                guard let onDebugLongPress else { return }
                ignoreNextSelect = true
                onDebugLongPress()
            }
        )
        .onChange(of: debugGalleryPresented) { presented in
            if !presented {
                ignoreNextSelect = false
            }
        }
#endif
    }

    private func selectIfTap() {
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
        @StateObject private var localization = LocalizationService(defaults: nil)

        var body: some View {
            VStack {
                Spacer()
                NativeTabBar(selectedTab: $selected, localization: localization)
            }
            .background(Theme.Color.bg)
        }
    }
}
