import XCTest
@testable import ZikrCore

final class HijriCalendarTests: XCTestCase {
    func testEveryCivilDayAndMonthInSupportedRange() throws {
        let e = try HijriCalendarEngine()
        for m in e.months {
            XCTAssertTrue([29, 30].contains(e.days(m).count))
        }
        for day in HijriCalendarEngine.bounds {
            let m = e.month(on: day)
            XCTAssertTrue(e.days(m).contains(day))
            XCTAssertEqual(e.start(m) + e.number(on: day) - 1, day)
        }
        XCTAssertEqual(HijriCalendarEngine.bounds.count, 18628)
    }
    func testBaselineMatchesFoundationIncludingLeapDay() throws {
        let e = try HijriCalendarEngine()
        var c = Calendar(identifier: .islamicUmmAlQura); c.timeZone = TimeZone(secondsFromGMT: 0)!
        for d in [HijriCalendarEngine.bounds.lowerBound, HijriCalendarEngine.day(year: 2024, month: 2, day: 29), HijriCalendarEngine.bounds.upperBound] {
            let parts = c.dateComponents([.year, .month, .day], from: HijriCalendarEngine.date(d))
            XCTAssertEqual(e.month(on: d), .init(year: parts.year!, month: parts.month!))
            XCTAssertEqual(e.number(on: d), parts.day)
        }
    }
    func testRamadanCorrectionHasContiguousMonthsAndIndependentDhul() throws {
        let base = try HijriCalendarEngine()
        for delta in -2...2 {
            let ramadan = HijriMonth(year: 1448, month: 9)
            let anchors = [HijriAnchor(month: ramadan, day: base.start(ramadan) + delta)]
            let interval = base.start(.init(year: 1448, month: 12)) - base.start(ramadan) - delta
            if !(87...90).contains(interval) {
                XCTAssertThrowsError(try HijriCalendarEngine(anchors: anchors))
                continue
            }
            let e = try HijriCalendarEngine(anchors: anchors)
            XCTAssertEqual(e.start(ramadan), base.start(ramadan) + delta)
            XCTAssertEqual(e.start(.init(year: 1448, month: 12)), base.start(.init(year: 1448, month: 12)))
            XCTAssertEqual(e.start(.init(year: 1449, month: 9)), base.start(.init(year: 1449, month: 9)))
            for m in e.months {
                XCTAssertTrue([29, 30].contains(e.days(m).count))
                for day in e.days(m) { XCTAssertEqual(e.month(on: day), m) }
            }
            XCTAssertTrue(e.isEidPending(year: 1448))
        }
    }
    func testExplicitEidAndImpossibleLength() throws {
        let base = try HijriCalendarEngine()
        let r = HijriMonth(year: 1448, month: 9), s = HijriMonth(year: 1448, month: 10)
        let day = base.start(r)
        let e = try HijriCalendarEngine(anchors: [.init(month: r, day: day), .init(month: s, day: day + 30)])
        XCTAssertEqual(e.days(r).count, 30)
        XCTAssertFalse(e.isEidPending(year: 1448))
        XCTAssertThrowsError(try HijriCalendarEngine(anchors: [.init(month: r, day: day), .init(month: s, day: day + 28)]))
        XCTAssertThrowsError(try HijriCalendarEngine(anchors: [.init(month: r, day: day + 3)]))
        XCTAssertThrowsError(try HijriCalendarEngine(anchors: [.init(month: r, day: day), .init(month: r, day: day)]))
    }
    func testDhulEventsAndAnchorSerialization() throws {
        let base = try HijriCalendarEngine()
        let m = HijriMonth(year: 1448, month: 12)
        let anchors = [HijriAnchor(month: m, day: base.start(m) - 1)]
        let e = try HijriCalendarEngine(anchors: JSONDecoder().decode([HijriAnchor].self, from: JSONEncoder().encode(anchors)))
        XCTAssertEqual(e.event(on: e.start(m) + 8), .arafah)
        XCTAssertEqual(e.event(on: e.start(m) + 9), .eidAdha)
        XCTAssertEqual(e.start(.init(year: 1448, month: 9)), base.start(.init(year: 1448, month: 9)))
    }
    func testTodayRespectsPhoneTimeZoneAndDST() {
        let instant = ISO8601DateFormatter().date(from: "2026-11-21T23:30:00Z")!
        XCTAssertEqual(HijriCalendarEngine.ordinal(instant, timeZone: TimeZone(identifier: "Asia/Dushanbe")!), HijriCalendarEngine.day(year: 2026, month: 11, day: 22))
        XCTAssertEqual(HijriCalendarEngine.ordinal(instant, timeZone: TimeZone(identifier: "America/Los_Angeles")!), HijriCalendarEngine.day(year: 2026, month: 11, day: 21))
        let dst = ISO8601DateFormatter().date(from: "2026-03-08T10:30:00Z")!
        XCTAssertEqual(HijriCalendarEngine.ordinal(dst, timeZone: TimeZone(identifier: "America/Los_Angeles")!), HijriCalendarEngine.day(year: 2026, month: 3, day: 8))
    }
    func testPreferencesRestoreRejectAtomicallyAndLeaveProgressUntouched() throws {
        let suite = "HijriTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("existing-progress-fixture", forKey: "progress")
        let store = HijriCalendarPreferences(defaults: defaults)
        let m = HijriMonth(year: 1448, month: 9)
        let day = try store.load().start(m)
        _ = try store.save([.init(month: m, day: day + 1)])
        XCTAssertEqual(try HijriCalendarPreferences(defaults: defaults).load().start(m), day + 1)
        let saved = defaults.data(forKey: HijriCalendarPreferences.key)
        XCTAssertThrowsError(try store.save([.init(month: m, day: day + 3)]))
        XCTAssertEqual(defaults.data(forKey: HijriCalendarPreferences.key), saved)
        XCTAssertEqual(defaults.string(forKey: "progress"), "existing-progress-fixture")
        _ = try store.save([])
        XCTAssertEqual(try store.load().start(m), day)
        defaults.set(Data("damaged".utf8), forKey: HijriCalendarPreferences.key)
        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(defaults.data(forKey: HijriCalendarPreferences.key), Data("damaged".utf8))
    }

}
