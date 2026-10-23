import XCTest
@testable import ZikrDomain

final class ProgressStateCodingTests: XCTestCase {
    // 2.3
    func testKeysAndRoundTrip() throws {
        let state = ProgressState(
            total: 1234,
            daily: ["2026-10-23": 137],
            unlocked: ["ch01", "ch02"],
            viewed: ["ch01"],
            settings: AppSettings(goalOn: true, goal: 200, lang: .tg),
            onboarded: true,
            cameras: ["medina": CameraPosition(x: 12.5, y: -40, z: 1.2)],
            city: "medina",
            updatedAt: 1_792_740_000_000
        )
        let data = try JSONEncoder().encode(state)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["v", "total", "daily", "unlocked", "viewed", "settings", "onboarded", "cameras", "city", "updatedAt"])
        let settings = try XCTUnwrap(object["settings"] as? [String: Any])
        XCTAssertEqual(Set(settings.keys), ["haptics", "sound", "animations", "banners", "translit", "translation",
                                            "keepAwake", "goalOn", "goal", "preview", "lang"])
        XCTAssertEqual(try JSONDecoder().decode(ProgressState.self, from: data), state)

        // Ключи city/updatedAt присутствуют и для nil.
        let fresh = ProgressState.fresh(preferredLanguages: ["en"])
        let freshData = try JSONEncoder().encode(fresh)
        let freshObject = try XCTUnwrap(try JSONSerialization.jsonObject(with: freshData) as? [String: Any])
        XCTAssertEqual(freshObject.count, 10)
        XCTAssertEqual(try JSONDecoder().decode(ProgressState.self, from: freshData), fresh)
    }
}
