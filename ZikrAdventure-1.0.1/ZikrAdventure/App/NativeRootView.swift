import SwiftUI
import ZikrDomain

/// До успешной миграции нет ни доступных команд, ни вспышки пустого прогресса/онбординга.
struct NativeRootView: View {
    @ObservedObject var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase
    @ViewBuilder var body: some View {
#if DEBUG
        // Unit-host не запускает реальную миграцию параллельно тестам с собственными источниками.
        // UI-тесты явно выбирают гостевой профиль и проверяют настоящий корень приложения.
        if (ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil),
           ProcessInfo.processInfo.environment["ZIKR_UITEST_AUTH"] == nil {
            Color.clear
        } else { content }
#else
        content
#endif
    }
    private var content: some View {
        ZStack {
            if container.isNativeReady { NativeTabsView(container: container) }
            else if container.hasStartupError {
                VStack(spacing: 20) {
                    Text(container.localization.tr(.startupRestoreFailed)).accessibilityIdentifier("startup.error")
                    Button(container.localization.tr(.authRetry)) { Task { await container.bootstrap() } }
                        .accessibilityIdentifier("startup.retry")
                }.padding()
            } else { ProgressView().tint(Theme.Color.accent).accessibilityIdentifier("startup.loading") }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await container.bootstrap() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { Task { await container.bootstrap() } }
            else { UIApplication.shared.isIdleTimerDisabled = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            Task { await container.bootstrap() }
        }
    }
}

private struct NativeTabsView: View {
    let container: AppContainer
    @State private var selected: TabItem = .zikr
    @ObservedObject private var localization: LocalizationService
    @StateObject private var info: InfoViewModel
    @StateObject private var settings: SettingsViewModel
    @StateObject private var zikr: ZikrViewModel
    @StateObject private var sira: SiraViewModel
    @StateObject private var map: MapViewModel
    @StateObject private var onboarding: OnboardingViewModel
#if DEBUG
    @State private var gallery = false
#endif
    init(container: AppContainer) {
        self.container = container
        localization = container.localization
        _info = StateObject(wrappedValue: container.makeInfoViewModel(language: container.localization.language.rawValue))
        _settings = StateObject(wrappedValue: container.makeSettingsViewModel())
        _zikr = StateObject(wrappedValue: container.makeZikrViewModel())
        _sira = StateObject(wrappedValue: container.makeSiraViewModel())
        _map = StateObject(wrappedValue: container.makeMapViewModel())
        _onboarding = StateObject(wrappedValue: container.makeOnboardingViewModel())
    }
    private var covered: Bool { onboarding.isVisible != false }
    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selected {
                case .zikr: ZikrView(viewModel: zikr) { selected = $0 }
                case .path: SiraView(viewModel: sira, progress: zikr)
                case .map: MapView(viewModel: map)
                case .info: InfoView(viewModel: info)
                case .settings: SettingsView(viewModel: settings)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(!covered).accessibilityHidden(covered)
            Group {
#if DEBUG
                NativeTabBar(selectedTab: $selected, localization: localization,
                             onDebugLongPress: { gallery = true }, debugGalleryPresented: gallery)
#else
                NativeTabBar(selectedTab: $selected, localization: localization)
#endif
            }.allowsHitTesting(!covered).accessibilityHidden(covered)
        }
        .fullScreenCover(isPresented: Binding(get: { covered }, set: { _ in })) {
            OnboardingView(viewModel: onboarding).interactiveDismissDisabled()
        }
        .onChange(of: selected) { tab in
            if tab == .info { Task { await info.refreshSettings() } } else { info.closeSheet() }
            if tab != .zikr { zikr.closeHistory() }
        }
        .onChange(of: localization.language) { info.setLanguage($0.rawValue) }
        .task { await settings.start() }
        .task { await zikr.start() }
        .task {
            zikr.openChapterNatively = { id in
                guard !covered else { return false }
                if sira.openFromBanner(id) { selected = .path; return true }
                if map.explore(id) { selected = .map; return true }
                return false
            }
            await sira.start()
        }
        .task {
            map.onSelectTab = { selected = $0 }
            sira.openOnMapNatively = { id, sheet in
                guard !covered else { return false }
                let opened = sheet ? map.explore(id, marksViewed: false) : map.showChapter(id)
                if opened { selected = .map }
                return opened
            }
            await map.start()
        }
        .task {
            let stream = await container.settings.changes()
            if let value = await container.settings.load() { updateSystemSettings(value) }
            for await value in stream { updateSystemSettings(value) }
        }
#if DEBUG
        .sheet(isPresented: $gallery) { UIKitGallery() }
#endif
    }
    private func updateSystemSettings(_ settings: AppSettings) {
        localization.setLanguage(settings.lang)
        UIApplication.shared.isIdleTimerDisabled = settings.keepAwake && UIApplication.shared.applicationState == .active
    }
}
