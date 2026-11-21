import XCTest
@testable import ZikrCore

final class DayKeyTests: XCTestCase {
    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso) ?? Date(timeIntervalSince1970: 0)
    }

    // 1.1
    func testZeroPaddedGregorian() throws {
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let d = date("2026-01-05T12:00:00Z")
        XCTAssertEqual(DayKey.string(for: d, timeZone: utc), "2026-01-05")

        // Не-григорианский календарь пользователя не влияет на ключ дня.
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = utc
        XCTAssertNotEqual(buddhist.component(.year, from: d), 2026)
        var persian = Calendar(identifier: .persian)
        persian.timeZone = utc
        XCTAssertNotEqual(persian.component(.year, from: d), 2026)
        XCTAssertTrue(DayKey.string(for: d, timeZone: utc).hasPrefix("2026-"))
    }

    // 1.2
    func testTimeZoneBoundary() throws {
        let d = date("2026-10-23T19:30:00Z")
        XCTAssertEqual(DayKey.string(for: d, timeZone: try XCTUnwrap(TimeZone(identifier: "Asia/Dushanbe"))), "2026-10-24")
        XCTAssertEqual(DayKey.string(for: d, timeZone: try XCTUnwrap(TimeZone(identifier: "UTC"))), "2026-10-23")
    }
}
