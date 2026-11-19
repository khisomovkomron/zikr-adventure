import Foundation
import ZikrCore

/// ZKR-59/A: данные команд без зависимости от DOM, WebKit и локализованных строк.
/// Подключать к UI только после миграции и отключения веб-писателя.
public enum NativeProgressCommand: Sendable {
    case tap, undo, reset(ZikrResetMode)
    case setSetting(SettingsField), setLanguage(AppLanguage), resetDefaults
    case clearHistory, resetProgress, completeOnboarding
    case markViewed(String), openChapter(String), explore(String)
    case selectCity(String?), saveCamera(String, CameraPosition)
}

/// Связи из ZikrContent инжектируются composition root, не копируются в Domain.
public struct NativeCommandCatalog: Sendable {
    public let cityIDs: Set<String>
    public let chapterCities: [String: String]

    public init(cityIDs: Set<String>, chapterCities: [String: String]) {
        self.cityIDs = cityIDs
        self.chapterCities = chapterCities
    }
}

public enum NativeCommandError: Error, Equatable {
    case invalidState, timestampExhausted, notBootstrapped
}

public struct NativeCommandResult: Equatable, Sendable {
    public let progress: ProgressState
    public let fresh: [String]
    public let didChange: Bool
    public let day: String

    public var snapshot: ZikrSnapshot {
        ZikrSnapshot(total: progress.total, today: progress.daily[day] ?? 0, day: day,
                     unlocked: progress.unlocked, fresh: fresh, updatedAt: progress.updatedAt ?? 0)
    }
}

/// Чистый порт действий текущего веб-приложения. nil — недопустимая команда / undo при нуле.
/// Возвращаемый результат ещё не является подтверждением записи: это делает StateStore.
public enum NativeProgressReducer {
    public static func apply(
        _ command: NativeProgressCommand, to original: ProgressState,
        at now: Date, timeZone: TimeZone, catalog: NativeCommandCatalog
    ) throws -> NativeCommandResult? {
        guard now.timeIntervalSince1970.isFinite,
              (0...JSNumber.maxSafeInteger).contains(original.total),
              original.daily.values.allSatisfy({ (0...JSNumber.maxSafeInteger).contains($0) }) else {
            throw NativeCommandError.invalidState
        }
        let day = DayKey.string(for: now, timeZone: timeZone)
        var state = original
        var fresh: [String] = []
        var persists = true
        func canOpen(_ id: String) -> Bool {
            ChapterCatalog.ids.contains(id) && (original.settings.preview || original.unlocked.contains(id))
        }
        switch command {
        case .tap:
            state.total = min(JSNumber.maxSafeInteger, state.total + 1)
            // Как сохраняемый legacy-снимок после sanitize: никогда не выходим за safe integer.
            state.daily[day] = min(JSNumber.maxSafeInteger, (state.daily[day] ?? 0) + 1)
            fresh = ZikrProgress.freshChapters(total: state.total, unlocked: state.unlocked)
            state.unlocked += fresh
        case .undo:
            guard state.total > 0 else { return nil }
            state.total -= 1
            if let today = state.daily[day], today > 0 { state.daily[day] = today - 1 }
        case .reset(let mode):
            state.total = 0
            if mode == .all { state.unlocked = []; state.viewed = [] }
            // zikrReset сохраняет daily, settings, onboarded, city и cameras в обоих режимах.
        case .setSetting(let field): field.apply(to: &state.settings)
        case .setLanguage(let language): state.settings.lang = language
        case .resetDefaults: state.settings = AppSettings(lang: original.settings.lang)
        case .clearHistory:
            if let today = state.daily[day], today > 0 { state.daily = [day: today] }
            else { state.daily = [:] }
        case .resetProgress:
            state = ProgressState(settings: original.settings, onboarded: true)
        case .completeOnboarding:
            persists = !state.onboarded
            state.onboarded = true
        case .markViewed(let id):
            guard canOpen(id) else { return nil }
            persists = !state.viewed.contains(id)
            if persists { state.viewed.append(id) }
        case .openChapter(let id), .explore(let id):
            guard canOpen(id) else { return nil }
            let city = catalog.chapterCities[id]
            if case .openChapter = command, city == nil { return nil }
            if let city, !catalog.cityIDs.contains(city) { return nil }
            persists = !state.viewed.contains(id) || city != nil
            if !state.viewed.contains(id) { state.viewed.append(id) }
            if let city { state.city = city }
        case .selectCity(let id):
            if let id, !catalog.cityIDs.contains(id) { return nil }
            state.city = id
        case .saveCamera(let id, let camera):
            guard catalog.cityIDs.contains(id), [camera.x, camera.y, camera.z].allSatisfy(\.isFinite) else { return nil }
            // Геометрическое ограничение камеры выполняет слой карты, как native map до ZKR-59.
            state.cameras[id] = camera
        }
        if persists {
            let milliseconds = now.timeIntervalSince1970 * 1000
            guard milliseconds.isFinite, let wall = JSNumber.clampedInt64(milliseconds) else {
                throw NativeCommandError.invalidState
            }
            let previous = original.updatedAt ?? 0
            guard previous < JSNumber.maxSafeInteger else { throw NativeCommandError.timestampExhausted }
            state.updatedAt = max(wall, previous + 1)
        }
        return NativeCommandResult(progress: state, fresh: fresh, didChange: persists, day: day)
    }
}
