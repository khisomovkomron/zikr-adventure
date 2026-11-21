import XCTest
import ZikrCore
import ZikrDomain
@testable import ZikrPersistence

final class NativeActivationTests: TempDirTestCase {
    private let catalog = NativeCommandCatalog(cityIDs: ["mecca"], chapterCities: ["ch01": "mecca"])

    func testDirectLegacyUpgradeRetainsSettingsHistoryAndOnboarding() async throws {
        let store = makeStore()
        let json = try Fixture.text("progress-1.1.1.json")
        try await store.activateNative(LegacySources(localStorageV2: json))
        let document = try XCTUnwrap(try readDocument())
        XCTAssertEqual(document.progress, sanitize(json))
        XCTAssertEqual(document.meta.nativeWriterActivated, true)
        XCTAssertEqual(document.schemaVersion, 3)
    }

    func testNewerLegacyResetWinsOverHigherStaleMirror() async throws {
        let store = makeStore()
        _ = await store.bootstrap(LegacySources(webLiveJSON: stateJSON(total: 100, extra: ",\"updatedAt\":100")))
        try await store.activateNative(LegacySources(localStorageV2: stateJSON(total: 0, extra: ",\"updatedAt\":200")))
        XCTAssertEqual(try readDocument().progress.total, 0)
        XCTAssertEqual(try readDocument().progress.updatedAt, 200)
    }

    func testNativeResetCannotBeResurrectedByLegacyOrWebSave() async throws {
        let store = makeStore()
        let old = stateJSON(total: 100, extra: ",\"updatedAt\":100")
        try await store.activateNative(LegacySources(progressFileJSON: old))
        _ = try await store.execute(.resetProgress, catalog: catalog)
        let before = try Data(contentsOf: stateURL)
        let restarted = makeStore()
        try await restarted.activateNative(LegacySources(webLiveJSON: stateJSON(total: 999, extra: ",\"updatedAt\":9999999999999")))
        let accepted = await restarted.replaceFromWeb(json: old)
        XCTAssertFalse(accepted)
        XCTAssertEqual(try Data(contentsOf: stateURL), before)
        XCTAssertEqual(try readDocument().progress.total, 0)
    }

    func testNativeCommandsRequireActivationEvenWithShadowFile() async throws {
        let store = makeStore()
        _ = await store.bootstrap(LegacySources(webLiveJSON: stateJSON(total: 8)))
        do { _ = try await store.execute(.tap, catalog: catalog); XCTFail("Shadow state cannot accept native writes") }
        catch NativeCommandError.notBootstrapped { }
        XCTAssertEqual(try readDocument().progress.total, 8)
    }

    func testMissingSourcesInitializeOnceButUnreadableFileDoesNot() async throws {
        let store = makeStore()
        try await store.activateNative(LegacySources())
        XCTAssertEqual(try readDocument().progress.total, 0)
        let before = try Data(contentsOf: stateURL)
        let blocked = JSONStateStore(fileURL: stateURL, appVersion: "test", readData: { _ in throw CocoaError(.fileReadNoPermission) })
        do { try await blocked.activateNative(LegacySources()); XCTFail("Unavailable native file must block activation") }
        catch AppError.storageRead(_) { }
        XCTAssertEqual(try Data(contentsOf: stateURL), before)
    }

    func testUnreadableParentIsNotMistakenForMissingFileAndRecovers() async throws {
        let parent = dir.appendingPathComponent("protected", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        let url = parent.appendingPathComponent("zikr-state.json")
        let original = JSONStateStore(fileURL: url, appVersion: "test")
        try await original.activateNative(LegacySources(webLiveJSON: stateJSON(total: 99)))
        let bytes = try Data(contentsOf: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: parent.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path) }
        let store = JSONStateStore(fileURL: url, appVersion: "test")
        let unavailable = await store.document()
        XCTAssertNil(unavailable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path)
        await store.retryUnreadableFile()
        try await store.activateNative(LegacySources())
        let restored = await store.document()
        XCTAssertEqual(restored?.progress.total, 99)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
}
