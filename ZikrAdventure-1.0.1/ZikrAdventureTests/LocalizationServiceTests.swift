// LocalizationServiceTests.swift
// ZKR-50: выбор языка, сохранение, строки из .lproj приложения (Localizable.xcstrings).
// Совпадение текстов с index.html проверяет tests/l10n-native.cjs (генератор --check).

import XCTest
import ZikrDomain
@testable import ZikrAdventure

@MainActor
final class LocalizationServiceTests: XCTestCase {
    func testStartLanguagePriority() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "LocalizationServiceTests"))
        defaults.removePersistentDomain(forName: "LocalizationServiceTests")
        XCTAssertEqual(LocalizationService(defaults: defaults, preferredLanguages: ["kk-KZ"]).language, .kk)
        defaults.set("tg", forKey: LocalizationService.languageDefaultsKey)
        XCTAssertEqual(LocalizationService(defaults: defaults, preferredLanguages: ["kk-KZ"]).language, .tg)
        XCTAssertEqual(LocalizationService(language: .en, defaults: defaults).language, .en)
        defaults.removePersistentDomain(forName: "LocalizationServiceTests")
    }

    func testSetLanguagePersistsAndResolvesUnknownCodes() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "LocalizationServiceTests2"))
        let service = LocalizationService(language: .en, defaults: defaults)
        service.setLanguage(code: "ky")
        XCTAssertEqual(service.language, .ky)
        XCTAssertEqual(defaults.string(forKey: LocalizationService.languageDefaultsKey), "ky")
        service.setLanguage(code: "xx")
        XCTAssertEqual(service.language, .ru)
        defaults.removePersistentDomain(forName: "LocalizationServiceTests2")
    }

    func testEveryKeyIsLocalizedInEveryLanguage() {
        let service = LocalizationService(language: .ru, defaults: nil)
        for language in AppLanguage.allCases {
            for key in L10nKey.allCases {
                let value = service.string(for: key, language: language)
                XCTAssertNotEqual(value, key.rawValue, "\(language.rawValue): \(key.rawValue) missing")
                XCTAssertFalse(value.isEmpty, "\(language.rawValue): \(key.rawValue) empty")
            }
        }
    }

    func testKnownStringsMatchWeb() {
        let service = LocalizationService(language: .ru, defaults: nil)
        XCTAssertEqual(service.tr(.tabSettings), "Настройки")
        XCTAssertEqual(service.tr(.setGoalValue, "120"), "Цель: 120")
        service.setLanguage(.kk)
        XCTAssertEqual(service.tr(.tabSettings), "Баптаулар")
        service.setLanguage(.tg)
        XCTAssertEqual(service.tr(.setLanguage), "Забон")
        service.setLanguage(.en)
        XCTAssertEqual(service.tr(.setGoalValue, service.format(1_000)), "Goal: 1,000")
    }

    func testTabTitlesUseNativeKeys() {
        let service = LocalizationService(language: .ky, defaults: nil)
        XCTAssertEqual(service.tr(TabItem.settings.titleKey), "Жөндөөлөр")
    }

    func testNativeNames() {
        XCTAssertEqual(LocalizationService.nativeName(of: .uz), "O‘zbekcha")
        XCTAssertEqual(LocalizationService.localeIdentifier(for: .tg), "tg-TJ")
    }
}
