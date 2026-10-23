// InfoParityTests.swift
// ZKR-48: info-content.json совпадает с объектом UI в index.html для всех 6 языков.
// index.html читается прямо из репозитория — любая правка веб-текстов без обновления JSON уронит тест.

import Foundation
import XCTest
@testable import ZikrContent

final class InfoParityTests: XCTestCase {
    private static let languages = ["ru", "en", "uz", "tg", "kk", "ky"]

    /// Packages/ZikrKit/Tests/ZikrContentTests/<file> → ZikrAdventure/Web/index.html
    private static var indexURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // <file>
            .deletingLastPathComponent() // ZikrContentTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // ZikrKit
            .deletingLastPathComponent() // Packages
            .appendingPathComponent("ZikrAdventure/Web/index.html")
    }

    func testBundledTextsMatchIndexHTML() throws {
        let html = try String(contentsOf: Self.indexURL, encoding: .utf8)
        let blocks = try Self.languageBlocks(in: html)
        XCTAssertEqual(Set(blocks.keys), Set(Self.languages))
        let content = try BundledInfoContentProvider().loadContent()
        for lang in Self.languages {
            let block = try XCTUnwrap(blocks[lang])
            for key in InfoKey.allCases {
                let web = try XCTUnwrap(Self.value(of: key.rawValue, in: block), "\(lang) / \(key.rawValue) нет в index.html")
                XCTAssertEqual(content.languages[lang]?[key.rawValue], web, "\(lang) / \(key.rawValue)")
            }
        }
    }

    /// Блоки `ru: { … }` внутри `const UI = { … };` (каждый начинается с новой строки).
    static func languageBlocks(in html: String) throws -> [String: String] {
        let start = try XCTUnwrap(html.range(of: "const UI = {"))
        let end = try XCTUnwrap(html.range(of: "\n};", range: start.upperBound..<html.endIndex))
        let body = String(html[start.upperBound..<end.lowerBound])
        let regex = try NSRegularExpression(pattern: #"^([a-z]{2}): \{"#, options: [.anchorsMatchLines])
        let ns = body as NSString
        let matches = regex.matches(in: body, range: NSRange(location: 0, length: ns.length))
        var result: [String: String] = [:]
        for (index, match) in matches.enumerated() {
            let lang = ns.substring(with: match.range(at: 1))
            let from = match.range.location + match.range.length
            let to = index + 1 < matches.count ? matches[index + 1].range.location : ns.length
            result[lang] = ns.substring(with: NSRange(location: from, length: to - from))
        }
        return result
    }

    /// Значение `"key": "…"` — строковый литерал JS в JSON-совместимой форме (\uXXXX, \").
    static func value(of key: String, in block: String) -> String? {
        let pattern = "\"" + NSRegularExpression.escapedPattern(for: key) + #""\s*:\s*("(?:[^"\\]|\\.)*")"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: block, range: NSRange(location: 0, length: (block as NSString).length))
        else { return nil }
        let literal = (block as NSString).substring(with: match.range(at: 1))
        return try? JSONDecoder().decode(String.self, from: Data(literal.utf8))
    }
}
