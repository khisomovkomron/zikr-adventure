// SettingsCommandsTests.swift
// ZKR-50: правила цели и применение команд совпадают с index.html.

import XCTest
@testable import ZikrDomain

final class SettingsCommandsTests: XCTestCase {
    func testGoalClampKeepsValueWithinBoundsWithoutRounding() {
        // index.html: Math.min(10000, Math.max(10, goal)) — без округления до шага 10.
        XCTAssertEqual(GoalRules.clamp(100), 100)
        XCTAssertEqual(GoalRules.clamp(104), 104)
        XCTAssertEqual(GoalRules.clamp(125), 125)
        XCTAssertEqual(GoalRules.clamp(4), 10)
        XCTAssertEqual(GoalRules.clamp(-50), 10)
        XCTAssertEqual(GoalRules.clamp(20_000), 10_000)
    }

    func testGoalStepperKeepsNonRoundValues() {
        XCTAssertEqual(GoalRules.stepped(125, by: 10), 135)
        XCTAssertEqual(GoalRules.stepped(15, by: -10), 10)
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
        XCTAssertEqual(settings.goal, 123) // без округления до шага 10
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
