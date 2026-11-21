import XCTest
import ZikrCore
@testable import ZikrDomain

final class NativeProgressCommandTests: XCTestCase {
    private let catalog = NativeCommandCatalog(cityIDs: ["mecca", "medina"],
                                                chapterCities: ["ch01": "mecca", "ch09": "medina"])
    private let utc = TimeZone(secondsFromGMT: 0)!
    private let noon = Date(timeIntervalSince1970: 1_795_089_600)

    private func apply(_ command: NativeProgressCommand, _ state: ProgressState,
                       at date: Date? = nil, zone: TimeZone? = nil) throws -> NativeCommandResult {
        try XCTUnwrap(NativeProgressReducer.apply(command, to: state, at: date ?? noon,
                                                 timeZone: zone ?? utc, catalog: catalog))
    }

    func testTapUnlocksOnceAndUndoNeverRelocks() throws {
        let day = DayKey.string(for: noon, timeZone: utc)
        let tapped = try apply(.tap, ProgressState(total: 9, daily: [day: 9]))
        XCTAssertEqual(tapped.snapshot.total, 10)
        XCTAssertEqual(tapped.snapshot.today, 10)
        XCTAssertEqual(tapped.fresh, ["ch01"])
        let undone = try apply(.undo, tapped.progress)
        XCTAssertEqual(undone.snapshot.today, 9)
        XCTAssertEqual(undone.progress.unlocked, ["ch01"])
        XCTAssertEqual(try apply(.tap, undone.progress).fresh, [])
    }

    func testMidnightUndoAndTimeZoneUseCurrentLocalDay() throws {
        let before = Date(timeIntervalSince1970: 1_795_046_399) // Fixed instant; derive local day explicitly.
        let after = before.addingTimeInterval(1)
        let oldDay = DayKey.string(for: before, timeZone: utc)
        let newDay = DayKey.string(for: after, timeZone: utc)
        XCTAssertNotEqual(oldDay, newDay)
        let state = ProgressState(total: 7, daily: [oldDay: 7])
        let undo = try apply(.undo, state, at: after)
        XCTAssertEqual(undo.progress.total, 6)
        XCTAssertEqual(undo.progress.daily, [oldDay: 7], "undo affects today, not yesterday")
        let tap = try apply(.tap, undo.progress, at: after)
        XCTAssertEqual(tap.progress.daily, [oldDay: 7, newDay: 1])
        let offset = TimeZone(secondsFromGMT: 14 * 3600)!
        XCTAssertEqual(try apply(.tap, state, at: before, zone: offset).day,
                       DayKey.string(for: before, timeZone: offset))
    }

    func testCounterResetsPreserveHistoryCameraSettingsAndOnboarding() throws {
        let state = ProgressState(total: 10, daily: ["2026-11-01": 10], unlocked: ["ch01"], viewed: ["ch01"],
                                  settings: AppSettings(goalOn: true, goal: 330, lang: .tg), onboarded: true,
                                  cameras: ["mecca": .init(x: 2, y: 3, z: 1)], city: "mecca")
        for mode in ZikrResetMode.allCases {
            let reset = try apply(.reset(mode), state).progress
            XCTAssertEqual(reset.total, 0)
            XCTAssertEqual(reset.daily, state.daily)
            XCTAssertEqual(reset.cameras, state.cameras)
            XCTAssertEqual(reset.city, state.city)
            XCTAssertEqual(reset.settings, state.settings)
            XCTAssertTrue(reset.onboarded)
            XCTAssertEqual(reset.unlocked, mode == .counter ? state.unlocked : [])
            XCTAssertEqual(reset.viewed, mode == .counter ? state.viewed : [])
        }
        let all = try apply(.resetProgress, state).progress
        XCTAssertEqual(all.total, 0)
        XCTAssertEqual(all.daily, [:])
        XCTAssertEqual(all.settings, state.settings)
        XCTAssertTrue(all.onboarded)
        XCTAssertEqual(all.cameras, [:])
        XCTAssertNil(all.city)
    }

