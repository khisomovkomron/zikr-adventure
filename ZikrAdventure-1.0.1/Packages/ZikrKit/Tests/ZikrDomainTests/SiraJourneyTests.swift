// SiraJourneyTests.swift
// ZKR-53: группы уровней, состояние заголовков и метки «Новое» — как renderPath() в index.html.

import XCTest
@testable import ZikrDomain

final class SiraJourneyTests: XCTestCase {
    func testGroupsSplitChaptersByLevelBounds() {
        let groups = SiraJourney.groups(total: 0)
        XCTAssertEqual(groups.count, 7)
        XCTAssertEqual(groups.map { $0.chapterIDs.count }, [4, 3, 3, 3, 3, 2, 1])
        XCTAssertEqual(groups[0].chapterIDs, ["ch01", "ch02", "ch03", "ch04"], "n = 100 входит в уровень 0–100")
        XCTAssertEqual(groups[1].chapterIDs, ["ch05", "ch06", "ch07"])
        XCTAssertEqual(groups[6].chapterIDs, ["ch19"])
        XCTAssertEqual(groups.flatMap(\.chapterIDs), ChapterCatalog.thresholds.map(\.id), "все 19 глав по порядку, без повторов")
    }

    func testLevelStates() {
        XCTAssertEqual(SiraJourney.groups(total: 0).map(\.state), [.active] + Array(repeating: .upcoming, count: 6))
        XCTAssertEqual(SiraJourney.groups(total: 99).map(\.state).prefix(2), [.active, .upcoming])
        XCTAssertEqual(SiraJourney.groups(total: 100).map(\.state).prefix(3), [.done, .active, .upcoming], "total ≥ to — пройден")
        XCTAssertEqual(SiraJourney.groups(total: 100_000_000).map(\.state), Array(repeating: .done, count: 7))
        XCTAssertEqual(SiraJourney.groups(total: 5).map(\.number), Array(1...7))
    }

    func testOpenAndNew() {
        XCTAssertTrue(SiraJourney.isOpen("ch01", unlocked: ["ch01"], preview: false))
        XCTAssertFalse(SiraJourney.isOpen("ch02", unlocked: ["ch01"], preview: false))
        XCTAssertTrue(SiraJourney.isOpen("ch02", unlocked: [], preview: true), "предпросмотр открывает всё")
        XCTAssertFalse(SiraJourney.isReallyOpen("ch02", unlocked: []))
        XCTAssertTrue(SiraJourney.isNew("ch01", unlocked: ["ch01"], viewed: [String]()))
        XCTAssertFalse(SiraJourney.isNew("ch01", unlocked: ["ch01"], viewed: ["ch01"]))
        XCTAssertFalse(SiraJourney.isNew("ch02", unlocked: [], viewed: Set<String>()), "в предпросмотре «Новое» не показывается")
    }
}
