// DataLayerDebtTests.swift
// ZKR-61: техдолг слоя данных по итогам QA PR #7 (пункты a–e).

import XCTest
import ZikrCore
import ZikrDomain
@testable import ZikrPersistence

/// Читатель файла, который первые `failures` раз падает с ошибкой ввода-вывода
/// (как при защите данных до первой разблокировки).
final class FlakyReader: @unchecked Sendable {
    private let lock = NSLock()
    private var failuresLeft: Int
    private var calls = 0

    init(failures: Int) { failuresLeft = failures }

    func read(_ url: URL) throws -> Data {
        lock.lock()
        calls += 1
        let fail = failuresLeft > 0
        if fail { failuresLeft -= 1 }
        lock.unlock()
        if fail { throw CocoaError(.fileReadNoPermission) }
        return try Data(contentsOf: url)
    }

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }
}

/// Записывает, на каком потоке вызывался читатель progress.json.
final class ThreadProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var flags: [Bool] = []

    func record(_ isMain: Bool) {
        lock.lock()
        flags.append(isMain)
        lock.unlock()
    }

    var values: [Bool] {
        lock.lock()
        defer { lock.unlock() }
        return flags
    }
}

// MARK: - (b) ошибка чтения ≠ повреждённый файл

final class StoreReadErrorTests: TempDirTestCase {
    private func corruptNames() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasPrefix("zikr-state.corrupt-") }
    }

    func testUnreadableFileIsKeptAndNotOverwritten() async throws {
        _ = await makeStore().bootstrap(LegacySources(webLiveJSON: stateJSON(total: 5)))
        let before = try Data(contentsOf: stateURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: stateURL.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: stateURL.path) }

        let store = makeStore()
        let result = await store.bootstrap(LegacySources(webLiveJSON: stateJSON(total: 99)))
        XCTAssertEqual(result, .unavailable(reason: "zikr-state.json unreadable"))
        let wrote = await store.replaceFromWeb(json: stateJSON(total: 77))
        XCTAssertFalse(wrote)
        let doc = await store.document()
        XCTAssertNil(doc)

        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: stateURL.path)
        XCTAssertEqual(try Data(contentsOf: stateURL), before)
        XCTAssertEqual(try corruptNames(), [])

        // Файл снова читается — тот же экземпляр хранилища подхватывает его без потерь.
        let again = await store.bootstrap(LegacySources(webLiveJSON: stateJSON(total: 99)))
        XCTAssertEqual(again, .existing)
        let wroteNow = await store.replaceFromWeb(json: stateJSON(total: 6))
        XCTAssertTrue(wroteNow)
        XCTAssertEqual(try readDocument().progress.total, 6)
    }

    func testReadErrorIsRetriedOnNextAccess() async throws {
        _ = await makeStore().bootstrap(LegacySources(webLiveJSON: stateJSON(total: 5)))
        let before = try Data(contentsOf: stateURL)
        let reader = FlakyReader(failures: 2)
        let store = JSONStateStore(fileURL: stateURL, clock: FixedClock(fixedDate), appVersion: "1.2.0-test",
                                   preferredLanguages: testLanguages, readData: { try reader.read($0) })

        let first = await store.bootstrap(LegacySources(webLiveJSON: stateJSON(total: 99)))
        XCTAssertEqual(first, .unavailable(reason: "zikr-state.json unreadable"))
        do {
            _ = try await store.update { $0.total += 1 }
            XCTFail("update must throw while the file is unreadable")
        } catch AppError.storageRead(_) {
        } catch {
            XCTFail("unexpected error \(error)")
        }
        XCTAssertEqual(try Data(contentsOf: stateURL), before)

        let doc = await store.document()
        XCTAssertEqual(doc?.progress.total, 5)
        XCTAssertEqual(reader.callCount, 3)
        let again = await store.bootstrap(LegacySources(webLiveJSON: stateJSON(total: 99)))
        XCTAssertEqual(again, .existing)
        XCTAssertEqual(reader.callCount, 3, "после успешного чтения файл больше не перечитывается")
        let updated = try await store.update { $0.total += 1 }
        XCTAssertEqual(updated.total, 6)
        XCTAssertEqual(try readDocument().progress.total, 6)
        XCTAssertEqual(try corruptNames(), [])
    }

    func testDecodeErrorThroughReaderIsStillQuarantined() async throws {
        try Data("not json".utf8).write(to: stateURL)
        let reader = FlakyReader(failures: 0)
        let store = JSONStateStore(fileURL: stateURL, clock: FixedClock(fixedDate), appVersion: "1.2.0-test",
                                   preferredLanguages: testLanguages, readData: { try reader.read($0) })
        let result = await store.bootstrap(LegacySources(webLiveJSON: stateJSON(total: 3)))
        XCTAssertEqual(result, .created(from: "webLive"))
        XCTAssertEqual(try corruptNames().count, 1)
        XCTAssertEqual(try readDocument().progress.total, 3)
    }
}

