import Foundation

/// Civil dates use UTC day ordinals; phone timezone is used only to extract today's Y/M/D.
/// This is an offline calculated calendar, not verification of a local moon announcement.
public struct HijriMonth: Hashable, Codable, Sendable, Identifiable {
    public let year: Int
    public let month: Int
    public var id: Int { year * 12 + month - 1 }
    public init(year: Int, month: Int) { self.year = year; self.month = month }
}

public struct HijriAnchor: Codable, Equatable, Sendable {
    public let month: HijriMonth
    public let day: Int
    public init(month: HijriMonth, day: Int) { self.month = month; self.day = day }
}

public enum HijriCalendarError: Error { case invalidAnchor, incompatibleAnchors }
public enum HijriEvent: String, CaseIterable, Sendable {
    case ramadan, eidFitr, arafah, eidAdha
    public var month: Int { switch self { case .ramadan: return 9; case .eidFitr: return 10; default: return 12 } }
    public var day: Int { switch self { case .arafah: return 9; case .eidAdha: return 10; default: return 1 } }
}

public struct HijriCalendarEngine: Sendable {
    public static var civil: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        c.firstWeekday = 2
        return c
    }
    private static var islamic: Calendar {
        var c = Calendar(identifier: .islamicUmmAlQura)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }
    public static func ordinal(_ date: Date, timeZone: TimeZone = .current) -> Int {
        var c = civil; c.timeZone = timeZone
        let parts = c.dateComponents([.year, .month, .day], from: date)
        return Int(civil.date(from: parts)!.timeIntervalSince1970 / 86400)
    }
    public static func date(_ day: Int) -> Date { Date(timeIntervalSince1970: Double(day) * 86400) }
    public static func day(year: Int, month: Int, day: Int) -> Int {
        Int(civil.date(from: DateComponents(year: year, month: month, day: day))!.timeIntervalSince1970 / 86400)
    }
    public static let bounds = day(year: 2000, month: 1, day: 1)...day(year: 2050, month: 12, day: 31)
    private static let firstYear = 1419
    private static let lastYear = 1475
    private static let base: [Int] = (firstYear...lastYear).flatMap { year in
        (1...12).map { month in
            Int(islamic.date(from: DateComponents(year: year, month: month, day: 1))!.timeIntervalSince1970 / 86400)
        }
    }
    private let starts: [Int]
    public let anchors: [HijriAnchor]
    public init(anchors: [HijriAnchor] = []) throws {
        var fixed: [Int: Int] = [:]
        for anchor in anchors {
            guard (Self.firstYear..<Self.lastYear).contains(anchor.month.year), [9, 10, 12].contains(anchor.month.month) else { throw HijriCalendarError.invalidAnchor }
            let i = Self.index(anchor.month)
            guard [9, 10, 12].contains(anchor.month.month), Self.base.indices.contains(i),
                  Self.bounds.contains(anchor.day), abs(anchor.day - Self.base[i]) <= 2,
                  fixed[i] == nil else { throw HijriCalendarError.invalidAnchor }
            fixed[i] = anchor.day
        }
        // Ramadan and Dhul-Hijjah stay independent across years. Other boundaries may
        // move locally to keep every month 29/30 days; minimise total deviation from base.
        var costs: [Int: Int] = [0: 0]
        var parents: [[Int: Int]] = [[0: 0]]
        for i in 1..<Self.base.count {
            let month = i % 12 + 1
            let candidates: [Int]
            if let anchor = fixed[i] { candidates = [anchor - Self.base[i]] }
            else if month == 9 || month == 12 || i == Self.base.count - 1 { candidates = [0] }
            else { candidates = Array(-2...2) }
            var next: [Int: Int] = [:]; var previous: [Int: Int] = [:]
            for shift in candidates {
                for p in costs.keys.sorted() {
                    let length = Self.base[i] + shift - Self.base[i - 1] - p
                    guard length == 29 || length == 30 else { continue }
                    let cost = costs[p]! + abs(shift)
                    if cost < (next[shift] ?? Int.max) { next[shift] = cost; previous[shift] = p }
                }
            }
            guard !next.isEmpty else { throw HijriCalendarError.incompatibleAnchors }
            costs = next; parents.append(previous)
        }
        var shift = costs.keys.min { (costs[$0]!, $0) < (costs[$1]!, $1) }!
        var result = Self.base
        for i in stride(from: result.count - 1, through: 1, by: -1) {
            result[i] += shift; shift = parents[i][shift]!
        }
        starts = result; self.anchors = anchors
    }
    private static func index(_ month: HijriMonth) -> Int { (month.year - firstYear) * 12 + month.month - 1 }
    public func baseline(_ month: HijriMonth) -> Int { Self.base[Self.index(month)] }
    public func start(_ month: HijriMonth) -> Int { starts[Self.index(month)] }
    public func days(_ month: HijriMonth) -> Range<Int> {
        let i = Self.index(month); return starts[i]..<starts[i + 1]
    }
    public func month(on day: Int) -> HijriMonth {
        let i = max(0, min(starts.count - 2, starts.partitionIndex { $0 > day } - 1))
        return HijriMonth(year: Self.firstYear + i / 12, month: i % 12 + 1)
    }
    public func number(on day: Int) -> Int { day - start(month(on: day)) + 1 }
    public var months: [HijriMonth] {
        (0..<(starts.count - 1)).compactMap { i in
            guard starts[i] <= Self.bounds.upperBound && starts[i + 1] > Self.bounds.lowerBound else { return nil }
            return HijriMonth(year: Self.firstYear + i / 12, month: i % 12 + 1)
        }
    }
    public func event(on day: Int) -> HijriEvent? {
        let m = month(on: day)
        return HijriEvent.allCases.first { $0.month == m.month && $0.day == number(on: day) }
    }
    public func isAdjusted(_ month: HijriMonth) -> Bool {
        let i = Self.index(month)
        return starts[i] != Self.base[i] || starts[i + 1] != Self.base[i + 1]
    }
    public func isUserDate(_ month: HijriMonth) -> Bool { anchors.contains { $0.month == month } }
    public func isEidPending(year: Int) -> Bool {
        isUserDate(.init(year: year, month: 9)) && !isUserDate(.init(year: year, month: 10))
    }
}

private extension Array where Element == Int {
    func partitionIndex(where predicate: (Int) -> Bool) -> Int {
        var low = 0; var high = count
        while low < high { let mid = (low + high) / 2; if predicate(self[mid]) { high = mid } else { low = mid + 1 } }
        return low
    }
}

/// Isolated preferences: no progress keys, account IDs or coordinates are read or written.
public final class HijriCalendarPreferences {
    public static let key = "calendar.hijri.anchors.v1"
    private let defaults: UserDefaults
    public init(defaults: UserDefaults) { self.defaults = defaults }
    public func load() throws -> HijriCalendarEngine {
        guard let data = defaults.data(forKey: Self.key) else { return try HijriCalendarEngine() }
        return try HijriCalendarEngine(anchors: JSONDecoder().decode([HijriAnchor].self, from: data))
    }
    @discardableResult public func save(_ anchors: [HijriAnchor]) throws -> HijriCalendarEngine {
        let engine = try HijriCalendarEngine(anchors: anchors)
        let data = try JSONEncoder().encode(anchors)
        defaults.set(data, forKey: Self.key)
        return engine
    }
}
