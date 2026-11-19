// AppContainer.swift
// ZKR-59: native writer; legacy-миграция завершена до показа экранов.
// Legacy-флаги оставлены до удаления старого каркаса после QA.

import Foundation
import UIKit
import ZikrContent
import ZikrDomain
import ZikrPersistence

@MainActor
final class AppContainer: ObservableObject {
    /// Старый веб-каркас отключён; NativeRootView от этого флага не зависит.
    static let isWebMirrorEnabled = false
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
    /// ZKR-57: false → вкладка «Карта» снова целиком веб-экран (как 1.1.1), переходы из «Пути Сиры»
    /// и «Зикра» — снова через веб (showChapter / explore). Работает только вместе с isWebMirrorEnabled.
    static let isNativeMapEnabled = true
    static let isNativeOnboardingEnabled: Bool = {
#if DEBUG
        if ProcessInfo.processInfo.environment["ZIKR_UITEST_AUTH"] == "guest",
           ProcessInfo.processInfo.environment["ZIKR_UITEST_WEB_ONBOARDING"] == "1" { return false }
#endif
        return true
    }()

    func makeOnboardingViewModel() -> OnboardingViewModel {
        OnboardingViewModel(sink: nativeCommands, settings: settingsSink, localization: localization,
                            initialStatus: startupOnboardingStatus)
    }

    @Published private(set) var isNativeReady = false
    @Published private(set) var hasStartupError = false
    private var isBootstrapping = false
    private var startupOnboardingStatus: OnboardingStatus?
    let nativeCommands: NativeCommandSink
    private let legacyReader: (any LegacyStorageReading)?
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
    /// ZKR-57: команды экрана «Карта» в веб и сцены карт (ZikrContent/map-content.json).
    let mapSink: any MapCommandSink
    let mapContent: any MapContentProviding
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
        mapSink: (any MapCommandSink)? = nil,
        mapContent: any MapContentProviding = BundledMapContentProvider(),
        presenter: (any PresenterProviding)? = nil,
        legacyReader: (any LegacyStorageReading)? = nil
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
        self.zikrContent = zikrContent
        self.mapContent = mapContent
        self.legacyReader = legacyReader
        let catalog: NativeCommandCatalog?
        if let content = try? zikrContent.loadZikrContent(), let map = try? mapContent.loadMapContent() {
            catalog = NativeCommandCatalog(cityIDs: Set(map.cities.keys), chapterCities: Dictionary(
                uniqueKeysWithValues: content.chapters.compactMap { chapter in chapter.city.map { (chapter.id, $0) } }))
        } else { catalog = nil }
        let commands = NativeCommandSink(store: store, catalog: catalog)
        self.nativeCommands = commands
        self.settingsSink = settingsSink ?? commands
        self.zikrSink = zikrSink ?? commands
        self.siraSink = siraSink ?? commands
        self.mapSink = mapSink ?? commands
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

    /// ZKR-62: один контейнер на процесс, включая повторные SwiftUI App.init.
    /// StateObject и раннее зеркало всегда получают один экземпляр. Preview/init изолированы.
    static func live() -> AppContainer { liveContainer }

    /// Лениво создаётся без обращения к WebViewManager.shared (до Firebase.configure).
    private static let liveContainer: AppContainer = {
        // Не создаём каталог до разблокировки и никогда не подменяем постоянный путь временным.
        var stateURL = supportDirectory().appendingPathComponent(JSONStateStore.fileName)
#if DEBUG
        if ProcessInfo.processInfo.environment["ZIKR_UITEST_AUTH"] == "guest" {
            stateURL = stateURL.deletingLastPathComponent().appendingPathComponent("UITests/zikr-state.json")
            if let fixture = ProcessInfo.processInfo.environment["ZIKR_UITEST_ONBOARDING"], ["fresh", "completed"].contains(fixture) {
                let progress = ProgressState(total: 123, settings: AppSettings(lang: .en), onboarded: fixture == "completed")
                let document = StateDocument(progress: progress, meta: .init(createdAt: Date(), createdFrom: "uiTest",
                    writtenByAppVersion: appVersion(), nativeWriterActivated: true))
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                if let data = try? encoder.encode(document) {
                    try? FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try? data.write(to: stateURL, options: .atomic)
                }
            }
        }
#endif
        return AppContainer(
            stateFileURL: stateURL,
            legacyProgressFileURL: legacyProgressFileURL(),
            appVersion: appVersion()
        )
    }()

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

    /// Однократная активация native writer; UI остаётся закрытым при недоступных данных.
    func bootstrap() async {
        if isNativeReady {
            if let settings = await settings.load() {
                UIApplication.shared.isIdleTimerDisabled = settings.keepAwake && UIApplication.shared.applicationState == .active
            }
            return
        }
        guard !isBootstrapping else { return }
        isBootstrapping = true
        hasStartupError = false
        defer { isBootstrapping = false }
        do {
            guard UIApplication.shared.isProtectedDataAvailable else { throw CocoaError(.fileReadNoPermission) }
            guard nativeCommands.catalog != nil else { throw CocoaError(.fileReadCorruptFile) }
            await stateStore.retryUnreadableFile()
            if await stateStore.document()?.meta.nativeWriterActivated != true {
                let sourcesFromReader: LegacySources
#if DEBUG
                if ProcessInfo.processInfo.environment["ZIKR_UITEST_AUTH"] == "guest" {
                    sourcesFromReader = LegacySources()
                } else { sourcesFromReader = try await (legacyReader ?? LegacyStorageReader()).read() }
#else
                sourcesFromReader = try await (legacyReader ?? LegacyStorageReader()).read()
#endif
                var sources = sourcesFromReader
                var url = legacyProgressFileURL
#if DEBUG
                if ProcessInfo.processInfo.environment["ZIKR_UITEST_AUTH"] == "guest" { url = nil }
#endif
                sources.progressFileJSON = try await Task.detached(priority: .utility) {
                    guard let url else { return nil as String? }
                    do {
                        let data = try Data(contentsOf: url)
                        guard let value = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadCorruptFile) }
                        return value
                    } catch let error as CocoaError where error.code == .fileReadNoSuchFile { return nil }
                }.value
                try await stateStore.activateNative(sources)
            }
            guard let progress = await stateStore.document()?.progress else { throw CocoaError(.fileReadUnknown) }
            startupOnboardingStatus = OnboardingStatus(onboarded: progress.onboarded, language: progress.settings.lang.rawValue)
            localization.setLanguage(progress.settings.lang)
            auth.activate()
            isNativeReady = true
        } catch {
            hasStartupError = true
        }
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

    /// ZKR-57: модель экрана «Карта».
    func makeMapViewModel() -> MapViewModel {
        MapViewModel(
            repository: progress,
            sink: mapSink,
            mapContentProvider: mapContent,
            contentProvider: zikrContent,
            localization: localization
        )
    }

    /// Application Support/progress.json — файл, который ведёт ProgressFileStore.
    nonisolated static func legacyProgressFileURL() -> URL? {
        supportDirectory().appendingPathComponent("progress.json")
    }

    nonisolated private static func supportDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent("Library/Application Support", isDirectory: true)
    }

    private static func appVersion() -> String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    }
}