// MARK: - (d) ошибка кодирования при слиянии не теряет состояние

final class MergerEncodingFailureTests: XCTestCase {
    private let a = "{\"v\":2,\"total\":10,\"daily\":{\"2026-10-22\":10},\"unlocked\":[\"ch01\"],\"viewed\":[\"ch01\"],\"settings\":{\"lang\":\"en\"},\"onboarded\":false}"
    private let b = "{\"v\":2,\"total\":20,\"daily\":{\"2026-10-23\":20},\"unlocked\":[\"ch02\"],\"viewed\":[],\"settings\":{\"lang\":\"uz\"},\"onboarded\":true,\"city\":\"medina\"}"

    func testEncodingFailureKeepsMergedState() {
        let merged = StateMerger.merge(sanitize(a), sanitize(b), preferredLanguages: testLanguages, encode: { _ in nil })
        XCTAssertNotEqual(merged, ProgressState.fresh(preferredLanguages: testLanguages))
        XCTAssertEqual(merged.total, 20)
        XCTAssertEqual(merged.unlocked, ["ch01", "ch02"])
        XCTAssertEqual(merged.daily, ["2026-10-22": 10, "2026-10-23": 20])
        XCTAssertEqual(merged.settings.lang, .uz)
        XCTAssertEqual(merged.city, "medina")
        XCTAssertTrue(merged.onboarded)
        XCTAssertEqual(merged, StateMerger.merge(sanitize(a), sanitize(b), preferredLanguages: testLanguages))
    }
}

// MARK: - (e) total = 0 без updatedAt — как в JS

final class MigratorZeroTotalTests: XCTestCase {
    private func native(updatedAt: Int64? = nil) -> String {
        let u = updatedAt.map { ",\"updatedAt\":\($0)" } ?? ""
        return "{\"v\":2,\"total\":0,\"daily\":{\"2026-10-23\":0},\"unlocked\":[\"ch01\"],\"viewed\":[\"ch01\"],\"settings\":{\"lang\":\"tg\",\"goal\":330},\"onboarded\":true,\"city\":\"medina\"\(u)}"
    }

    func testZeroTotalWithoutUpdatedAtMergesWithFreshLikeJS() throws {
        // JS: loadLocal() → freshState(); mergeStates(fresh, backup) берёт базу fresh (total 0 >= 0).
        let r = try XCTUnwrap(LegacyMigrator.resolve(LegacySources(progressFileJSON: native()), preferredLanguages: testLanguages))
        XCTAssertEqual(r.1, "progressFile")
        XCTAssertEqual(r.0.total, 0)
        XCTAssertEqual(r.0.settings, AppSettings.defaults(preferredLanguages: testLanguages))
        XCTAssertNil(r.0.city)
        XCTAssertEqual(r.0.unlocked, ["ch01"])
        XCTAssertEqual(r.0.viewed, ["ch01"])
        XCTAssertEqual(r.0.daily, ["2026-10-23": 0])
        XCTAssertTrue(r.0.onboarded)
        XCTAssertNil(r.0.updatedAt)
    }

