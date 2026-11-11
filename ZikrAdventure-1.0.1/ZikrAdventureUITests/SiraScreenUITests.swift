// SiraScreenUITests.swift
// ZKR-53: нативный экран «Путь Сиры». Главы открываются счётом через веб (window.zikrNative.tap),
// просмотр пишет веб (window.zikrNative.markViewed): «Читать» → лист главы, метка «Новое» снимается
// при следующем показе вкладки (как renderPath()), «На карте» переключает на «Карту».

import XCTest

final class SiraScreenUITests: XCTestCase {
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

    func testOpenReadAndMarkViewed() {
        let app = launch()
        let total = app.descendants(matching: .any)["zikr.total"]
        if value(total) != "0" {
            resetAll(app)
            XCTAssertTrue(waitFor(total, value: "0"))
        }

        // При 0 все главы закрыты.
        app.buttons["tab.path"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["sira.screen"].waitForExistence(timeout: 10), "нативный экран «Путь Сиры» не показан")
        XCTAssertTrue(app.staticTexts["sira.title"].exists)
        let ch01 = app.descendants(matching: .any)["sira.chapter.ch01"]
        XCTAssertTrue(ch01.waitForExistence(timeout: 5))
        XCTAssertTrue(waitFor(ch01, value: "locked"))
        XCTAssertFalse(app.buttons["sira.read.ch01"].exists)

        // 10 нажатий → глава 1 открыта, «Новое».
        app.buttons["tab.zikr"].tap()
        let button = app.buttons["zikr.button"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        for _ in 0..<10 { button.tap() }
        XCTAssertTrue(waitFor(total, value: "10"))
        if app.buttons["zikr.banner.close"].exists { app.buttons["zikr.banner.close"].tap() }
        app.buttons["tab.path"].tap()
        XCTAssertTrue(waitFor(ch01, value: "new"), "получено: \(value(ch01))")
        XCTAssertTrue(ch01.label.contains("Новое"))
        XCTAssertTrue(waitFor(app.descendants(matching: .any)["sira.chapter.ch02"], value: "locked"))

        // «Читать» → лист главы (chapterCard) с текстом и «На карте».
        let read = app.buttons["sira.read.ch01"]
        scrollTo(read, in: app)
        read.tap()
        let title = app.staticTexts["sira.sheet.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Долина Мекки")
        XCTAssertTrue(app.staticTexts["sira.sheet.text"].exists)
        XCTAssertTrue(app.buttons["sira.sheet.map"].exists)
        app.buttons["sira.sheet.close"].tap()
        XCTAssertFalse(title.waitForExistence(timeout: 1))
        XCTAssertTrue(waitFor(ch01, value: "new"), "метка остаётся до следующего показа вкладки, как в вебе")

        // Повторный показ вкладки: просмотрено (viewed записал веб).
        Thread.sleep(forTimeInterval: 1)
        app.buttons["tab.info"].tap()
        app.buttons["tab.path"].tap()
        XCTAssertTrue(waitFor(ch01, value: "open"), "получено: \(value(ch01))")
        XCTAssertFalse(ch01.label.contains("Новое"))

        // «На карте» → вкладка «Карта» (openCity в вебе).
        let map = app.buttons["sira.map.ch01"]
        scrollTo(map, in: app)
        map.tap()
        XCTAssertTrue(waitFor(app.buttons["tab.map"], selected: true), "«На карте» должна открыть «Карту»")

        // Просмотр сохраняется после перезапуска.
        Thread.sleep(forTimeInterval: 1.5)
        app.terminate()
        let relaunched = launch()
        relaunched.buttons["tab.path"].tap()
        XCTAssertTrue(waitFor(relaunched.descendants(matching: .any)["sira.chapter.ch01"], value: "open"))

        // Вернуть чистое состояние.
        relaunched.buttons["tab.zikr"].tap()
        resetAll(relaunched)
        XCTAssertTrue(waitFor(relaunched.descendants(matching: .any)["zikr.total"], value: "0"))
    }

    func testPlaceCardChapter() {
        let app = launch()
        let total = app.descendants(matching: .any)["zikr.total"]
        if value(total) != "0" {
            resetAll(app)
            XCTAssertTrue(waitFor(total, value: "0"))
        }
        let button = app.buttons["zikr.button"]
        for _ in 0..<25 { button.tap() }
        XCTAssertTrue(waitFor(total, value: "25"))
        if app.buttons["zikr.banner.close"].exists { app.buttons["zikr.banner.close"].tap() }
        app.buttons["tab.path"].tap()
        let read = app.buttons["sira.read.ch02"]
        XCTAssertTrue(read.waitForExistence(timeout: 5))
        scrollTo(read, in: app)
        read.tap()
        // placeCard(zamzam, { siraFirst }): название места, арабское название, Сира, расстояние.
        XCTAssertTrue(waitFor(app.staticTexts["sira.sheet.title"], label: "Колодец Замзам"))
        XCTAssertEqual(app.staticTexts["sira.sheet.arabic"].label, "بئر زمزم")
        XCTAssertTrue(app.staticTexts["sira.sheet.sira"].exists)
        XCTAssertEqual(app.staticTexts["sira.sheet.distance"].label, "От Каабы: ~20 м, юго-восток")
        app.buttons["sira.sheet.close"].tap()
        app.buttons["tab.zikr"].tap()
        resetAll(app)
        XCTAssertTrue(waitFor(total, value: "0"))
    }

    func testUzbekLabels() {
        let app = launch(language: "uz")
        app.buttons["tab.path"].tap()
        XCTAssertTrue(waitFor(app.staticTexts["sira.title"], label: "Siyrat yo‘li"))
        XCTAssertTrue(waitFor(app.buttons["tab.path"], label: "Siyrat yo‘li"))
        app.buttons["tab.settings"].tap()
        app.buttons["settings.lang.ru"].tap()
    }

    /// Скриншоты для QA (тема — как у симулятора). ZIKR_SHOT_WEB=1 — сборка с isNativeSiraEnabled = false
    /// (веб-экран для сравнения), ZIKR_SHOT_CHAPTERS=ch01,ch02 — листы «Читать» этих глав.
    func testScreenshots() {
        let env = ProcessInfo.processInfo.environment
        let isWeb = env["ZIKR_SHOT_WEB"] == "1"
        let app = launch(language: env["ZIKR_SHOT_LANG"] ?? "ru")
        app.buttons["tab.path"].tap()
        if isWeb {
            Thread.sleep(forTimeInterval: 3)
        } else {
            XCTAssertTrue(app.descendants(matching: .any)["sira.screen"].waitForExistence(timeout: 10))
            Thread.sleep(forTimeInterval: 1)
        }
        attach(app, name: "sira-top")
        // Протяжка без инерции — одинаковый сдвиг у веб- и нативного экрана.
        drag(app, by: 400, web: isWeb)
        attach(app, name: "sira-mid")
        drag(app, by: -400, web: isWeb)
        let readTitle = env["ZIKR_SHOT_READ"] ?? "Читать"
        let closeTitle = env["ZIKR_SHOT_CLOSE"] ?? "Закрыть"
        for id in (env["ZIKR_SHOT_CHAPTERS"] ?? "").split(separator: ",").map(String.init) {
            let read = isWeb ? webButton(app, title: readTitle, chapter: id) : app.buttons["sira.read.\(id)"]
            var attempts = 0
            while attempts < 6, !(read.exists && read.isHittable && read.frame.maxY < app.frame.maxY - 110) {
                drag(app, by: 150, web: isWeb)
                attempts += 1
            }
            guard read.exists else { continue }
            read.tap()
            Thread.sleep(forTimeInterval: 1.5)
            attach(app, name: "sira-sheet-\(id)")
            let close = isWeb ? app.webViews.buttons[closeTitle].firstMatch : app.buttons["sira.sheet.close"]
            if close.exists { close.tap() }
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    /// Кнопка «Читать» главы в веб-экране: N-я по порядку среди открытых (data-read).
    private func webButton(_ app: XCUIApplication, title: String, chapter id: String) -> XCUIElement {
        let index = (Int(id.dropFirst(2)) ?? 1) - 1
        return app.webViews.buttons.matching(NSPredicate(format: "label == %@", title)).element(boundBy: index)
    }

    private func drag(_ app: XCUIApplication, by distance: CGFloat, web: Bool) {
        let target = web ? app.webViews.firstMatch : app.scrollViews.firstMatch
        let start = target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: 0, dy: distance / 2))
        let end = start.withOffset(CGVector(dx: 0, dy: -distance))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.6)
        Thread.sleep(forTimeInterval: 0.6)
    }

    // MARK: - Помощники

    private func resetAll(_ app: XCUIApplication) {
        app.scrollViews.firstMatch.swipeDown()
        app.buttons["zikr.reset"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Счётчик и главы — начать путь заново"].tap()
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        var attempts = 0
        while attempts < 12, !(element.exists && element.isHittable && element.frame.maxY < app.frame.maxY - 120) {
            app.scrollViews.firstMatch.swipeUp(velocity: .slow)
            attempts += 1
        }
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

    private func waitFor(_ element: XCUIElement, selected: Bool, timeout: TimeInterval = 8) -> Bool {
        let predicate = NSPredicate(format: "isSelected == %@", NSNumber(value: selected))
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: timeout) == .completed
    }
}