    func testHistoryAndSettingsKeepOtherData() throws {
        let day = DayKey.string(for: noon, timeZone: utc)
        var state = ProgressState(total: 50, daily: ["2000-01-01": 20, day: 30], onboarded: true)
        state = try apply(.clearHistory, state).progress
        XCTAssertEqual(state.daily, [day: 30])
        XCTAssertEqual(state.total, 50)
        for toggle in SettingsToggle.allCases {
            let old = state.settings[toggle]
            state = try apply(.setSetting(.toggle(toggle, !old)), state).progress
            XCTAssertEqual(state.settings[toggle], !old)
        }
        XCTAssertEqual(try apply(.setSetting(.goal(-100)), state).progress.settings.goal, 10)
        XCTAssertEqual(try apply(.setSetting(.goal(99_999)), state).progress.settings.goal, 10_000)
        XCTAssertEqual(try apply(.setSetting(.goal(333)), state).progress.settings.goal, 333)
        for language in AppLanguage.allCases {
            let changed = try apply(.setLanguage(language), state).progress
            XCTAssertEqual(changed.settings.lang, language)
            XCTAssertEqual(try apply(.resetDefaults, changed).progress.settings, AppSettings(lang: language))
            XCTAssertEqual(changed.total, 50)
        }
    }

    func testViewedPreviewCityAndCameraValidation() throws {
        let state = ProgressState(total: 10, unlocked: ["ch01"])
        let opened = try apply(.openChapter("ch01"), state).progress
        XCTAssertEqual(opened.viewed, ["ch01"])
        XCTAssertEqual(opened.city, "mecca")
        XCTAssertNil(try NativeProgressReducer.apply(.openChapter("ch09"), to: state, at: noon, timeZone: utc, catalog: catalog))
        var preview = state
        preview.settings.preview = true
        XCTAssertEqual(try apply(.openChapter("ch09"), preview).progress.city, "medina")
        XCTAssertNil(try NativeProgressReducer.apply(.openChapter("ch19"), to: preview, at: noon, timeZone: utc, catalog: catalog))
        XCTAssertEqual(try apply(.explore("ch19"), preview).progress.viewed, ["ch19"])
        let camera = CameraPosition(x: -100, y: 4.5, z: 1.7)
        XCTAssertEqual(try apply(.saveCamera("mecca", camera), state).progress.cameras["mecca"], camera)
        XCTAssertNil(try apply(.selectCity(nil), opened).progress.city)
        for camera in [CameraPosition(x: .nan, y: 0, z: 1), .init(x: 0, y: .infinity, z: 1)] {
            XCTAssertNil(try NativeProgressReducer.apply(.saveCamera("mecca", camera), to: state, at: noon, timeZone: utc, catalog: catalog))
        }
    }

    func testClockRollbackAndNumericLimitsDoNotOverflow() throws {
        let futureTimestamp = Int64(noon.timeIntervalSince1970 * 1000) + 50_000
        let day = DayKey.string(for: noon, timeZone: utc)
        let state = ProgressState(total: JSNumber.maxSafeInteger, daily: [day: JSNumber.maxSafeInteger], updatedAt: futureTimestamp)
        let result = try apply(.tap, state)
        XCTAssertEqual(result.progress.total, JSNumber.maxSafeInteger)
        XCTAssertEqual(result.progress.daily[day], JSNumber.maxSafeInteger)
        XCTAssertEqual(result.progress.updatedAt, futureTimestamp + 1)
        var exhausted = state
        exhausted.updatedAt = JSNumber.maxSafeInteger
        XCTAssertThrowsError(try NativeProgressReducer.apply(.tap, to: exhausted, at: noon, timeZone: utc, catalog: catalog)) { XCTAssertEqual($0 as? NativeCommandError, .timestampExhausted) }
        var invalid = state
        invalid.total = -1
        XCTAssertThrowsError(try NativeProgressReducer.apply(.tap, to: invalid, at: noon, timeZone: utc, catalog: catalog))
        XCTAssertThrowsError(try NativeProgressReducer.apply(.tap, to: state, at: Date(timeIntervalSince1970: .nan), timeZone: utc, catalog: catalog))
    }
}
