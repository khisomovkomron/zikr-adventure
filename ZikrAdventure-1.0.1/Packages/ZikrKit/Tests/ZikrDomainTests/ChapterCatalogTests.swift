import XCTest
@testable import ZikrDomain

final class ChapterCatalogTests: XCTestCase {
    // 2.1
    func testCatalogMatchesWeb() {
        let expected: [Int64] = [10, 25, 50, 100, 250, 500, 1_000, 2_500, 5_000, 10_000, 25_000, 50_000,
                                 100_000, 250_000, 500_000, 1_000_000, 5_000_000, 10_000_000, 100_000_000]
        XCTAssertEqual(ChapterCatalog.thresholds.count, 19)
        XCTAssertEqual(ChapterCatalog.thresholds.map { $0.id }, (1...19).map { String(format: "ch%02d", $0) })
        XCTAssertEqual(ChapterCatalog.thresholds.map { $0.n }, expected)
        for (a, b) in zip(ChapterCatalog.thresholds, ChapterCatalog.thresholds.dropFirst()) {
            XCTAssertLessThan(a.n, b.n)
        }
        XCTAssertEqual(ChapterCatalog.ids.count, 19)
    }
}
