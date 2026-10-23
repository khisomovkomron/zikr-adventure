// AppContainer.swift
// Контейнер зависимостей нативного слоя данных (ZKR-49).
// Режим «тени»: native только зеркалирует состояние веб-страницы в zikr-state.json
// и ничего не пишет обратно в веб (progress.json и localStorage не трогаются).

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

    let stateStore: JSONStateStore
    let progress: any ProgressRepository
    let settings: any SettingsRepository
    let webStateMirror: WebStateMirror
    /// ZKR-48: тексты экрана «Инфо» (ZikrContent/info-content.json).
    let infoContent: any InfoContentProviding

    private let legacyProgressFileURL: URL?

    init(
        stateFileURL: URL,
        legacyProgressFileURL: URL?,
        appVersion: String,
        infoContent: any InfoContentProviding = BundledInfoContentProvider()
    ) {
        let store = JSONStateStore(fileURL: stateFileURL, appVersion: appVersion)
        self.stateStore = store
        self.progress = JSONProgressRepository(store: store)
        self.settings = JSONSettingsRepository(store: store)
        self.webStateMirror = WebStateMirror(store: store)
        self.legacyProgressFileURL = legacyProgressFileURL
        self.infoContent = infoContent
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
            appVersion: appVersion()
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

    /// Application Support/progress.json — файл, который ведёт ProgressFileStore.
    nonisolated static func legacyProgressFileURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("progress.json")
    }

    private static func appVersion() -> String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    }
}
