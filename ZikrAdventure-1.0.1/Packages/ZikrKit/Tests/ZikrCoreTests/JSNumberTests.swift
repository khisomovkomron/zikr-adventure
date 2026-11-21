import XCTest
@testable import ZikrCore

final class JSNumberTests: XCTestCase {
    // 1.3
    func testRoundMatchesMathRound() {
        XCTAssertEqual(JSNumber.round(0.5), 1)
        XCTAssertEqual(JSNumber.round(-0.5), 0)
        XCTAssertEqual(JSNumber.round(1.5), 2)
        XCTAssertEqual(JSNumber.round(-1.5), -1)
        XCTAssertEqual(JSNumber.round(2.4), 2)
    }

    func testMaxSafeInteger() {
        XCTAssertEqual(JSNumber.maxSafeInteger, 9_007_199_254_740_991)
        XCTAssertEqual(JSNumber.clampedInt64(1e20), JSNumber.maxSafeInteger)
        XCTAssertNil(JSNumber.clampedInt64(.nan))
    }
}
