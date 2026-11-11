// MapScreenUITests.swift
// ZKR-57: нативный экран «Карта». Главы открываются счётом через веб (window.zikrNative.tap); выбор города
// и камеру пишет веб (window.zikrNative.selectCity / saveCamera). Обзор → панель города → карта города →
// список мест → карточка места (блок Сиры: открыт / «откроется на N») → назад; «На карте» из «Пути Сиры».

import XCTest

final class MapScreenUITests: XCTestCase {
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

    /// Счёт с нуля до count (главы открываются в вебе).
    private func count(to target: Int, in app: XCUIApplication) {
        let total = app.descendants(matching: .any)["zikr.total"]
        if value(total) != "0" {
            resetAll(app)
            XCTAssertTrue(waitFor(total, value: "0"))
        }
        let button = app.buttons["zikr.button"]
        for _ in 0..<target { button.tap() }
        XCTAssertTrue(waitFor(total, value: "\(target)"))
        if app.buttons["zikr.banner.close"].exists { app.buttons["zikr.banner.close"].tap() }
    }

    func testWorldCityListAndPlaceCards() {
        let app = launch()
        count(to: 25, in: app)

        app.buttons["tab.map"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["map.screen"].waitForExistence(timeout: 10), "нативный экран «Карта» не показан")
        if app.buttons["map.city.back"].exists { app.buttons["map.city.back"].tap() }
        if app.buttons["map.panel.close"].exists { app.buttons["map.panel.close"].tap() }
        XCTAssertTrue(waitFor(app.staticTexts["map.world.title"], label: "Карта"))
        XCTAssertTrue(app.staticTexts["map.disclaimer"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["map.world.progress"].label.contains("Глав: 2 из"))

        // Кнопка «Мекка» → панель города (2 открытые главы Мекки).
        app.buttons["map.world.pick.mecca"].tap()
        XCTAssertTrue(waitFor(app.staticTexts["map.panel.title"], label: "Мекка"))
        XCTAssertTrue(app.staticTexts["map.panel.chapters"].label.hasPrefix("Главы Сиры в городе: 2 из "))
        app.buttons["map.panel.open"].tap()

        // Карта города.
        XCTAssertTrue(waitFor(app.staticTexts["map.city.title"], label: "Мекка"))
        XCTAssertTrue(app.descendants(matching: .any)["map.city.canvas"].waitForExistence(timeout: 10))
        for id in ["map.city.zoomIn", "map.city.zoomOut", "map.city.reset", "map.city.list", "map.city.help"] {
            XCTAssertTrue(app.buttons[id].exists, id)
        }
        app.buttons["map.city.zoomIn"].tap()
        app.buttons["map.city.reset"].tap()

        // Список мест → Замзам (глава 2 открыта): карточка места, блок Сиры после «Облика».
        app.buttons["map.city.list"].tap()
        let zamzam = app.buttons["map.list.row.zamzam"]
        XCTAssertTrue(zamzam.waitForExistence(timeout: 5))
        XCTAssertTrue(zamzam.label.contains("Глава 2 · Глава открыта"), zamzam.label)
        XCTAssertFalse(app.buttons["map.list.row.marwa"].exists, "Марва (sub 1) не в списке")
        zamzam.tap()
        XCTAssertTrue(waitFor(app.staticTexts["sira.sheet.title"], label: "Колодец Замзам"))
        XCTAssertTrue(app.staticTexts["sira.sheet.sira"].exists)
        XCTAssertFalse(app.buttons["sira.sheet.map"].exists, "на карте нет «На карте»")
        app.buttons["sira.sheet.close"].tap()
        XCTAssertFalse(app.staticTexts["sira.sheet.title"].waitForExistence(timeout: 1))

        // Кааба (глава 16 закрыта): «Этот рассказ Сиры откроется на …».
        app.buttons["map.city.list"].tap()
        let kaaba = app.buttons["map.list.row.kaaba"]
        XCTAssertTrue(kaaba.waitForExistence(timeout: 5))
        kaaba.tap()
        XCTAssertTrue(waitFor(app.staticTexts["sira.sheet.title"], label: "Кааба"))
        let locked = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Этот рассказ Сиры откроется на")).firstMatch
        XCTAssertTrue(locked.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["sira.sheet.sira"].exists)
        app.buttons["sira.sheet.close"].tap()

        // Легенда.
        app.buttons["map.city.help"].tap()
        XCTAssertTrue(waitFor(app.staticTexts["map.sheet.title"], label: "Легенда"))
        app.buttons["map.sheet.close"].tap()

        // Назад → обзор с панелью Мекки; крестик → кнопки городов.
        app.buttons["map.city.back"].tap()
        XCTAssertTrue(waitFor(app.staticTexts["map.world.title"], label: "Карта"))
        XCTAssertTrue(app.staticTexts["map.panel.title"].waitForExistence(timeout: 3))
        app.buttons["map.panel.close"].tap()
        XCTAssertTrue(app.buttons["map.world.pick.medina"].waitForExistence(timeout: 3))

        // Выбор города сохраняется (state.city пишет веб): Медина после перезапуска.
        app.buttons["map.world.pick.medina"].tap()
        XCTAssertTrue(waitFor(app.staticTexts["map.panel.title"], label: "Медина"))
        Thread.sleep(forTimeInterval: 1.5)
        app.terminate()
        let relaunched = launch()
        relaunched.buttons["tab.map"].tap()
        XCTAssertTrue(waitFor(relaunched.staticTexts["map.panel.title"], label: "Медина"))
        relaunched.buttons["map.panel.close"].tap()

        relaunched.buttons["tab.zikr"].tap()
        resetAll(relaunched)
        XCTAssertTrue(waitFor(relaunched.descendants(matching: .any)["zikr.total"], value: "0"))
    }

    func testSiraShowOnMapOpensNativeCity() {
        let app = launch()
        count(to: 10, in: app)
        app.buttons["tab.path"].tap()
        let map = app.buttons["sira.map.ch01"]
        XCTAssertTrue(map.waitForExistence(timeout: 5))
        scrollTo(map, in: app)
        map.tap()
        XCTAssertTrue(waitFor(app.buttons["tab.map"], selected: true))
        XCTAssertTrue(waitFor(app.staticTexts["map.city.title"], label: "Мекка"), "«На карте» открывает карту Мекки")
        XCTAssertTrue(app.descendants(matching: .any)["map.city.canvas"].waitForExistence(timeout: 10))
        // Back в шапке обзора → «Зикр».
        app.buttons["map.city.back"].tap()
        if app.buttons["map.panel.close"].waitForExistence(timeout: 3) { app.buttons["map.panel.close"].tap() }
        app.buttons["map.world.back"].tap()
        XCTAssertTrue(waitFor(app.buttons["tab.zikr"], selected: true))
        resetAll(app)
        XCTAssertTrue(waitFor(app.descendants(matching: .any)["zikr.total"], value: "0"))
    }

    /// Скриншоты для QA (тема — как у симулятора). ZIKR_SHOT_WEB=1 — сборка с isNativeMapEnabled = false
    /// (веб-экран для сравнения). ZIKR_SHOT_COUNT — счёт перед снимками (главы и слои карты).
    func testScreenshots() {
        let env = ProcessInfo.processInfo.environment
        let isWeb = env["ZIKR_SHOT_WEB"] == "1"
        let app = launch(language: env["ZIKR_SHOT_LANG"] ?? "ru")
        if let target = env["ZIKR_SHOT_COUNT"].flatMap(Int.init) {
            count(to: target, in: app)
        }
        app.buttons["tab.map"].tap()
        Thread.sleep(forTimeInterval: isWeb ? 3 : 1.5)
        // Обзор без выбранного города.
        tap(app, native: "map.panel.close", web: "Закрыть", isWeb: isWeb, optional: true)
        Thread.sleep(forTimeInterval: 1)
        attach(app, name: "map-world")
        tap(app, native: "map.world.pick.mecca", web: "Мекка", isWeb: isWeb)
        Thread.sleep(forTimeInterval: 1.2)
        attach(app, name: "map-panel")
        for city in ["mecca", "medina"] {
            if city == "medina" {
                // После «Назад» открыта панель Мекки — закрыть, затем выбрать Медину.
                tap(app, native: "map.panel.close", web: "Закрыть", isWeb: isWeb, optional: true)
                Thread.sleep(forTimeInterval: 0.8)
                tap(app, native: "map.world.pick.medina", web: "Медина", isWeb: isWeb)
                Thread.sleep(forTimeInterval: 1)
            }
            tap(app, native: "map.panel.open", web: "Открыть карту города", isWeb: isWeb)
            Thread.sleep(forTimeInterval: 2.5)
            tap(app, native: "map.city.reset", web: "К центру", isWeb: isWeb)
            Thread.sleep(forTimeInterval: 1.5)
            attach(app, name: "map-\(city)")
            tap(app, native: "map.city.list", web: "Список мест", isWeb: isWeb)
            Thread.sleep(forTimeInterval: 1)
            attach(app, name: "map-\(city)-list")
            // Мечеть Куба (ch09) открыта только с 5000 — при меньшем счёте лист места Медины пропускается.
            let place = city == "mecca" ? "Колодец Замзам" : "Мечеть Куба"
            let row = isWeb
                ? app.webViews.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", place)).firstMatch
                : app.buttons["map.list.row.\(city == "mecca" ? "zamzam" : "quba")"]
            if row.waitForExistence(timeout: 2) {
                row.tap()
                Thread.sleep(forTimeInterval: 1.8)
                attach(app, name: "map-\(city)-place")
                tap(app, native: "sira.sheet.close", web: "Закрыть", isWeb: isWeb)
            } else {
                tap(app, native: "map.sheet.close", web: "Закрыть", isWeb: isWeb)
            }
            Thread.sleep(forTimeInterval: 0.6)
            tap(app, native: "map.city.back", web: "Назад", isWeb: isWeb)
            Thread.sleep(forTimeInterval: 1)
        }
        tap(app, native: "map.world.help", web: "Легенда", isWeb: isWeb)
        Thread.sleep(forTimeInterval: 1)
        attach(app, name: "map-legend")
        tap(app, native: "map.sheet.close", web: "Закрыть", isWeb: isWeb)
    }

    private func tap(_ app: XCUIApplication, native id: String, web title: String, isWeb: Bool, optional: Bool = false) {
        let element = isWeb ? app.webViews.buttons[title].firstMatch : app.buttons[id]
        if optional, !element.exists { return }
        XCTAssertTrue(element.waitForExistence(timeout: 5), isWeb ? title : id)
        element.tap()
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
