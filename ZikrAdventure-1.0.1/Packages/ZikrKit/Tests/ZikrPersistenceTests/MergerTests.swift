import XCTest
import ZikrCore
import ZikrDomain
@testable import ZikrPersistence

final class MergerTests: XCTestCase {
    // 5.1
    func testMerge() {
        let a = sanitize("{\"total\":10,\"daily\":{\"d1\":10,\"d2\":1},\"unlocked\":[\"ch01\"],\"viewed\":[\"x\",\"y\"],\"onboarded\":false,\"settings\":{\"lang\":\"en\",\"goal\":300},\"city\":\"mecca\"}")
        let b = sanitize("{\"total\":20,\"daily\":{\"d2\":5,\"d3\":7},\"unlocked\":[\"ch02\",\"ch01\"],\"viewed\":[\"y\",\"z\"],\"onboarded\":true,\"settings\":{\"lang\":\"uz\",\"goal\":500},\"city\":\"medina\"}")
        let m = StateMerger.merge(a, b)
        XCTAssertEqual(m.total, 20)
        XCTAssertEqual(m.daily, ["d1": 10, "d2": 5, "d3": 7])
        XCTAssertEqual(m.unlocked, ["ch01", "ch02"])
        XCTAssertEqual(m.viewed, ["x", "y", "z"])
        XCTAssertTrue(m.onboarded)
        XCTAssertEqual(m.settings.lang, .uz, "settings от копии с большим total")
        XCTAssertEqual(m.settings.goal, 500)
        XCTAssertEqual(m.city, "medina")

        // При равенстве total база — a.
        let tie = StateMerger.merge(sanitize("{\"total\":5,\"settings\":{\"lang\":\"kk\"}}"), sanitize("{\"total\":5,\"settings\":{\"lang\":\"ky\"}}"))
        XCTAssertEqual(tie.settings.lang, .kk)
    }
}
