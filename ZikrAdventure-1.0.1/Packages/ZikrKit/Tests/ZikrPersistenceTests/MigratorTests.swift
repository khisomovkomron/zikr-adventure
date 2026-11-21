import XCTest
import ZikrCore
import ZikrDomain
@testable import ZikrPersistence

final class MigratorTests: XCTestCase {
    private func resolve(_ s: LegacySources) -> (ProgressState, String)? {
        LegacyMigrator.resolve(s, preferredLanguages: testLanguages)
    }

    private func v2(total: Int, updatedAt: Int64? = nil, onboarded: Bool = true) -> String {
        let u = updatedAt.map { ",\"updatedAt\":\($0)" } ?? ""
        return "{\"v\":2,\"total\":\(total),\"daily\":{\"2026-10-23\":\(total)},\"unlocked\":[\"ch01\"],\"viewed\":[],\"settings\":{\"lang\":\"en\"},\"onboarded\":\(onboarded)\(u)}"
    }

    // 4.1
    func testOnlyProgressFile() throws {
        let r = try XCTUnwrap(resolve(LegacySources(progressFileJSON: try Fixture.text("progress-1.0.0.json"))))
        XCTAssertEqual(r.1, "progressFile")
        XCTAssertEqual(r.0.total, 137)
        XCTAssertEqual(r.0.settings.lang, .tg)
        XCTAssertNil(r.0.updatedAt)
    }

    // 4.2
    func testWebLiveWins() throws {
        let r = try XCTUnwrap(resolve(LegacySources(progressFileJSON: try Fixture.text("progress-1.1.1.json"),
                                                    webLiveJSON: v2(total: 5), localStorageV2: v2(total: 9999))))
        XCTAssertEqual(r.1, "webLive")
        XCTAssertEqual(r.0.total, 5)
    }

    // 4.3
    func testNewerUpdatedAtWins() throws {
        let native = v2(total: 100, updatedAt: 2_000)
        var r = try XCTUnwrap(resolve(LegacySources(progressFileJSON: native, localStorageV2: v2(total: 50, updatedAt: 3_000))))
        XCTAssertEqual(r.1, "localStorageV2")
        XCTAssertEqual(r.0.total, 50)
        r = try XCTUnwrap(resolve(LegacySources(progressFileJSON: native, localStorageV2: v2(total: 50, updatedAt: 1_000))))
        XCTAssertEqual(r.1, "progressFile")
        XCTAssertEqual(r.0.total, 100)
        r = try XCTUnwrap(resolve(LegacySources(progressFileJSON: native, localStorageV2: v2(total: 50, updatedAt: 2_000))))
        XCTAssertEqual(r.1, "localStorageV2")
        XCTAssertEqual(r.0.total, 50)
    }

    // 4.4
    func testLocalUpdatedAtOnlyGivesNative() throws {
        let r = try XCTUnwrap(resolve(LegacySources(progressFileJSON: v2(total: 10), localStorageV2: v2(total: 99, updatedAt: 5_000))))
        XCTAssertEqual(r.1, "progressFile")
        XCTAssertEqual(r.0.total, 10)
    }

    // 4.5
    func testNoUpdatedAtMerges() throws {
        let local = "{\"total\":30,\"daily\":{\"a\":30},\"unlocked\":[\"ch01\",\"ch02\"],\"viewed\":[\"ch01\"],\"onboarded\":false}"
        let native = "{\"total\":20,\"daily\":{\"a\":5,\"b\":15},\"unlocked\":[\"ch03\"],\"viewed\":[\"ch02\"],\"onboarded\":true}"
        let r = try XCTUnwrap(resolve(LegacySources(progressFileJSON: native, localStorageV2: local)))
        XCTAssertEqual(r.0.total, 30)
        XCTAssertEqual(r.0.daily, ["a": 30, "b": 15])
        XCTAssertEqual(r.0.unlocked, ["ch01", "ch02", "ch03"])
        XCTAssertEqual(r.0.viewed, ["ch01", "ch02"])
        XCTAssertTrue(r.0.onboarded)
    }

    // 4.6
    func testOnlyV1() throws {
        let r = try XCTUnwrap(resolve(LegacySources(localStorageV1: try Fixture.text("localStorage-v1.json"))))
        XCTAssertEqual(r.1, "localStorageV1")
        XCTAssertEqual(r.0.total, 42)
        XCTAssertEqual(r.0.daily, ["2025-01-01": 30, "2025-01-02": 12])
        XCTAssertTrue(r.0.onboarded)
        XCTAssertFalse(r.0.settings.haptics)
        XCTAssertTrue(r.0.settings.sound)
        XCTAssertEqual(r.0.settings.goal, 50)
        XCTAssertEqual(r.0.settings.lang, .ru, "lang из v1 игнорируется")
        XCTAssertTrue(r.0.settings.animations)
    }

    // 4.7
    func testBrokenV2AndNothing() throws {
        let r = try XCTUnwrap(resolve(LegacySources(localStorageV2: "{битый", localStorageV1: try Fixture.text("localStorage-v1.json"))))
        XCTAssertEqual(r.0, ProgressState.fresh(preferredLanguages: testLanguages))
        XCTAssertEqual(r.1, "fresh")
        XCTAssertNil(resolve(LegacySources()))
        XCTAssertNil(resolve(LegacySources(progressFileJSON: "null")))
    }
}
