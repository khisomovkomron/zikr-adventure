// DayKey.swift
// Ключ дня "yyyy-MM-dd" в локальном часовом поясе — как dayKey() в index.html
// (getFullYear/getMonth/getDate), всегда в григорианском календаре.

import Foundation

public enum DayKey {
    public static func string(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let y = c.year ?? 0, m = c.month ?? 0, d = c.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}
