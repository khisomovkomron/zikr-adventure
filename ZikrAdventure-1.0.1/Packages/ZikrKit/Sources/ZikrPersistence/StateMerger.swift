// StateMerger.swift
// Порт mergeStates(a, b) из index.html (строки ~802–808).

import Foundation
import ZikrDomain

public enum StateMerger {
    /// preferredLanguages влияет только на значения по умолчанию для отсутствующих полей;
    /// у уже очищенных состояний все поля есть.
    public static func merge(
        _ a: ProgressState,
        _ b: ProgressState,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> ProgressState {
        // База — состояние с большим total (при равенстве — a), как { ...b, ...a } / { ...a, ...b }.
        let (base, other) = a.total >= b.total ? (a, b) : (b, a)
        var m = base
        // Отсутствующие у базы необязательные поля берутся у второго (поведение spread).
        if m.updatedAt == nil { m.updatedAt = other.updatedAt }

        m.total = max(a.total, b.total)

        var daily = b.daily
        for (key, n) in a.daily { daily[key] = max(n, daily[key] ?? 0) }
        m.daily = daily

        m.unlocked = orderedUnion(a.unlocked, b.unlocked)
        m.viewed = orderedUnion(a.viewed, b.viewed)
        m.onboarded = a.onboarded || b.onboarded
        return LegacySanitizer.sanitize(encodeToJSON(m), preferredLanguages: preferredLanguages)
    }

    /// [...new Set([...a, ...b])]: сначала a, затем новые из b, без повторов.
    static func orderedUnion(_ a: [String], _ b: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for item in a + b where !seen.contains(item) {
            seen.insert(item)
            out.append(item)
        }
        return out
    }

    static func encodeToJSON(_ state: ProgressState) -> JSONValue? {
        guard let data = try? JSONEncoder().encode(state) else { return nil }
        return JSONValue.parse(data)
    }
}
