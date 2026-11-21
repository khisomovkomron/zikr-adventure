// InfoBidiTests.swift
// ZKR-63: после ﷺ (U+FDFA, bidi-класс AL) знак препинания и цифра переупорядочиваются
// («ﷺ: 7» показывается как «7 :ﷺ»). Во всех текстах «Инфо» за ﷺ, если дальше идут
// пробелы/знаки препинания и цифра, должен стоять U+200E (LRM).

import Foundation
import XCTest
@testable import ZikrContent

final class InfoBidiTests: XCTestCase {
    private static let salawat = "\u{FDFA}"
    private static let lrm = "\u{200E}"

    /// ﷺ, затем только пробелы/пунктуация, затем цифра — без LRM между ними.
    private static let unsafePattern = try! NSRegularExpression(pattern: "\u{FDFA}[\\p{P}\\p{Zs}]*\\p{Nd}")

    static func hasUnsafeDigitAfterSalawat(_ text: String) -> Bool {
        unsafePattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    func testDetectorCatchesTheOriginalBug() {
        XCTAssertTrue(Self.hasUnsafeDigitAfterSalawat("Пророка \(Self.salawat): 7 уровней"))
        XCTAssertFalse(Self.hasUnsafeDigitAfterSalawat("Пророка \(Self.salawat)\(Self.lrm): 7 уровней"))
        XCTAssertFalse(Self.hasUnsafeDigitAfterSalawat("Payg‘ambar \(Self.salawat) davridagi"))
    }

    func testNoInfoTextReordersDigitsAfterSalawat() throws {
        let content = try BundledInfoContentProvider().loadContent()
        for (lang, texts) in content.languages {
            for (key, text) in texts {
                XCTAssertFalse(Self.hasUnsafeDigitAfterSalawat(text), "\(lang) / \(key)")
            }
        }
    }

    func testAboutTextKeepsSalawatBeforeColonAndNumber() throws {
        let content = try BundledInfoContentProvider().loadContent()
        for lang in ["ru", "en", "tg"] {
            let text = try XCTUnwrap(content.languages[lang]?["info.aboutTextApp"])
            XCTAssertTrue(text.contains("\(Self.salawat)\(Self.lrm): 7"), lang)
        }
    }
}
