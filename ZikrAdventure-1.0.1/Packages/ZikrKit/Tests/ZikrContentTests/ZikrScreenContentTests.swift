// ZikrScreenContentTests.swift
// ZKR-52: zikr-content.json (уровни и главы из index.html) — полнота на 6 языках и выбор языка.
// ZKR-53: + города, места, тексты глав, карточки мест и расстояния для «Пути Сиры».

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

    func testSiraChapterFields() throws {
        let content = try BundledZikrContentProvider().loadZikrContent()
        for chapter in content.chapters {
            if let place = chapter.place {
                XCTAssertNotNil(content.places[place], "\(chapter.id): место \(place)")
                XCTAssertEqual(content.places[place]?.city, chapter.city, "\(chapter.id): город места")
            } else {
                for lang in Self.languages {
                    XCTAssertFalse((chapter.text?[lang] ?? "").isEmpty, "\(chapter.id) text [\(lang)]")
                }
            }
            if let city = chapter.city {
                XCTAssertTrue(["mecca", "medina"].contains(city), chapter.id)
            }
        }
        XCTAssertEqual(content.chapters.filter { $0.city == nil }.map(\.id), ["ch19"], "без города только ch19")
        XCTAssertEqual(content.chapter(id: "ch01")?.focus, "kaaba")
        XCTAssertEqual(content.chapter(id: "ch02")?.place, "zamzam")
        XCTAssertEqual(content.chapterIndex(id: "ch01"), 1)
        XCTAssertEqual(content.chapterIndex(id: "ch19"), 19)
        XCTAssertNil(content.chapterIndex(id: "nope"))
    }

    func testPlacesAreComplete() throws {
        let content = try BundledZikrContentProvider().loadZikrContent()
        XCTAssertEqual(content.places.count, 16)
        let categories: Set<String> = ["sacred", "mosque", "sira", "nature", "city", "memorial"]
        for (id, place) in content.places {
            XCTAssertFalse(place.ar.isEmpty, id)
            XCTAssertTrue(categories.contains(place.cat), "\(id): \(place.cat)")
            XCTAssertFalse(place.dist.isEmpty, "\(id): DIST")
            for lang in Self.languages {
                for (field, values) in [("name", place.name), ("sig", place.sig), ("look", place.look), ("sira", place.sira)] {
                    XCTAssertFalse((values[lang] ?? "").isEmpty, "\(id).\(field) [\(lang)]")
                }
            }
        }
        XCTAssertEqual(content.places["kaaba"]?.dist, [.init(m: 0)])
        XCTAssertEqual(content.places["safamarwa"]?.dist, [.init(m: 130, dir: "se", sub: 0), .init(m: 300, dir: "ne", sub: 1)])
        XCTAssertEqual(content.places["hira"]?.dist, [.init(m: 4_800, dir: "ne")])
        XCTAssertEqual(content.safaMarwaLabel(1, language: "kk"), "Мәруа")
        XCTAssertEqual(content.safaMarwaLabel(0, language: "uz"), "Safo")
        XCTAssertEqual(content.safaMarwaLabel(5, language: "ru"), "")
    }
}
