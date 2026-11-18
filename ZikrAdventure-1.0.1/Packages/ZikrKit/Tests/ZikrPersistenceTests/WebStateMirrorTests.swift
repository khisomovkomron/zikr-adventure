import XCTest
import ZikrCore
import ZikrDomain
@testable import ZikrPersistence

final class WebStateMirrorTests: TempDirTestCase {
    func testUnreadableStoreResumesWithLatestSnapshotAfterAvailabilitySignal() async throws {
        _ = await makeStore().bootstrap(LegacySources(webLiveJSON: stateJSON(total: 5)))
        let reader = FlakyReader(failures: 1)
        let store = JSONStateStore(fileURL: stateURL, appVersion: "1.2.0-test",
                                   readData: { try reader.read($0) })
        let mirror = WebStateMirror(store: store)
        mirror.enqueue(stateJSON(total: 10))
        await mirror.flushForTesting()
        mirror.enqueue(stateJSON(total: 20))
        await mirror.flushForTesting()
        XCTAssertEqual(reader.callCount, 1)
        XCTAssertEqual(try readDocument().progress.total, 5)
        await mirror.retryUnreadableFile()
        mirror.enqueue(stateJSON(total: 30))
        await mirror.flushForTesting()
        XCTAssertEqual(reader.callCount, 2)
        XCTAssertEqual(try readDocument().progress.total, 30)
    }

    // 7.1
    func testThousandSnapshotsCoalesce() async throws {
        let mirror = WebStateMirror(store: makeStore())
        for total in 1...1000 { mirror.enqueue(stateJSON(total: total)) }
        await mirror.flushForTesting()
        XCTAssertEqual(try readDocument().progress.total, 1000)
    }

    // 7.2
    func testInvalidJSONDoesNotStopQueue() async throws {
        let mirror = WebStateMirror(store: makeStore())
        mirror.enqueue("{broken")
        await mirror.flushForTesting()
        mirror.enqueue(stateJSON(total: 42))
        await mirror.flushForTesting()
        XCTAssertEqual(try readDocument().progress.total, 42)
        mirror.enqueue("[]")
        mirror.enqueue("{also broken")
        await mirror.flushForTesting()
        XCTAssertEqual(try readDocument().progress.total, 42)
    }

    func testFallbackBootstrapsAndDoesNotOverwrite() async throws {
        let store = makeStore()
        let mirror = WebStateMirror(store: store)
        mirror.enqueueFallback(LegacySources(localStorageV2: stateJSON(total: 12)))
        await mirror.flushForTesting()
        XCTAssertEqual(try readDocument().meta.createdFrom, "localStorageV2")
        XCTAssertEqual(try readDocument().progress.total, 12)
        mirror.enqueue(stateJSON(total: 13))
        mirror.enqueueFallback(LegacySources(localStorageV2: stateJSON(total: 1)))
        await mirror.flushForTesting()
        XCTAssertEqual(try readDocument().progress.total, 13)
    }
}
