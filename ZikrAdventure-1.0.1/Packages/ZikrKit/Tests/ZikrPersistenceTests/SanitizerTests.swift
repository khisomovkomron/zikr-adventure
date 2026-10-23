import XCTest
import ZikrCore
import ZikrDomain
@testable import ZikrPersistence

final class SanitizerTests: XCTestCase {
    private let fresh = ProgressState.fresh(preferredLanguages: testLanguages)

    // 3.1
    func testNonObjectsGiveFresh() {
        XCTAssertEqual(LegacySanitizer.sanitize(nil, preferredLanguages: testLanguages), fresh)
        XCTAssertEqual(sanitize("null"), fresh)
        XCTAssertEqual(sanitize("[1,2,3]"), fresh)
        XCTAssertEqual(sanitize("\"text\""), fresh)
    }

    // 3.2
    func testTotal() {
        XCTAssertEqual(sanitize("{\"total\":-5}").total, 0)
        XCTAssertEqual(sanitize("{\"total\":12.7}").total, 12)
        XCTAssertEqual(sanitize("{\"total\":\"100\"}").total, 0)
        XCTAssertEqual(sanitize("{\"total\":1e20}").total, 9_007_199_254_740_991)
        XCTAssertEqual(sanitize("{\"total\":true}").total, 0)
    }

    // 3.3
    func testDaily() {
        let s = sanitize("{\"daily\":{\"2026-10-01\":-1,\"2026-10-02\":\"x\",\"2026-10-03\":0,\"2026-10-04\":7,\"2026-10-05\":2.9}}")
        XCTAssertEqual(s.daily, ["2026-10-03": 0, "2026-10-04": 7, "2026-10-05": 2])
        XCTAssertEqual(sanitize("{\"daily\":[1,2]}").daily, [:])
        XCTAssertEqual(sanitize("{\"daily\":5}").daily, [:])
    }

    // 3.4
    func testUnlockedAndViewed() {
        let s = sanitize("{\"unlocked\":[\"ch01\",\"zz\",\"ch01\"],\"viewed\":[1,\"a\"]}")
        XCTAssertEqual(s.unlocked, ["ch01", "ch01"])
        XCTAssertEqual(s.viewed, ["a"])
        XCTAssertEqual(sanitize("{\"unlocked\":\"ch01\"}").unlocked, [])
    }

    // 3.5
    func testGoal() {
        func goal(_ raw: String) -> Int { sanitize("{\"settings\":{\"goal\":\(raw)}}").settings.goal }
        XCTAssertEqual(goal("0"), 100)
        XCTAssertEqual(goal("4"), 100)
        XCTAssertEqual(goal("5"), 10)
        XCTAssertEqual(goal("-5"), 100)
        XCTAssertEqual(goal("15"), 20)
        XCTAssertEqual(goal("99999"), 10000)
        XCTAssertEqual(goal("\"abc\""), 100)
        XCTAssertEqual(sanitize("{\"settings\":{}}").settings.goal, 100)
        XCTAssertEqual(sanitize("{}").settings.goal, 100)
    }

    // 3.6
    func testSettings() {
        XCTAssertEqual(sanitize("{\"settings\":{\"lang\":\"fr\"}}").settings.lang, .ru)
        XCTAssertEqual(LegacySanitizer.sanitize(JSONValue.parse("{\"settings\":{}}"), preferredLanguages: ["kk-KZ"]).settings.lang, .kk)
        let s = sanitize("{\"settings\":{\"haptics\":\"yes\",\"sound\":true,\"lang\":\"tg\"}}")
        XCTAssertTrue(s.settings.haptics)
        XCTAssertTrue(s.settings.sound)
        XCTAssertEqual(s.settings.lang, .tg)
        var expected = AppSettings.defaults(preferredLanguages: testLanguages)
        expected.sound = true
        expected.lang = .tg
        XCTAssertEqual(s.settings, expected)
    }

    // 3.7
    func testCamerasCityUpdatedAt() {
        XCTAssertEqual(sanitize("{\"cameras\":[1]}").cameras, [:])
        let s = sanitize("{\"cameras\":{\"medina\":{\"x\":1,\"y\":2,\"z\":3},\"mecca\":{\"x\":1,\"y\":2}},\"city\":5,\"updatedAt\":1792740000000}")
        XCTAssertEqual(s.cameras, ["medina": CameraPosition(x: 1, y: 2, z: 3)])
        XCTAssertNil(s.city)
        XCTAssertEqual(s.updatedAt, 1_792_740_000_000)
        XCTAssertEqual(sanitize("{\"city\":\"medina\"}").city, "medina")
        XCTAssertNil(sanitize("{}").updatedAt)
    }

    func testFixture111RoundTrip() throws {
        let s = sanitize(try Fixture.text("progress-1.1.1.json"))
        XCTAssertEqual(s.total, 1234)
        XCTAssertEqual(s.city, "medina")
        XCTAssertTrue(s.settings.goalOn)
        XCTAssertEqual(s.settings.goal, 200)
        XCTAssertEqual(s.settings.lang, .tg)
        XCTAssertEqual(s.cameras["medina"], CameraPosition(x: 12.5, y: -40, z: 1.2))
        XCTAssertEqual(s.v, 2)
    }
}
