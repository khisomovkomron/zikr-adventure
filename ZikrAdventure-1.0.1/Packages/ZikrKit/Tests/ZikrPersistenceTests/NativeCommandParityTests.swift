import XCTest
import ZikrDomain

/// Fixtures генерируются настоящими функциями index.html, не Swift-реализацией.
/// Timestamp проверяется отдельно: native объединяет web persist в одну транзакцию
/// и не сбрасывает версию при resetProgress (иначе старые данные могут воскреснуть).
final class NativeCommandParityTests: XCTestCase {
    private struct Scenario: Decodable {
        let name: String
        let initial: ProgressState
        let steps: [Step]
    }
    private struct Step: Decodable {
        let command: Command
        let expected: ProgressState
        let fresh: [String]
    }
    private struct Command: Decodable {
        let name: String
        let now: Int64
        let field: String?
        let bool: Bool?
        let int: Int?
        let text: String?
        let camera: CameraPosition?

        func value() throws -> NativeProgressCommand {
            switch name {
            case "tap": return .tap
            case "undo": return .undo
            case "reset": return .reset(try XCTUnwrap(ZikrResetMode(rawValue: text ?? "")))
            case "setSetting":
                if field == "goal" { return .setSetting(.goal(try XCTUnwrap(int))) }
                return .setSetting(.toggle(try XCTUnwrap(SettingsToggle(rawValue: field ?? "")), try XCTUnwrap(bool)))
            case "setLang": return .setLanguage(try XCTUnwrap(AppLanguage(rawValue: text ?? "")))
            case "resetDefaults": return .resetDefaults
            case "clearHistory": return .clearHistory
            case "resetProgress": return .resetProgress
            case "completeOnboarding": return .completeOnboarding
            case "markViewed": return .markViewed(try XCTUnwrap(text))
            case "showChapter": return .openChapter(try XCTUnwrap(text))
            case "explore": return .explore(try XCTUnwrap(text))
            case "selectCity": return .selectCity(text)
            case "saveCamera": return .saveCamera(try XCTUnwrap(text), try XCTUnwrap(camera))
            default: throw NSError(domain: "Unknown parity command", code: 1)
            }
        }
    }

    func testWebGoldenScenariosMatchNativeCommands() throws {
        let scenarios = try JSONDecoder().decode([Scenario].self, from: Fixture.data("native-command-parity.json"))
        let catalog = NativeCommandCatalog(cityIDs: ["mecca", "medina"], chapterCities: ["ch01": "mecca", "ch09": "medina"])
        let utc = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        for scenario in scenarios {
            var state = scenario.initial
            for (index, step) in scenario.steps.enumerated() {
                let date = Date(timeIntervalSince1970: Double(step.command.now) / 1000)
                let result = try XCTUnwrap(NativeProgressReducer.apply(try step.command.value(), to: state,
                                                                      at: date, timeZone: utc, catalog: catalog))
                var comparison = result.progress
                comparison.updatedAt = step.expected.updatedAt
                XCTAssertEqual(comparison, step.expected, "\(scenario.name), step \(index): \(step.command.name)")
                XCTAssertEqual(result.fresh, step.fresh)
                if result.didChange {
                    XCTAssertGreaterThan(result.progress.updatedAt ?? 0, state.updatedAt ?? 0)
                } else {
                    XCTAssertEqual(result.progress.updatedAt, state.updatedAt)
                }
                state = result.progress
            }
        }
    }
}
