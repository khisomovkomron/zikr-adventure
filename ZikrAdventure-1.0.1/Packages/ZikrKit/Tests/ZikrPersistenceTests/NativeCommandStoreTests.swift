import XCTest
import ZikrCore
import ZikrDomain
@testable import ZikrPersistence

final class NativeCommandStoreTests: TempDirTestCase {
    private let catalog = NativeCommandCatalog(cityIDs: ["mecca", "medina"],
                                                chapterCities: ["ch01": "mecca", "ch09": "medina"])

    private func seeded(_ progress: ProgressState = ProgressState()) async throws -> JSONStateStore {
        let store = makeStore()
        let data = try JSONEncoder().encode(progress)
        _ = await store.bootstrap(LegacySources(webLiveJSON: String(decoding: data, as: UTF8.self)))
        return store
    }

    func testConcurrentTapsAreAtomicAndPersistAcrossRestart() async throws {
        let store = try await seeded()
        let catalog = catalog
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<200 {
                group.addTask { _ = try await store.execute(.tap, catalog: catalog) }
            }
            try await group.waitForAll()
        }
        let restored = await makeStore().document()
        XCTAssertEqual(restored?.progress.total, 200)
        XCTAssertEqual(restored?.progress.daily.values.reduce(0, +), 200)
        XCTAssertEqual(restored?.progress.unlocked, ["ch01", "ch02", "ch03", "ch04"])
        XCTAssertEqual(restored?.progress.updatedAt,
                       Int64(fixedDate.timeIntervalSince1970 * 1000) + 199)
    }

    func testOnboardingAndViewedAreIdempotentWithoutRewritingFile() async throws {
        let store = try await seeded(ProgressState(total: 10, unlocked: ["ch01"]))
        _ = try await store.execute(.completeOnboarding, catalog: catalog)
        _ = try await store.execute(.markViewed("ch01"), catalog: catalog)
        let bytes = try Data(contentsOf: stateURL)
        let onb = try await store.execute(.completeOnboarding, catalog: catalog)
        let viewed = try await store.execute(.markViewed("ch01"), catalog: catalog)
        XCTAssertFalse(try XCTUnwrap(onb).didChange)
        XCTAssertFalse(try XCTUnwrap(viewed).didChange)
        XCTAssertEqual(try Data(contentsOf: stateURL), bytes)
    }

    func testRejectedCommandAndZeroUndoDoNotWrite() async throws {
        let store = try await seeded()
        let bytes = try Data(contentsOf: stateURL)
        for command: NativeProgressCommand in [.undo, .markViewed("ch01"), .selectCity("unknown"),
                                               .saveCamera("mecca", .init(x: .nan, y: 0, z: 1))] {
            let result = try await store.execute(command, catalog: catalog)
            XCTAssertNil(result)
        }
        XCTAssertEqual(try Data(contentsOf: stateURL), bytes)
    }

    func testWriteFailureDoesNotConfirmOrPublishProgress() async throws {
        let store = try await seeded(ProgressState(total: 9))
        // Заменяем целевой файл каталогом: атомарная запись обязана завершиться ошибкой.
        try FileManager.default.removeItem(at: stateURL)
        try FileManager.default.createDirectory(at: stateURL, withIntermediateDirectories: false)
        do {
            _ = try await store.execute(.tap, catalog: catalog)
            XCTFail("Failed write must throw rather than acknowledge a tap")
        } catch AppError.storageWrite(_) { }
        let document = await store.document()
        XCTAssertEqual(document?.progress.total, 9)
        XCTAssertEqual(document?.progress.unlocked, [])
    }

    func testUnbootstrappedUnavailableAndFutureStoresNeverCreateFreshProgress() async throws {
        let empty = makeStore()
        do {
            _ = try await empty.execute(.tap, catalog: catalog)
            XCTFail("bootstrap required")
        } catch NativeCommandError.notBootstrapped { }
        XCTAssertFalse(FileManager.default.fileExists(atPath: stateURL.path))

        for bytes in [Data("{\"schemaVersion\":999}".utf8), try Fixture.data("progress-1.1.1.json")] {
            try bytes.write(to: stateURL)
            let store = JSONStateStore(fileURL: stateURL, appVersion: "test", readData: { _ in
                throw CocoaError(.fileReadNoPermission)
            })
            do {
                _ = try await store.execute(.tap, catalog: catalog)
                XCTFail("unavailable storage must block commands")
            } catch NativeCommandError.notBootstrapped { }
            XCTAssertEqual(try Data(contentsOf: stateURL), bytes)
        }
        let future = makeStore()
        try Data("{\"schemaVersion\":999}".utf8).write(to: stateURL)
        do {
            _ = try await future.execute(.tap, catalog: catalog)
            XCTFail("future schema must block commands")
        } catch NativeCommandError.notBootstrapped { }
        XCTAssertEqual(try Data(contentsOf: stateURL), Data("{\"schemaVersion\":999}".utf8))
    }
}
