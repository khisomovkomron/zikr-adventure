import Foundation
import XCTest
import ZikrCore
import ZikrDomain
@testable import ZikrPersistence

enum Fixture {
    static func url(_ name: String) throws -> URL {
        let parts = name.split(separator: ".", maxSplits: 1).map(String.init)
        return try XCTUnwrap(Bundle.module.url(forResource: parts[0], withExtension: parts.count > 1 ? parts[1] : nil,
                                               subdirectory: "Fixtures"), "fixture \(name)")
    }

    static func data(_ name: String) throws -> Data { try Data(contentsOf: url(name)) }
    static func text(_ name: String) throws -> String { try XCTUnwrap(String(data: data(name), encoding: .utf8)) }
}

let testLanguages = ["ru-RU"]
let fixedDate = Date(timeIntervalSince1970: 1_792_740_000)

func sanitize(_ json: String) -> ProgressState {
    LegacySanitizer.sanitize(JSONValue.parse(json), preferredLanguages: testLanguages)
}

/// Временный каталог FileManager.default.temporaryDirectory/UUID, удаляется в tearDown.
class TempDirTestCase: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let dir { try? FileManager.default.removeItem(at: dir) }
        dir = nil
    }

    var stateURL: URL { dir.appendingPathComponent("zikr-state.json") }
    var progressURL: URL { dir.appendingPathComponent("progress.json") }

    func makeStore(clock: Date = fixedDate) -> JSONStateStore {
        JSONStateStore(fileURL: stateURL, clock: FixedClock(clock), appVersion: "1.2.0-test", preferredLanguages: testLanguages)
    }

    func readDocument() throws -> StateDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(StateDocument.self, from: Data(contentsOf: stateURL))
    }

    func stateJSON(total: Int, extra: String = "") -> String {
        "{\"v\":2,\"total\":\(total),\"daily\":{},\"unlocked\":[],\"viewed\":[],\"settings\":{\"lang\":\"en\"},\"onboarded\":true\(extra)}"
    }
}
