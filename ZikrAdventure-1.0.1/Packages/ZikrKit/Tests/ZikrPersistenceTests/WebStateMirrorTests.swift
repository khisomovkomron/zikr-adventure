import XCTest
import ZikrCore
import ZikrDomain
@testable import ZikrPersistence

final class WebStateMirrorTests: TempDirTestCase {
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
