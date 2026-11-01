// SettingsCommandsTests.swift
// ZKR-50: правила цели и применение команд совпадают с index.html.

import XCTest
@testable import ZikrDomain

final class SettingsCommandsTests: XCTestCase {
    func testGoalClampMatchesWebSanitize() {
        // Math.min(10000, Math.max(10, Math.round(goal / 10) * 10 || 100))
        XCTAssertEqual(GoalRules.clamp(100), 100)
        XCTAssertEqual(GoalRules.clamp(104), 100)
        XCTAssertEqual(GoalRules.clamp(105), 110)
        XCTAssertEqual(GoalRules.clamp(4), 100) // round → 0 → || 100
        XCTAssertEqual(GoalRules.clamp(6), 10)
        XCTAssertEqual(GoalRules.clamp(-50), 10)
        XCTAssertEqual(GoalRules.clamp(-5), 100) // Math.round(-0.5) = -0 → || 100
        XCTAssertEqual(GoalRules.clamp(20_000), 10_000)
    }

    func testGoalStepperBounds() {
        XCTAssertEqual(GoalRules.stepped(100, by: 10), 110)
        XCTAssertEqual(GoalRules.stepped(10, by: -10), 10)
        XCTAssertEqual(GoalRules.stepped(10_000, by: 10), 10_000)
    }

    func testFieldAppliesToSettings() {
        var settings = AppSettings()
        SettingsField.toggle(.sound, true).apply(to: &settings)
        SettingsField.toggle(.animations, false).apply(to: &settings)
        SettingsField.goal(123).apply(to: &settings)
        XCTAssertTrue(settings.sound)
        XCTAssertFalse(settings.animations)
        XCTAssertEqual(settings.goal, 120)
        XCTAssertEqual(SettingsField.goal(1).key, "goal")
        XCTAssertEqual(SettingsField.toggle(.keepAwake, true).key, "keepAwake")
    }

    func testToggleSubscriptCoversAllKeys() {
        var settings = AppSettings()
        for toggle in SettingsToggle.allCases {
            let before = settings[toggle]
            settings[toggle] = !before
            XCTAssertEqual(settings[toggle], !before, toggle.rawValue)
        }
        XCTAssertFalse(SettingsToggle.allCases.map(\.rawValue).contains("preview"))
    }
}
