import XCTest
import WebKit
import ZikrDomain
import ZikrPersistence
@testable import ZikrAdventure

@MainActor
final class NativeRuntimeTests: XCTestCase {
    private var directory: URL!
    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDown() async throws { try? FileManager.default.removeItem(at: directory) }
    private func container(_ reader: StubLegacyReader) -> AppContainer {
        AppContainer(stateFileURL: directory.appendingPathComponent("state.json"), legacyProgressFileURL: nil,
                     appVersion: "test", auth: FakeAuthService(state: .guest),
                     localization: LocalizationService(defaults: nil), legacyReader: reader)
    }

    func testBootstrapSwitchesAllSinksAndNeverReimportsAfterReset() async throws {
        let reader = StubLegacyReader()
        reader.sources = LegacySources(localStorageV2: "{\"total\":12,\"onboarded\":true,\"settings\":{\"lang\":\"ky\"}}")
        let app = container(reader)
        await app.bootstrap()
        XCTAssertTrue(app.isNativeReady)
        XCTAssertEqual(reader.calls, 1)
        XCTAssertEqual(app.localization.language, .ky)
        let tapped = await app.zikrSink.tap()
        XCTAssertEqual(tapped?.total, 13)
        let setting = await app.settingsSink.set(.goal(333))
        XCTAssertTrue(setting)
        let camera = await app.mapSink.saveCamera(cityID: "mecca", x: 2, y: 3, z: 1)
        XCTAssertTrue(camera)
        let viewed = await app.siraSink.markViewed(chapterID: "ch01")
        XCTAssertTrue(viewed)
        let reset = await app.settingsSink.resetProgress()
        XCTAssertTrue(reset)
        let blocked = StubLegacyReader(); blocked.fails = true
        let restarted = container(blocked)
        await restarted.bootstrap()
        XCTAssertTrue(restarted.isNativeReady)
        XCTAssertEqual(blocked.calls, 0)
        let progress = await restarted.progress.load()
        XCTAssertEqual(progress?.total, 0)
        XCTAssertEqual(progress?.settings.goal, 333)
        XCTAssertTrue(progress?.onboarded == true)
    }

    func testFailedLegacyReadBlocksFreshStateAndCanRetry() async throws {
        let reader = StubLegacyReader(); reader.fails = true
        let app = container(reader)
        await app.bootstrap()
        XCTAssertFalse(app.isNativeReady)
        XCTAssertTrue(app.hasStartupError)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("state.json").path))
        let tap = await app.zikrSink.tap()
        XCTAssertNil(tap)
        reader.fails = false
        await app.bootstrap()
        XCTAssertTrue(app.isNativeReady)
        XCTAssertFalse(app.hasStartupError)
    }

    func testReadOnlyMigrationUsesSameOriginWithoutLoadingAppHTML() async throws {
        let dataStore = WKWebsiteDataStore.nonPersistent()
        let config = WKWebViewConfiguration()
        config.websiteDataStore = dataStore
        config.setURLSchemeHandler(ReadOnlyMigrationPage(), forURLScheme: "zikr")
        config.userContentController.addUserScript(WKUserScript(source:
            "localStorage.setItem('zikr-adventure.v2','{\"total\":77}');localStorage.setItem('zikr-adventure.v1','{\"total\":3}');",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: .zero, configuration: config)
        let delegate = MigrationNavigationProbe()
        view.navigationDelegate = delegate
        view.load(URLRequest(url: URL(string: "zikr://localhost/migration.html")!))
        await fulfillment(of: [delegate.loaded], timeout: 30)
        let sources = try await LegacyStorageReader(dataStore: dataStore).read()
        XCTAssertEqual(sources.localStorageV2, "{\"total\":77}")
        XCTAssertEqual(sources.localStorageV1, "{\"total\":3}")
        let state = try await view.evaluateJavaScript("typeof window.zikrNative") as? String
        XCTAssertEqual(state, "undefined")
    }
}

@MainActor
private final class StubLegacyReader: LegacyStorageReading {
    var sources = LegacySources()
    var calls = 0
    var fails = false
    func read() async throws -> LegacySources {
        calls += 1
        if fails { throw CocoaError(.fileReadNoPermission) }
        return sources
    }
}

@MainActor
private final class MigrationNavigationProbe: NSObject, WKNavigationDelegate {
    let loaded = XCTestExpectation(description: "Read-only migration origin loaded")
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded.fulfill() }
}
