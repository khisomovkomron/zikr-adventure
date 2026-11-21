// LegacySanitizer.swift
// Точный порт sanitize(s) из index.html (строки ~764–777), с двумя осознанными отличиями,
// которые делают результат строго типизированным (см. комментарии «Отличие»):
//  • daily: дробные значения округляются вниз (в вебе остаются дробными);
//  • settings: значение неверного типа заменяется значением по умолчанию (в вебе остаётся как есть).
// Поле v всегда 2. Неизвестные ключи верхнего уровня отбрасываются.

import Foundation
import ZikrCore
import ZikrDomain

public enum LegacySanitizer {
    public static func sanitize(_ value: JSONValue?, preferredLanguages: [String]) -> ProgressState {
        let defaults = AppSettings.defaults(preferredLanguages: preferredLanguages)
        let s = value?.objectValue ?? [:]
        var out = ProgressState(settings: defaults)

        // total: Number.isFinite(total) && total > 0 ? min(floor(total), MAX_SAFE_INTEGER) : 0
        if let t = s["total"]?.numberValue, t.isFinite, t > 0 {
            out.total = JSNumber.clampedInt64(t) ?? 0
        }

        // daily: объект; удаляются нечисловые и отрицательные значения; 0 сохраняется.
        if let daily = s["daily"]?.objectValue {
            var result: [String: Int64] = [:]
            for (key, raw) in daily {
                guard let n = raw.numberValue, n.isFinite, n >= 0 else { continue }
                // Отличие: дробное значение округляется вниз, чтобы хранить Int64.
                result[key] = JSNumber.clampedInt64(n) ?? 0
            }
            out.daily = result
        }

        // unlocked: только известные id глав; порядок и повторы сохраняются (как filter в JS).
        if let unlocked = s["unlocked"]?.arrayValue {
            out.unlocked = unlocked.compactMap { $0.stringValue }.filter { ChapterCatalog.ids.contains($0) }
        }

        // viewed: только строки.
        if let viewed = s["viewed"]?.arrayValue {
            out.viewed = viewed.compactMap { $0.stringValue }
        }

        out.settings = sanitizeSettings(s["settings"], defaults: defaults)

        // onboarded: в вебе берётся как есть; в типизированной модели — Bool, иначе false.
        out.onboarded = s["onboarded"]?.boolValue ?? false

        // cameras: объект; записи без числовых x/y/z отбрасываются.
        if let cameras = s["cameras"]?.objectValue {
            var result: [String: CameraPosition] = [:]
            for (key, raw) in cameras {
                guard let x = raw["x"]?.numberValue, let y = raw["y"]?.numberValue, let z = raw["z"]?.numberValue,
                      x.isFinite, y.isFinite, z.isFinite else { continue }
                result[key] = CameraPosition(x: x, y: y, z: z)
            }
            out.cameras = result
        }

        out.city = s["city"]?.stringValue

        if let u = s["updatedAt"]?.numberValue, u.isFinite {
            out.updatedAt = JSNumber.clampedInt64(u)
        }

        out.v = 2
        return out
    }

    /// { ...DEFAULT_SETTINGS, ...(settings || {}) } + проверка lang + нормализация goal.
    static func sanitizeSettings(_ value: JSONValue?, defaults: AppSettings) -> AppSettings {
        let s = value?.objectValue ?? [:]
        var out = defaults
        // Отличие: значение неверного типа → значение по умолчанию.
        out.haptics = s["haptics"]?.boolValue ?? defaults.haptics
        out.sound = s["sound"]?.boolValue ?? defaults.sound
        out.animations = s["animations"]?.boolValue ?? defaults.animations
        out.banners = s["banners"]?.boolValue ?? defaults.banners
        out.translit = s["translit"]?.boolValue ?? defaults.translit
        out.translation = s["translation"]?.boolValue ?? defaults.translation
        out.keepAwake = s["keepAwake"]?.boolValue ?? defaults.keepAwake
        out.goalOn = s["goalOn"]?.boolValue ?? defaults.goalOn
        out.preview = s["preview"]?.boolValue ?? defaults.preview

        // if (!LANG_CODES.includes(lang)) lang = "ru". Отсутствующий lang → detectLang().
        if let raw = s["lang"] {
            out.lang = raw.stringValue.flatMap(AppLanguage.init(rawValue:)) ?? .ru
        } else {
            out.lang = defaults.lang
        }

        // goal = min(10000, max(10, Math.round(goal / 10) * 10 || 100)); нечисловое → 100.
        out.goal = normalizeGoal(s["goal"]?.numberValue ?? Double(defaults.goal))
        return out
    }

    static func normalizeGoal(_ goal: Double) -> Int {
        var g = JSNumber.round(goal / 10) * 10
        // `|| 100`: 0, -0 и NaN ложны в JS.
        if g == 0 || g.isNaN { g = 100 }
        g = Swift.min(10000, Swift.max(10, g))
        return Int(g)
    }
}