    func testZeroTotalWithUpdatedAtKeepsNative() throws {
        let r = try XCTUnwrap(LegacyMigrator.resolve(LegacySources(progressFileJSON: native(updatedAt: 5)), preferredLanguages: testLanguages))
        XCTAssertEqual(r.1, "progressFile")
        XCTAssertEqual(r.0.settings.lang, .tg)
        XCTAssertEqual(r.0.settings.goal, 330)
        XCTAssertEqual(r.0.city, "medina")
        XCTAssertEqual(r.0.updatedAt, 5)
    }

    func testPositiveTotalWithoutUpdatedAtKeepsNative() throws {
        let r = try XCTUnwrap(LegacyMigrator.resolve(LegacySources(progressFileJSON: try Fixture.text("progress-1.0.0.json")),
                                                     preferredLanguages: testLanguages))
        XCTAssertEqual(r.0.total, 137)
        XCTAssertEqual(r.0.settings.lang, .tg)
    }
}

// MARK: - (c) progress.json читается не на главном потоке; (a) ранний снимок не теряется

final class MirrorFallbackTests: TempDirTestCase {
    @MainActor
    func testFallbackReadsProgressFileOffMainThread() async throws {
        try Fixture.data("progress-1.1.1.json").write(to: progressURL)
        let probe = ThreadProbe()
        let mirror = WebStateMirror(store: makeStore(), progressFileReader: { url in
            probe.record(Thread.isMainThread)
            return LegacySources.progressFile(at: url).progressFileJSON
        })
        XCTAssertTrue(Thread.isMainThread)
        mirror.enqueueFallback(progressFileURL: progressURL, localStorageV2: nil, localStorageV1: nil)
        await mirror.flushForTesting()
        XCTAssertEqual(probe.values, [false])
        let doc = try readDocument()
        XCTAssertEqual(doc.meta.createdFrom, "progressFile")
        XCTAssertEqual(doc.progress.total, 1234)
    }

    @MainActor
    func testFallbackPassesLocalStorage() async throws {
        try Fixture.data("progress-1.1.1.json").write(to: progressURL)
        let mirror = WebStateMirror(store: makeStore())
        let v2 = stateJSON(total: 5000, extra: ",\"updatedAt\":9999999999999")
        mirror.enqueueFallback(progressFileURL: progressURL, localStorageV2: v2, localStorageV1: nil)
        await mirror.flushForTesting()
        let doc = try readDocument()
        XCTAssertEqual(doc.meta.createdFrom, "localStorageV2")
        XCTAssertEqual(doc.progress.total, 5000)
    }

    @MainActor
    func testFallbackWithoutProgressFileURL() async throws {
        let mirror = WebStateMirror(store: makeStore(), progressFileReader: { _ in
            XCTFail("reader must not be called without URL")
            return nil
        })
        mirror.enqueueFallback(progressFileURL: nil, localStorageV2: nil, localStorageV1: stateJSON(total: 7))
        await mirror.flushForTesting()
        XCTAssertEqual(try readDocument().progress.total, 7)
    }

    /// (a) Снимок, пришедший до bootstrap (зеркало подключено до загрузки страницы),
    /// сохраняется и не перезаписывается последующей миграцией из progress.json.
    @MainActor
    func testSnapshotBeforeBootstrapIsKept() async throws {
        try Fixture.data("progress-1.1.1.json").write(to: progressURL)
        let store = makeStore()
        let mirror = WebStateMirror(store: store)
        mirror.enqueue(stateJSON(total: 50))
        await mirror.flushForTesting()
        let result = await store.bootstrap(.progressFile(at: progressURL))
        XCTAssertEqual(result, .existing)
        XCTAssertEqual(try readDocument().progress.total, 50)
        XCTAssertEqual(try readDocument().meta.createdFrom, "webLive")
    }
}
