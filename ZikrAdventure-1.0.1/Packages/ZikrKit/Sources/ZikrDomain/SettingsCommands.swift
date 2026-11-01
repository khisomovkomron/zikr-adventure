// SettingsCommands.swift
// ZKR-50: команды нативного экрана «Настройки». Единственный писатель настроек — веб:
// нативный экран отправляет команду (window.zikrNative.*), веб применяет её и сохраняет,
// зеркало (ZKR-49) пишет результат в zikr-state.json, экран получает его из changes().

import Foundation

/// Переключатели экрана настроек — ключи state.settings в index.html.
/// `preview` сюда не входит: в приложении блок «Предпросмотр» скрыт (IS_APP).
public enum SettingsToggle: String, CaseIterable, Sendable {
    case haptics, sound, animations, banners, translit, translation, keepAwake, goalOn
}

/// Личная цель на день: те же границы и шаг, что в index.html (кнопки −/+).
public enum GoalRules {
    public static let minimum = 10
    public static let maximum = 10_000
    public static let step = 10

    /// Только границы 10…10000, без округления до шага 10 — как раньше в index.html
    /// (`applySetting("goal", …)`, кнопки −/+). Сохранённое значение не меняется.
    public static func clamp(_ value: Int) -> Int {
        min(maximum, max(minimum, value))
    }

    /// Кнопки −/+: `Math.max(10, goal - 10)` / `Math.min(10000, goal + 10)`.
    public static func stepped(_ goal: Int, by delta: Int) -> Int {
        min(maximum, max(minimum, goal + delta))
    }
}

/// Одно изменение настройки.
public enum SettingsField: Equatable, Sendable {
    case toggle(SettingsToggle, Bool)
    case goal(Int)

    /// Ключ в state.settings.
    public var key: String {
        switch self {
        case .toggle(let toggle, _): return toggle.rawValue
        case .goal: return "goal"
        }
    }

    /// Оптимистичное применение к локальной копии (до подтверждения из zikr-state.json).
    public func apply(to settings: inout AppSettings) {
        switch self {
        case .toggle(let toggle, let value): settings[toggle] = value
        case .goal(let value): settings.goal = GoalRules.clamp(value)
        }
    }
}

public extension AppSettings {
    subscript(toggle: SettingsToggle) -> Bool {
        get {
            switch toggle {
            case .haptics: return haptics
            case .sound: return sound
            case .animations: return animations
            case .banners: return banners
            case .translit: return translit
            case .translation: return translation
            case .keepAwake: return keepAwake
            case .goalOn: return goalOn
            }
        }
        set {
            switch toggle {
            case .haptics: haptics = newValue
            case .sound: sound = newValue
            case .animations: animations = newValue
            case .banners: banners = newValue
            case .translit: translit = newValue
            case .translation: translation = newValue
            case .keepAwake: keepAwake = newValue
            case .goalOn: goalOn = newValue
            }
        }
    }
}

/// Канал команд к единственному писателю настроек (веб-странице).
/// Возвращает true, если веб принял команду; false — команда не выполнена
/// (страница не ответила, ключ не из белого списка и т. п.).
public protocol SettingsCommandSink: Sendable {
    @discardableResult func set(_ field: SettingsField) async -> Bool
    @discardableResult func setLanguage(_ language: AppLanguage) async -> Bool
    @discardableResult func resetDefaults() async -> Bool
    @discardableResult func clearHistory() async -> Bool
    @discardableResult func resetProgress() async -> Bool
}
