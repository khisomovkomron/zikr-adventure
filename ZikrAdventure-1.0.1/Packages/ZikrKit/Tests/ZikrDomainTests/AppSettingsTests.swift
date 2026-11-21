import XCTest
@testable import ZikrDomain

final class AppSettingsTests: XCTestCase {
    // 2.2
    func testDefaultsMatchWeb() {
        let s = AppSettings.defaults(preferredLanguages: ["ru-RU"])
        XCTAssertTrue(s.haptics)
        XCTAssertFalse(s.sound)
        XCTAssertTrue(s.animations)
        XCTAssertTrue(s.banners)
        XCTAssertTrue(s.translit)
        XCTAssertTrue(s.translation)
        XCTAssertFalse(s.keepAwake)
        XCTAssertFalse(s.goalOn)
        XCTAssertEqual(s.goal, 100)
        XCTAssertFalse(s.preview)
        XCTAssertEqual(s.lang, .ru)
    }

    func testLanguageDetection() {
        XCTAssertEqual(AppSettings.defaults(preferredLanguages: ["tg-TJ"]).lang, .tg)
        XCTAssertEqual(AppSettings.defaults(preferredLanguages: ["uz-Latn-UZ"]).lang, .uz)
        XCTAssertEqual(AppSettings.defaults(preferredLanguages: ["de-DE"]).lang, .ru)
        XCTAssertEqual(AppSettings.defaults(preferredLanguages: []).lang, .ru)
        XCTAssertEqual(AppSettings.defaults(preferredLanguages: ["EN-us"]).lang, .en)
    }
}
