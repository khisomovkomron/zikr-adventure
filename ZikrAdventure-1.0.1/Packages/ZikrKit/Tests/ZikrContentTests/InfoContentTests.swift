// InfoContentTests.swift
// ZKR-48: тексты экрана «Инфо», fallback как у T() в index.html, порядок пунктов и легенды.

import XCTest
import ZikrCore
@testable import ZikrContent

final class InfoContentTests: XCTestCase {
    private static let languages = ["ru", "en", "uz", "tg", "kk", "ky"]

    private func bundled() throws -> InfoContent {
        try BundledInfoContentProvider().loadContent()
    }

    func testBundledContentHasAllLanguagesAndKeys() throws {
        let content = try bundled()
        XCTAssertEqual(content.schema, InfoContent.supportedSchema)
        XCTAssertEqual(Set(content.languages.keys), Set(Self.languages))
        for lang in Self.languages {
            for key in InfoKey.allCases {
                let value = content.languages[lang]?[key.rawValue]
                XCTAssertNotNil(value, "\(lang) / \(key.rawValue)")
                XCTAssertFalse(value?.isEmpty ?? true, "\(lang) / \(key.rawValue)")
            }
        }
    }

    func testFallbackMatchesWebT() {
        let content = InfoContent(languages: [
            "en": ["info.about": "About", "common.close": "Close"],
            "ru": ["info.about": "О приложении"],
        ])
        XCTAssertEqual(content.text(.about, language: "ru"), "О приложении")
        // нет ключа в языке → en
        XCTAssertEqual(content.text(.close, language: "ru"), "Close")
        // нет языка → en
        XCTAssertEqual(content.text(.about, language: "xx"), "About")
        // нет нигде → сам ключ
        XCTAssertEqual(content.text(.howText, language: "ru"), "info.howText")
    }

    func testDecodeRejectsUnsupportedSchemaAndGarbage() {
        XCTAssertThrowsError(try InfoContent.decode(from: Data(#"{"schema":2,"languages":{}}"#.utf8))) { error in
            XCTAssertEqual(error as? AppError, .unsupportedSchema(2))
        }
        XCTAssertThrowsError(try InfoContent.decode(from: Data("not json".utf8))) { error in
            XCTAssertEqual(error as? AppError, .decoding("InfoContent"))
        }
    }

    func testPageTopicsOrderAndAppTexts() throws {
        let content = try bundled()
        let page = InfoPage.make(content: content, language: "ru")
        XCTAssertEqual(page.title, "Инфо")
        XCTAssertEqual(page.topics.map(\.id), [.about, .how, .sources, .privacy])
        XCTAssertEqual(page.topics.map(\.icon), [.info, .path, .book, .lock])
        XCTAssertEqual(page.topics[0].title, content.text(.about, language: "ru"))
        // В приложении (IS_APP) — App-варианты текстов.
        XCTAssertEqual(page.topics[0].body, content.text(.aboutTextApp, language: "ru"))
        XCTAssertEqual(page.topics[1].body, content.text(.howText, language: "ru"))
        XCTAssertEqual(page.topics[2].body, content.text(.sourcesText, language: "ru"))
        XCTAssertEqual(page.topics[3].body, content.text(.privacyTextApp, language: "ru"))
        XCTAssertEqual(page.legendRow.title, "Легенда")
        XCTAssertEqual(page.legendRow.icon, .map)
        XCTAssertEqual(page.closeTitle, "Закрыть")
    }

    func testLegendOrderMatchesOpenLegend() throws {
        let content = try bundled()
        let legend = InfoPage.make(content: content, language: "en").legend
        XCTAssertEqual(legend.title, content.text(.legend, language: "en"))
        XCTAssertEqual(legend.disclaimer, content.text(.disclaimer, language: "en"))
        XCTAssertEqual(legend.entries.map(\.icon), [.info, .star, .path, .urban, .hand, .list])
        XCTAssertEqual(
            legend.entries.map(\.text),
            [InfoKey.legendPlace, .legendLit, .legendRoute, .legendLife, .legendGesture, .legendList]
                .map { content.text($0, language: "en") }
        )
    }

    func testEveryLanguageProducesDistinctLocalizedPage() throws {
        let content = try bundled()
        let pages = Self.languages.map { InfoPage.make(content: content, language: $0) }
        XCTAssertEqual(Set(pages.map(\.title)).count, Self.languages.count)
        for page in pages {
            XCTAssertFalse(page.topics.contains { $0.title.hasPrefix("info.") || $0.body.hasPrefix("info.") })
        }
        // Неизвестный язык → английский, как T().
        XCTAssertEqual(InfoPage.make(content: content, language: "de"), InfoPage.make(content: content, language: "en"))
    }

    func testProviderReportsMissingFile() {
        let missing = URL(fileURLWithPath: "/nonexistent/info-content.json")
        XCTAssertThrowsError(try BundledInfoContentProvider(url: missing).loadContent()) { error in
            XCTAssertEqual(error as? AppError, .storageRead("info-content.json"))
        }
    }
}
