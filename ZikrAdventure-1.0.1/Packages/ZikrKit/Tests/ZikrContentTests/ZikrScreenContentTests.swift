// ZikrScreenContentTests.swift
// ZKR-52: zikr-content.json (уровни и главы из index.html) — полнота на 6 языках и выбор языка.

import XCTest
@testable import ZikrContent

final class ZikrScreenContentTests: XCTestCase {
    private static let languages = ["ru", "en", "uz", "tg", "kk", "ky"]

    func testBundledContentIsComplete() throws {
        let content = try BundledZikrContentProvider().loadZikrContent()
        XCTAssertEqual(content.levels.count, 7)
        XCTAssertEqual(content.chapters.count, 19)
        XCTAssertEqual(content.chapters.map(\.n), content.chapters.map(\.n).sorted(), "главы по порядку порогов")
        for level in content.levels {
            for lang in Self.languages {
                XCTAssertFalse((level.name[lang] ?? "").isEmpty, "level \(level.from) [\(lang)]")
            }
        }
        for chapter in content.chapters {
            for lang in Self.languages {
                XCTAssertFalse((chapter.title[lang] ?? "").isEmpty, "\(chapter.id) title [\(lang)]")
                XCTAssertFalse((chapter.year[lang] ?? "").isEmpty, "\(chapter.id) year [\(lang)]")
            }
        }
    }

    func testKnownStrings() throws {
        let content = try BundledZikrContentProvider().loadZikrContent()
        XCTAssertEqual(content.levelName(index: 0, language: "ru"), "Долина Мекки")
        XCTAssertEqual(content.levelName(index: 6, language: "en"), "The path complete")
        XCTAssertEqual(content.chapterTitle(id: "ch01", language: "en"), content.chapters[0].title["en"])
        XCTAssertEqual(content.chapterYear(id: "ch04", language: "ru"), "605 г.")
        XCTAssertEqual(content.levelName(index: 99, language: "ru"), "")
        XCTAssertEqual(content.chapterTitle(id: "nope", language: "ru"), "")
    }

    func testPickFallsBackToRussian() {
        XCTAssertEqual(ZikrScreenContent.pick(["ru": "А", "en": ""], language: "en"), "А")
        XCTAssertEqual(ZikrScreenContent.pick(["ru": "А", "uz": "B"], language: "uz"), "B")
        XCTAssertEqual(ZikrScreenContent.pick([:], language: "uz"), "")
    }
}
