import Foundation
import ZikrDomain
import ZikrPersistence

/// Единственный live sink после activateNative. WebViewManager не используется.
@MainActor
final class NativeCommandSink: ZikrCommandSink, SettingsCommandSink, SiraCommandSink, MapCommandSink, OnboardingCommandSink {
    let store: JSONStateStore
    let catalog: NativeCommandCatalog?
    init(store: JSONStateStore, catalog: NativeCommandCatalog?) { self.store = store; self.catalog = catalog }

    private func run(_ command: NativeProgressCommand) async -> NativeCommandResult? {
        guard let catalog else { return nil }
        return try? await store.execute(command, catalog: catalog)
    }
    func tap() async -> ZikrSnapshot? { await run(.tap)?.snapshot }
    func undo() async -> ZikrSnapshot? { await run(.undo)?.snapshot }
    func reset(_ mode: ZikrResetMode) async -> ZikrSnapshot? { await run(.reset(mode))?.snapshot }
    func clearHistory() async -> Bool { await run(.clearHistory) != nil }
    func explore(chapterID: String) async -> Bool { await run(.explore(chapterID)) != nil }
    func markViewed(chapterID: String) async -> Bool { await run(.markViewed(chapterID)) != nil }
    func showChapter(chapterID: String) async -> Bool { await run(.openChapter(chapterID)) != nil }
    func selectCity(_ cityID: String?) async -> Bool { await run(.selectCity(cityID)) != nil }
    func saveCamera(cityID: String, x: Double, y: Double, z: Double) async -> Bool {
        await run(.saveCamera(cityID, .init(x: x, y: y, z: z))) != nil
    }
    func set(_ field: SettingsField) async -> Bool { await run(.setSetting(field)) != nil }
    func setLanguage(_ language: AppLanguage) async -> Bool { await run(.setLanguage(language)) != nil }
    func resetDefaults() async -> Bool { await run(.resetDefaults) != nil }
    func resetProgress() async -> Bool { await run(.resetProgress) != nil }
    func complete() async -> Bool { await run(.completeOnboarding) != nil }
    func status() async -> OnboardingStatus? {
        guard let document = await store.document(), document.meta.nativeWriterActivated == true else { return nil }
        return OnboardingStatus(onboarded: document.progress.onboarded, language: document.progress.settings.lang.rawValue)
    }
}
