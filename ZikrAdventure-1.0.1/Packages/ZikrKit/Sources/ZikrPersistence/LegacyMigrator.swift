// LegacyMigrator.swift
// Выбор исходного состояния при первом запуске: повторяет логику страницы
// (loadLocal() + сравнение с window.__ZIKR_NATIVE_STATE), строки ~778–792 index.html.

import Foundation
import ZikrDomain

public enum LegacyMigrator {
    public enum Source {
        public static let progressFile = "progressFile"
        public static let webLive = "webLive"
        public static let localStorageV2 = "localStorageV2"
        public static let localStorageV1 = "localStorageV1"
        public static let fresh = "fresh"
    }

    /// Возвращает состояние и название источника либо nil, если данных нет.
    public static func resolve(_ sources: LegacySources, preferredLanguages: [String]) -> (ProgressState, String)? {
        // 1. Живое состояние страницы — самый свежий источник.
        if let liveText = sources.webLiveJSON, let live = JSONValue.parse(liveText), live.objectValue != nil {
            return (LegacySanitizer.sanitize(live, preferredLanguages: preferredLanguages), Source.webLive)
        }

        let local = loadLocal(sources, preferredLanguages: preferredLanguages)
        let native = loadNative(sources, preferredLanguages: preferredLanguages)

        switch (local, native) {
        case let (.some(l), .some(n)):
            let state = l.state, backup = n
            // (state.updatedAt || backup.updatedAt) ? (state.updatedAt >= backup.updatedAt ? state : backup) : merge
            if isTruthy(state.updatedAt) || isTruthy(backup.updatedAt) {
                if let su = state.updatedAt, let bu = backup.updatedAt, su >= bu {
                    return (state, l.source)
                }
                return (backup, Source.progressFile)
            }
            return (StateMerger.merge(state, backup, preferredLanguages: preferredLanguages), l.source)
        case let (.some(l), .none):
            return (l.state, l.source)
        case let (.none, .some(n)):
            return (n, Source.progressFile)
        case (.none, .none):
            return nil
        }
    }

    /// Порт loadLocal(). nil — в localStorage нет ни v2, ни v1.
    static func loadLocal(_ sources: LegacySources, preferredLanguages: [String]) -> (state: ProgressState, source: String)? {
        if let v2 = sources.localStorageV2, !v2.isEmpty {
            guard let parsed = JSONValue.parse(v2) else {
                // JSON.parse бросает → catch → freshState(); v1 уже не читается.
                return (ProgressState.fresh(preferredLanguages: preferredLanguages), Source.fresh)
            }
            return (LegacySanitizer.sanitize(parsed, preferredLanguages: preferredLanguages), Source.localStorageV2)
        }
        guard let v1Text = sources.localStorageV1, !v1Text.isEmpty else { return nil }
        guard let v1Value = JSONValue.parse(v1Text) else {
            return (ProgressState.fresh(preferredLanguages: preferredLanguages), Source.fresh)
        }
        guard let v1 = v1Value.objectValue else { return nil }

        // sanitize({ total, daily, onboarded }); settings = { ...s.settings, ...v1.settings, lang: s.settings.lang }; sanitize(s)
        let defaults = AppSettings.defaults(preferredLanguages: preferredLanguages)
        var settings: [String: JSONValue] = (StateMerger.encodeSettings(defaults)) ?? [:]
        if let v1Settings = v1["settings"]?.objectValue {
            for (key, value) in v1Settings { settings[key] = value }
        }
        settings["lang"] = .string(defaults.lang.rawValue)

        var object: [String: JSONValue] = ["settings": .object(settings)]
        if let total = v1["total"] { object["total"] = total }
        if let daily = v1["daily"] { object["daily"] = daily }
        if let onboarded = v1["onboarded"] { object["onboarded"] = onboarded }
        return (LegacySanitizer.sanitize(.object(object), preferredLanguages: preferredLanguages), Source.localStorageV1)
    }

    /// window.__ZIKR_NATIVE_STATE: объект из progress.json или nil.
    static func loadNative(_ sources: LegacySources, preferredLanguages: [String]) -> ProgressState? {
        guard let text = sources.progressFileJSON, let value = JSONValue.parse(text), value.objectValue != nil else {
            return nil
        }
        return LegacySanitizer.sanitize(value, preferredLanguages: preferredLanguages)
    }

    private static func isTruthy(_ value: Int64?) -> Bool {
        guard let value else { return false }
        return value != 0
    }
}

extension StateMerger {
    static func encodeSettings(_ settings: AppSettings) -> [String: JSONValue]? {
        guard let data = try? JSONEncoder().encode(settings) else { return nil }
        return JSONValue.parse(data)?.objectValue
    }
}
