// ZikrCommands.swift
// ZKR-52: команды нативного экрана «Зикр». Единственный писатель счёта — веб: native отправляет
// команду (window.zikrNative.tap / undo / reset), веб выполняет тот же код, что веб-экран, сохраняет
// состояние ("save" → progress.json + zikr-state.json) и возвращает снимок для сверки UI.

import Foundation

/// Сброс из диалога «Обнулить счётчик?» (openResetDialog(): data-r="counter" | "all").
public enum ZikrResetMode: String, Codable, Sendable, CaseIterable {
    /// Только счётчик — главы остаются.
    case counter
    /// Счётчик и главы — начать путь заново.
    case all
}

/// Ответ веба на команду: состояние счётчика сразу после записи (zikrSnapshot() в index.html).
public struct ZikrSnapshot: Codable, Equatable, Sendable {
    public var total: Int64
    /// daily[dayKey()] на момент команды.
    public var today: Int64
    /// dayKey() веба ("yyyy-MM-dd").
    public var day: String
    public var unlocked: [String]
    /// Главы, открытые именно этой командой (evaluate()), по порядку порогов.
    public var fresh: [String]
    /// state.updatedAt после persist(): по нему сверяются снимки zikr-state.json (более старые не применяются).
    public var updatedAt: Int64

    public init(total: Int64, today: Int64, day: String, unlocked: [String], fresh: [String] = [], updatedAt: Int64) {
        self.total = total
        self.today = today
        self.day = day
        self.unlocked = unlocked
        self.fresh = fresh
        self.updatedAt = updatedAt
    }
}

/// Канал команд к единственному писателю счёта (веб-странице). nil / false — команда не выполнена
/// (страница не ответила, total уже 0 и т. п.).
public protocol ZikrCommandSink: Sendable {
    func tap() async -> ZikrSnapshot?
    func undo() async -> ZikrSnapshot?
    func reset(_ mode: ZikrResetMode) async -> ZikrSnapshot?
    @discardableResult func clearHistory() async -> Bool
    /// «Изучить» в баннере открытой главы (explore(ch) в вебе: карта или «Путь Сиры»).
    @discardableResult func explore(chapterID: String) async -> Bool
}
