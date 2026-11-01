// SettingsScreenUITests.swift
// ZKR-50: нативный экран «Настройки». Элементы ищутся по accessibilityIdentifier, тексты сверяются
// с index.html (ru/uz). ZIKR_UITEST_AUTH подменяет Firebase в DEBUG-сборке (AppContainer).

import XCTest

final class SettingsScreenUITests: XCTestCase {
    private static let skipTitles = ["Пропустить", "Skip", "O‘tkazib yuborish", "Гузаштан", "Өткізу", "Өткөрүү"]
    private static let languages = ["ru", "en", "uz", "tg", "kk", "ky"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(auth: String = "guest") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ZIKR_UITEST_AUTH"] = auth
        app.launch()
        skipOnboardingIfShown(app)
        let tab = app.buttons["tab.settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        XCTAssertTrue(app.buttons["settings.lang.ru"].waitForExistence(timeout: 10), "нативный экран не показан")
        return app
    }

    func testToggleSurvivesTabSwitch() {
        let app = launch()
        let toggle = app.switches["settings.toggle.animations"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let before = toggle.value as? String
        toggle.tap()
        XCTAssertTrue(waitFor(toggle, valueNot: before))
        let after = toggle.value as? String

        app.buttons["tab.zikr"].tap()
        XCTAssertTrue(waitForDisappearance(toggle))
        app.buttons["tab.settings"].tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, after, "значение пришло из веба (zikr-state.json)")

        toggle.tap() // вернуть как было
        XCTAssertTrue(waitFor(toggle, valueNot: after))
    }

    func testLanguageSwitchRelabelsTabBar() {
        let app = launch()
        app.buttons["settings.lang.uz"].tap()
        XCTAssertTrue(waitFor(app.buttons["tab.settings"], label: "Sozlamalar"))
        app.buttons["settings.lang.ru"].tap()
        XCTAssertTrue(waitFor(app.buttons["tab.settings"], label: "Настройки"))
    }

    func testGoalStepper() {
        let app = launch()
        app.buttons["settings.lang.ru"].tap()
        let value = app.staticTexts["settings.goal.value"]
        if !value.exists {
            let goalToggle = app.switches["settings.toggle.goalOn"]
            scrollTo(goalToggle, in: app)
            goalToggle.tap()
        }
        scrollTo(value, in: app)
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        let start = goal(from: value.label)
        let plus = app.buttons["settings.goal.plus"]
        let minus = app.buttons["settings.goal.minus"]
        if start > 9_980 {
            minus.tap(); minus.tap()
        }
        let base = goal(from: value.label)
        plus.tap()
        plus.tap()
        let expected = base + 20
        XCTAssertTrue(waitFor(value, label: "Цель: \(Self.ruNumber(expected))"), "получено: \(value.label)")
        minus.tap()
        minus.tap()
        XCTAssertTrue(waitFor(value, label: "Цель: \(Self.ruNumber(base))"))
    }

    func testDeleteAccountShowsReauthHint() {
        let app = launch(auth: "signedIn")
        app.buttons["settings.lang.ru"].tap()
        let delete = app.buttons["auth.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Удалить аккаунт"].tap()
        // Один запрос «id + текст»: под нагрузкой отдельное чтение label может не успеть до отмены.
        let status = app.staticTexts.matching(NSPredicate(
            format: "identifier == %@ AND label == %@",
            "auth.status", "Чтобы удалить аккаунт, подтвердите вход ещё раз."
        )).firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        // UITestAuthService «отменяет» вход через 8 с — тихий возврат без ошибки.
        XCTAssertTrue(delete.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["auth.deletionError"].exists)
    }

    /// Скриншоты для QA: все 6 языков, верх и низ экрана (тема — как у симулятора).
    func testScreenshotsAllLanguages() {
        let app = launch(auth: ProcessInfo.processInfo.environment["ZIKR_SHOT_AUTH"] ?? "guest")
        for language in Self.languages {
            let chip = app.buttons["settings.lang.\(language)"]
            scrollTo(chip, in: app)
            chip.tap()
            Thread.sleep(forTimeInterval: 1)
            app.scrollViews.firstMatch.swipeDown()
            app.scrollViews.firstMatch.swipeDown()
            attach(app, name: "settings-\(language)-top")
            app.scrollViews.firstMatch.swipeUp()
            app.scrollViews.firstMatch.swipeUp()
            app.scrollViews.firstMatch.swipeUp()
            attach(app, name: "settings-\(language)-bottom")
        }
        let ru = app.buttons["settings.lang.ru"]
        scrollTo(ru, in: app)
        ru.tap()
    }

    // MARK: - Помощники

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func goal(from label: String) -> Int {
        Int(label.filter(\.isNumber)) ?? 0
    }

    private static func ruNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ru-RU")
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        let scroll = app.scrollViews.firstMatch
        var attempts = 0
        while !(element.exists && element.isHittable) && attempts < 6 {
            scroll.swipeUp()
            attempts += 1
        }
        attempts = 0
        while !(element.exists && element.isHittable) && attempts < 8 {
            scroll.swipeDown()
            attempts += 1
        }
    }

    private func skipOnboardingIfShown(_ app: XCUIApplication) {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            for title in Self.skipTitles {
                let button = app.webViews.buttons[title]
                if button.exists {
                    button.tap()
                    return
                }
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    private func waitFor(_ element: XCUIElement, label: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
    }

    private func waitFor(_ element: XCUIElement, valueNot value: String?, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if (element.value as? String) != value { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
