// AppContainer.swift
// Контейнер зависимостей нативного слоя данных (ZKR-49).
// Режим «тени»: native только зеркалирует состояние веб-страницы в zikr-state.json
// и сам не пишет ни в progress.json, ни в localStorage.
// ZKR-50: настройки меняются только командами в веб (window.zikrNative.*) — веб остаётся
// единственным писателем; здесь же живут общие AuthService и LocalizationService.

import Foundation
import ZikrContent
import ZikrDomain
import ZikrPersistence

@MainActor
final class AppContainer: ObservableObject {
    /// Аварийный выключатель: false → зеркало не подключается, bootstrap не выполняется,
    /// приложение работает ровно как 1.1.1.
    static let isWebMirrorEnabled = true
    /// ZKR-48: false → вкладка «Инфо» снова целиком веб-экран (как 1.1.1).
    static let isNativeInfoEnabled = true
    /// ZKR-50: false → вкладка «Настройки» снова целиком веб-экран (как 1.1.1).
    /// Работает только вместе с isWebMirrorEnabled (экран читает zikr-state.json).
    static let isNativeSettingsEnabled = true
    /// ZKR-52: false → вкладка «Зикр» снова целиком веб-экран (как 1.1.1).
    /// Работает только вместе с isWebMirrorEnabled (экран читает zikr-state.json).
    static let isNativeZikrEnabled = true
    /// ZKR-53: false → вкладка «Путь Сиры» снова целиком веб-экран (как 1.1.1).
    /// Работает только вместе с isWebMirrorEnabled (экран читает zikr-state.json).
    static let isNativeSiraEnabled = true

    let stateStore: JSONStateStore
    let progress: any ProgressRepository
    let settings: any SettingsRepository
    let webStateMirror: WebStateMirror
    /// ZKR-48: тексты экрана «Инфо» (ZikrContent/info-content.json).
    let infoContent: any InfoContentProviding
    /// ZKR-50: единственный владелец авторизации (нативный экран и мост в веб).
    let auth: any AuthService
    /// ZKR-50: язык интерфейса и нативные строки (Localizable.xcstrings).
    let localization: LocalizationService
    /// ZKR-50: команды настроек в веб.
    let settingsSink: any SettingsCommandSink
    /// ZKR-52: команды счётчика в веб и тексты уровней/глав экрана «Зикр».
    let zikrSink: any ZikrCommandSink
    let zikrContent: any ZikrContentProviding
    /// ZKR-53: команды экрана «Путь Сиры» в веб (тексты глав и мест — тот же zikrContent).
    let siraSink: any SiraCommandSink
    let presenter: any PresenterProviding

    private let legacyProgressFileURL: URL?

    init(
        stateFileURL: URL,
        legacyProgressFileURL: URL?,
        appVersion: String,
        infoContent: any InfoContentProviding = BundledInfoContentProvider(),
        auth: (any AuthService)? = nil,
        localization: LocalizationService? = nil,
        settingsSink: (any SettingsCommandSink)? = nil,
        zikrSink: (any ZikrCommandSink)? = nil,
        zikrContent: any ZikrContentProviding = BundledZikrContentProvider(),
        siraSink: (any SiraCommandSink)? = nil,
        presenter: (any PresenterProviding)? = nil
    ) {
        let store = JSONStateStore(fileURL: stateFileURL, appVersion: appVersion)
        self.stateStore = store
        self.progress = JSONProgressRepository(store: store)
        self.settings = JSONSettingsRepository(store: store)
        self.webStateMirror = WebStateMirror(store: store)
        self.legacyProgressFileURL = legacyProgressFileURL
        self.infoContent = infoContent
        self.auth = auth ?? Self.makeAuthService()
        self.localization = localization ?? LocalizationService()
        self.settingsSink = settingsSink ?? WebSettingsCommandSink { WebViewManager.shared }
        self.zikrSink = zikrSink ?? WebZikrCommandSink(
            queries: { WebViewManager.shared },
            commands: { WebViewManager.shared }
        )
        self.zikrContent = zikrContent
        self.siraSink = siraSink ?? WebSiraCommandSink { WebViewManager.shared }
        self.presenter = presenter ?? KeyWindowPresenterProvider()
    }

    /// AuthCoordinator; в DEBUG-сборке UI-тесты подменяют его через ZIKR_UITEST_AUTH.
    private static func makeAuthService() -> any AuthService {
#if DEBUG
        if let stub = UITestAuthService.fromEnvironment(ProcessInfo.processInfo.environment) {
            return stub
        }
#endif
        return AuthCoordinator()
    }

    /// Application Support/zikr-state.json; версия из CFBundleShortVersionString.
    static func live() -> AppContainer {
        let stateURL = (try? JSONStateStore.defaultFileURL())
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("zikr-state.json")
        return AppContainer(
            stateFileURL: stateURL,
            legacyProgressFileURL: legacyProgressFileURL(),
            appVersion: appVersion()
        )
    }

    /// Временный каталог (FileManager.temporaryDirectory/UUID) — для превью и экспериментов.
    static func preview() -> AppContainer {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return AppContainer(
            stateFileURL: dir.appendingPathComponent("zikr-state.json"),
            legacyProgressFileURL: nil,
            appVersion: appVersion(),
            localization: LocalizationService(defaults: nil)
        )
    }

    /// Первичная миграция из Application Support/progress.json (только чтение).
    /// Существующий zikr-state.json не переписывается.
    func bootstrap() async {
        guard Self.isWebMirrorEnabled else { return }
        // ZKR-61: чтение progress.json — вне главного потока.
        let url = legacyProgressFileURL
        let sources = await Task.detached(priority: .utility) {
            url.map { LegacySources.progressFile(at: $0) } ?? LegacySources()
        }.value
        await stateStore.bootstrap(sources)
    }

    // MARK: - Фабрики view model (ZKR-64: DI в одном месте)

    /// ZKR-48/ZKR-64: модель экрана «Инфо» на стартовом языке.
    func makeInfoViewModel(language: String) -> InfoViewModel {
        InfoViewModel(provider: infoContent, settings: settings, language: language)
    }

    /// ZKR-50: модель экрана «Настройки».
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            repository: settings,
            sink: settingsSink,
            authService: auth,
            localization: localization,
            reduceMotion: SystemReduceMotionProvider(),
            urlOpener: SafariURLOpener(presenter: presenter),
            presenter: presenter
        )
    }

    /// ZKR-52: модель экрана «Зикр».
    func makeZikrViewModel() -> ZikrViewModel {
        ZikrViewModel(
            repository: progress,
            sink: zikrSink,
            contentProvider: zikrContent,
            localization: localization,
            feedback: ZikrFeedbackService(),
            announcer: VoiceOverAnnouncer()
        )
    }

    /// ZKR-53: модель экрана «Путь Сиры».
    func makeSiraViewModel() -> SiraViewModel {
        SiraViewModel(
            repository: progress,
            sink: siraSink,
            contentProvider: zikrContent,
            localization: localization
        )
    }

    /// Application Support/progress.json — файл, который ведёт ProgressFileStore.
    nonisolated static func legacyProgressFileURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("progress.json")
    }

    private static func appVersion() -> String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    }
}
