// ZikrProgressTests.swift
// ZKR-52: порт currentLevel() / progressCard() / nextChapter() / goalCard() / openHistory() из index.html.

import XCTest
@testable import ZikrDomain

final class ZikrProgressTests: XCTestCase {
    func testLevelBoundaries() {
        // total < to → этот уровень; ровно на границе — уже следующий.
        let cases: [(Int64, Int)] = [
            (0, 0), (99, 0), (100, 1), (999, 1), (1_000, 2), (9_999, 2), (10_000, 3),
            (99_999, 3), (100_000, 4), (999_999, 4), (1_000_000, 5), (9_999_999, 5),
            (10_000_000, 6), (99_999_999, 6), (100_000_000, 7), (Int64.max, 7),
        ]
        for (total, expected) in cases {
            XCTAssertEqual(ZikrProgress.currentLevelIndex(total: total), expected, "total \(total)")
        }
    }

    func testLevelCardAtZero() {
        let card = ZikrProgress.levelCard(total: 0)
        XCTAssertEqual(card.number, 1)
        XCTAssertEqual(card.count, 7)
        XCTAssertFalse(card.isDone)
        XCTAssertEqual(card.fraction, 0)
        XCTAssertEqual(card.toNext, 100)
        XCTAssertEqual(card.bounds, LevelCatalog.Bounds(from: 0, to: 100))
    }

    func testLevelCardFractionAndToNext() {
        let card = ZikrProgress.levelCard(total: 99)
        XCTAssertEqual(card.number, 1)
        XCTAssertEqual(card.fraction, 0.99, accuracy: 1e-9)
        XCTAssertEqual(card.toNext, 1)

        let second = ZikrProgress.levelCard(total: 100)
        XCTAssertEqual(second.number, 2)
        XCTAssertEqual(second.fraction, 0)
        XCTAssertEqual(second.toNext, 900)

        let deep = ZikrProgress.levelCard(total: 999_999)
        XCTAssertEqual(deep.number, 5)
        XCTAssertEqual(deep.toNext, 1)
        XCTAssertEqual(deep.fraction, Double(999_999 - 100_000) / Double(900_000), accuracy: 1e-12)
    }

    func testAllLevelsDone() {
        let card = ZikrProgress.levelCard(total: 100_000_000)
        XCTAssertTrue(card.isDone)
        XCTAssertEqual(card.index, 6, "показывается последний уровень")
        XCTAssertEqual(card.fraction, 1)
        XCTAssertEqual(card.toNext, 0)
    }

    func testNextChapterFollowsUnlockedNotTotal() {
        XCTAssertEqual(ZikrProgress.nextChapter(total: 0, unlocked: []),
                       .init(id: "ch01", threshold: 10, remaining: 10))
        // После «Сброс счётчика» главы остаются: следующая — первая не открытая, остаток от нового total.
        XCTAssertEqual(ZikrProgress.nextChapter(total: 0, unlocked: ["ch01", "ch02"]),
                       .init(id: "ch03", threshold: 50, remaining: 50))
        // total уже больше порога, а глава ещё не открыта — остаток 0, не отрицательный.
        XCTAssertEqual(ZikrProgress.nextChapter(total: 30, unlocked: [])?.remaining, 0)
        XCTAssertNil(ZikrProgress.nextChapter(total: 0, unlocked: ChapterCatalog.thresholds.map(\.id)))
    }

    func testFreshChapters() {
        XCTAssertEqual(ZikrProgress.freshChapters(total: 9, unlocked: []), [])
        XCTAssertEqual(ZikrProgress.freshChapters(total: 10, unlocked: []), ["ch01"])
        XCTAssertEqual(ZikrProgress.freshChapters(total: 60, unlocked: ["ch01"]), ["ch02", "ch03"])
    }

    func testGoal() {
        var settings = AppSettings(goalOn: false, goal: 100)
        XCTAssertNil(ZikrProgress.goal(today: 50, settings: settings))
        settings.goalOn = true
        XCTAssertEqual(ZikrProgress.goal(today: 33, settings: settings), .init(goal: 100, done: 33, fraction: 0.33))
        XCTAssertEqual(ZikrProgress.goal(today: 250, settings: settings), .init(goal: 100, done: 100, fraction: 1))
    }

    func testHistoryDaysNewestFirstWithoutZeroesMax30() {
        var daily: [String: Int64] = ["2026-11-10": 0]
        for day in 1...31 { daily[String(format: "2026-10-%02d", day)] = Int64(day) }
        daily["2026-11-11"] = 5
        let days = ZikrProgress.historyDays(daily: daily)
        XCTAssertEqual(days.count, 30)
        XCTAssertEqual(days.first?.day, "2026-11-11")
        XCTAssertEqual(days[1].day, "2026-10-31")
        XCTAssertFalse(days.contains { $0.day == "2026-11-10" })
    }

    func testLevelCatalogIsContiguousTimesTen() {
        let levels = LevelCatalog.levels
        XCTAssertEqual(levels.count, 7)
        XCTAssertEqual(levels.first?.from, 0)
        for (a, b) in zip(levels, levels.dropFirst()) {
            XCTAssertEqual(a.to, b.from)
        }
        XCTAssertEqual(levels.last?.to, 100_000_000)
    }

    func testSnapshotDecodesWebJSON() throws {
        let json = #"{"total":10,"today":3,"day":"2026-11-11","unlocked":["ch01"],"fresh":["ch01"],"updatedAt":1762839000123}"#
        let snapshot = try JSONDecoder().decode(ZikrSnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(snapshot, ZikrSnapshot(total: 10, today: 3, day: "2026-11-11", unlocked: ["ch01"], fresh: ["ch01"], updatedAt: 1_762_839_000_123))
    }
}
