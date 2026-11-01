import XCTest
import ZikrCore
import ZikrDomain
@testable import ZikrPersistence

final class RepositoriesTests: TempDirTestCase {
    // 8.1
    func testRepositoriesReadAndUpdateThroughStore() async throws {
        let store = makeStore()
        let progress = JSONProgressRepository(store: store)
        let settings = JSONSettingsRepository(store: store)
        let initialProgress = await progress.load()
        let initialSettings = await settings.load()
        XCTAssertNil(initialProgress)
        XCTAssertNil(initialSettings)

        _ = await store.replaceFromWeb(json: stateJSON(total: 10))
        let loaded = await progress.load()
        XCTAssertEqual(loaded?.total, 10)
        let loadedSettings = await settings.load()
        XCTAssertEqual(loadedSettings?.lang, .en)

        let updated = try await progress.update { $0.total += 5 }
        XCTAssertEqual(updated.total, 15)
        let newSettings = try await settings.update { $0.goal = 300 }
        XCTAssertEqual(newSettings.goal, 300)
        let doc = try readDocument()
        XCTAssertEqual(doc.progress.total, 15)
        XCTAssertEqual(doc.progress.settings.goal, 300)
    }

    // ZKR-50: changes() настроек — после записи, без повторов при неизменных настройках.
    func testSettingsChangesYieldOnlyWhenSettingsChange() async throws {
        let store = makeStore()
        let settings = JSONSettingsRepository(store: store)
        _ = await store.replaceFromWeb(json: stateJSON(total: 1))
        let stream = await settings.changes()
        var iterator = stream.makeAsyncIterator()

        _ = await store.replaceFromWeb(json: stateJSON(total: 2, extra: ",\"updatedAt\":2"))
        let first = await iterator.next()
        XCTAssertEqual(first?.lang, .en)

        // Счёт изменился, настройки — нет: событие пропускается; следующее — уже с новой целью.
        _ = await store.replaceFromWeb(json: stateJSON(total: 3, extra: ",\"updatedAt\":3"))
        _ = await store.replaceFromWeb(json:
            "{\"v\":2,\"total\":3,\"daily\":{},\"unlocked\":[],\"viewed\":[],\"settings\":{\"lang\":\"en\",\"goal\":250},\"onboarded\":true,\"updatedAt\":4}")
        let second = await iterator.next()
        XCTAssertEqual(second?.goal, 250)
    }
}
