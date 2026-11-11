// ZikrScreenUITests.swift
// ZKR-52: нативный экран «Зикр». Счёт идёт через веб (window.zikrNative), значения сверяются
// с index.html: 33 нажатия → всего/сегодня/за сеанс +33, «Исправить», оба варианта «Обнулить», история.

import XCTest

final class ZikrScreenUITests: XCTestCase {
    private static let skipTitles = ["Пропустить", "Skip", "O‘tkazib yuborish", "Гузаштан", "Өткізу", "Өткөрүү"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(language: String = "ru") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ZIKR_UITEST_AUTH"] = "guest"
        app.launch()
        skipOnboardingIfShown(app)
        let settingsTab = app.buttons["tab.settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10))
        settingsTab.tap()
        let chip = app.buttons["settings.lang.\(language)"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        chip.tap()
        app.buttons["tab.zikr"].tap()
        XCTAssertTrue(app.buttons["zikr.button"].waitForExistence(timeout: 10), "нативный экран «Зикр» не показан")
        return app
    }

    func testCountUndoResetAndHistory() {
        let app = launch()
        let total = app.descendants(matching: .any)["zikr.total"]
        let today = app.descendants(matching: .any)["zikr.today"]
        let session = app.descendants(matching: .any)["zikr.session"]
        let opened = app.staticTexts["zikr.opened"]
        let button = app.buttons["zikr.button"]

        // Чистый старт: «Счётчик и главы».
        if value(total) != "0" {
            resetAll(app)
            XCTAssertTrue(waitFor(total, value: "0"))
        }
        XCTAssertTrue(waitFor(opened, label: "Открыто глав: 0 из 19"))
        XCTAssertFalse(app.buttons["zikr.undo"].isEnabled, "при 0 «Исправить» неактивна")
        XCTAssertFalse(app.buttons["zikr.reset"].isEnabled)
        let todayStart = Int(value(today).filter(\.isNumber)) ?? 0
        let sessionStart = Int(value(session).filter(\.isNumber)) ?? 0

        for _ in 0..<33 { button.tap() }
        XCTAssertTrue(waitFor(total, value: "33"), "получено: \(value(total))")
        XCTAssertTrue(waitFor(today, value: Self.ruNumber(todayStart + 33)))
        XCTAssertTrue(waitFor(session, value: Self.ruNumber(sessionStart + 33)))
        XCTAssertTrue(waitFor(opened, label: "Открыто глав: 2 из 19"), "главы на 10 и 25")

        app.buttons["zikr.undo"].tap()
        XCTAssertTrue(waitFor(total, value: "32"))
        XCTAssertTrue(waitFor(today, value: Self.ruNumber(todayStart + 32)))

        // «Только счётчик — главы остаются».
        app.buttons["zikr.reset"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["Обнулить счётчик?"].exists)
        alert.buttons["Только счётчик — главы остаются"].tap()
        XCTAssertTrue(waitFor(total, value: "0"))
        XCTAssertTrue(waitFor(session, value: "0"))
        XCTAssertTrue(waitFor(opened, label: "Открыто глав: 2 из 19"))
        XCTAssertTrue(waitFor(today, value: Self.ruNumber(todayStart + 32)), "история дня не сбрасывается")

        // История: сегодняшний день есть.
        app.buttons["zikr.history"].tap()
        XCTAssertTrue(app.staticTexts["zikr.history.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["zikr.history.day.\(Self.todayKey())"].waitForExistence(timeout: 5))
        app.buttons["zikr.history.close"].tap()

        // Снова 1 нажатие и «Счётчик и главы».
        button.tap()
        XCTAssertTrue(waitFor(total, value: "1"))
        resetAll(app)
        XCTAssertTrue(waitFor(total, value: "0"))
        XCTAssertTrue(waitFor(opened, label: "Открыто глав: 0 из 19"))
    }

    func testSurvivesRelaunch() {
        var app = launch()
        let button = app.buttons["zikr.button"]
        let total = app.descendants(matching: .any)["zikr.total"]
        let before = Int(value(total).filter(\.isNumber)) ?? 0
        for _ in 0..<5 { button.tap() }
        XCTAssertTrue(waitFor(total, value: Self.ruNumber(before + 5)))
        // Дать вебу сохранить (persist → progress.json / zikr-state.json).
        Thread.sleep(forTimeInterval: 1.5)
        app.terminate()
        app = launch()
        let relaunched = app.descendants(matching: .any)["zikr.total"]
        XCTAssertTrue(waitFor(relaunched, value: Self.ruNumber(before + 5)), "получено: \(value(relaunched))")
        XCTAssertTrue(waitFor(app.descendants(matching: .any)["zikr.session"], value: "0"), "сеанс начинается с 0")
    }

    func testUzbekLabels() {
        let app = launch(language: "uz")
        // VoiceOver-подписи — a11y.correct / a11y.button из UI.uz.
        XCTAssertTrue(waitFor(app.buttons["zikr.undo"], label: "Oxirgi bosishni tuzatish"))
        XCTAssertTrue(waitFor(app.buttons["zikr.button"], label: "Zikr tugmasi. Hisobni bittaga oshirish"))
        XCTAssertTrue(waitFor(app.buttons["tab.zikr"], label: "Zikr"))
        // Вернуть русский.
        app.buttons["tab.settings"].tap()
        app.buttons["settings.lang.ru"].tap()
    }

    /// Скриншоты для QA (тема — как у симулятора).
    func testScreenshots() {
        let app = launch(language: ProcessInfo.processInfo.environment["ZIKR_SHOT_LANG"] ?? "ru")
        Thread.sleep(forTimeInterval: 1)
        attach(app, name: "zikr-top")
        app.scrollViews.firstMatch.swipeUp()
        app.scrollViews.firstMatch.swipeUp()
        attach(app, name: "zikr-bottom")
    }

    // MARK: - Помощники

    private func resetAll(_ app: XCUIApplication) {
        app.scrollViews.firstMatch.swipeDown()
        app.buttons["zikr.reset"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Счётчик и главы — начать путь заново"].tap()
    }

    private func value(_ element: XCUIElement) -> String {
        (element.value as? String) ?? ""
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func ruNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ru-RU")
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
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
            if app.buttons["zikr.button"].exists { return }
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    private func waitFor(_ element: XCUIElement, label: String, timeout: TimeInterval = 8) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
    }

    private func waitFor(_ element: XCUIElement, value: String, timeout: TimeInterval = 8) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
    }
}
