import XCTest
import ZikrCore
import ZikrDomain
@testable import ZikrPersistence
#if canImport(CryptoKit)
import CryptoKit
#endif

final class JSONStateStoreTests: TempDirTestCase {
    private func digest(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        #if canImport(CryptoKit)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        #else
        return data.base64EncodedString()
        #endif
    }

    private func installProgressFile(_ fixture: String = "progress-1.1.1.json") throws {
        try Fixture.data(fixture).write(to: progressURL)
    }

    private func mtime(_ url: URL) throws -> Date {
        try XCTUnwrap(try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)
    }

    // 6.1
    func testCreatesFromProgressFile() async throws {
        try installProgressFile()
        let store = makeStore()
        let result = await store.bootstrap(.progressFile(at: progressURL))
        XCTAssertEqual(result, .created(from: "progressFile"))
        let doc = try readDocument()
        XCTAssertEqual(doc.schemaVersion, 3)
        XCTAssertEqual(doc.meta.createdFrom, "progressFile")
        XCTAssertEqual(doc.meta.createdAt, fixedDate)
        XCTAssertEqual(doc.meta.writtenByAppVersion, "1.2.0-test")
        XCTAssertEqual(doc.progress.total, 1234)
        XCTAssertEqual(doc.progress.city, "medina")
        let cached = await store.document()
        XCTAssertEqual(cached, doc)
    }

    // 6.2
    func testBootstrapIsIdempotent() async throws {
        try installProgressFile()
        _ = await makeStore().bootstrap(.progressFile(at: progressURL))
        let before = try Data(contentsOf: stateURL)
        let store = makeStore(clock: fixedDate.addingTimeInterval(3600))
        let again = await store.bootstrap(.progressFile(at: progressURL))
        XCTAssertEqual(again, .existing)
        let sameStoreAgain = await store.bootstrap(LegacySources(webLiveJSON: stateJSON(total: 1)))
        XCTAssertEqual(sameStoreAgain, .existing)
        XCTAssertEqual(try Data(contentsOf: stateURL), before)
    }

    // 6.3
    func testCorruptFileIsQuarantined() async throws {
        try installProgressFile()
        try Fixture.data("corrupt.txt").write(to: stateURL)
        let result = await makeStore().bootstrap(.progressFile(at: progressURL))
        XCTAssertEqual(result, .created(from: "progressFile"))
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        let corrupt = names.filter { $0.hasPrefix("zikr-state.corrupt-") && $0.hasSuffix(".json") }
        XCTAssertEqual(corrupt, ["zikr-state.corrupt-\(Int64(fixedDate.timeIntervalSince1970 * 1000)).json"])
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(corrupt[0])), try Fixture.data("corrupt.txt"))
        XCTAssertEqual(try readDocument().progress.total, 1234)
    }

    func testOlderSchemaIsQuarantined() async throws {
        let old = "{\"schemaVersion\":2,\"progress\":{},\"meta\":{}}"
        try Data(old.utf8).write(to: stateURL)
        let result = await makeStore().bootstrap(LegacySources())
        XCTAssertEqual(result, .empty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stateURL.path))
    }

    // 6.4
    func testFutureSchemaIsReadOnly() async throws {
        try Fixture.data("future-schema.json").write(to: stateURL)
        let before = try Data(contentsOf: stateURL)
        let store = makeStore()
        let result = await store.bootstrap(.progressFile(at: progressURL))
        guard case .readOnly = result else { return XCTFail("expected readOnly, got \(result)") }
        let wrote = await store.replaceFromWeb(json: stateJSON(total: 7))
        XCTAssertFalse(wrote)
        do {
            _ = try await store.update { $0.total = 1 }
            XCTFail("update must throw")
        } catch {
            XCTAssertEqual(error as? AppError, .unsupportedSchema(99))
        }
        XCTAssertEqual(try Data(contentsOf: stateURL), before)
    }

    // 6.5
    func testReplaceWithoutMaxMerge() async throws {
        let store = makeStore()
        let first = await store.replaceFromWeb(json: stateJSON(total: 500))
        XCTAssertTrue(first)
        let second = await store.replaceFromWeb(json: stateJSON(total: 0))
        XCTAssertTrue(second)
        XCTAssertEqual(try readDocument().progress.total, 0)
        XCTAssertEqual(try readDocument().meta.lastWebSyncAt, fixedDate)
    }

    // 6.6
    func testSameJSONWrittenOnce() async throws {
        let store = makeStore()
        let first = await store.replaceFromWeb(json: stateJSON(total: 3))
        XCTAssertTrue(first)
        let before = try mtime(stateURL)
        try await Task.sleep(nanoseconds: 50_000_000)
        let second = await store.replaceFromWeb(json: stateJSON(total: 3))
        XCTAssertFalse(second)
        XCTAssertEqual(try mtime(stateURL), before)

        // Тот же документ, прочитанный новым экземпляром, тоже не переписывается.
        let reopened = makeStore()
        let third = await reopened.replaceFromWeb(json: stateJSON(total: 3))
        XCTAssertFalse(third)
    }

    // 6.7
    func testProgressFileIsNeverModified() async throws {
        try installProgressFile()
        let before = try digest(progressURL)
        let store = makeStore()
        _ = await store.bootstrap(.progressFile(at: progressURL))
        _ = await store.replaceFromWeb(json: stateJSON(total: 1))
        _ = try await store.update { $0.total += 1 }
        _ = await store.replaceFromWeb(json: "{oops")
        XCTAssertEqual(try digest(progressURL), before)
    }

    // 6.8
    func testEmptyThenFirstSnapshotCreates() async throws {
        let store = makeStore()
        let result = await store.bootstrap(.progressFile(at: progressURL))
        XCTAssertEqual(result, .empty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stateURL.path))
        let wrote = await store.replaceFromWeb(json: stateJSON(total: 9))
        XCTAssertTrue(wrote)
        let doc = try readDocument()
        XCTAssertEqual(doc.meta.createdFrom, "webLive")
        XCTAssertEqual(doc.progress.total, 9)
        let invalid = await store.replaceFromWeb(json: "not json")
        XCTAssertFalse(invalid)
    }

    // 6.9
    func testUpdateWritesAndNotifies() async throws {
        let store = makeStore()
        let stream = await store.changes()
        let updated = try await store.update { $0.total = 77 }
        XCTAssertEqual(updated.total, 77)
        XCTAssertEqual(try readDocument().progress.total, 77)
        var iterator = stream.makeAsyncIterator()
        let received = await iterator.next()
        XCTAssertEqual(received?.total, 77)
    }

    func testWritesIntoMissingDirectory() async throws {
        let nested = dir.appendingPathComponent("a/b/zikr-state.json")
        let store = JSONStateStore(fileURL: nested, clock: FixedClock(fixedDate), appVersion: "t", preferredLanguages: testLanguages)
        let wrote = await store.replaceFromWeb(json: stateJSON(total: 1))
        XCTAssertTrue(wrote)
        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path))
    }
}
