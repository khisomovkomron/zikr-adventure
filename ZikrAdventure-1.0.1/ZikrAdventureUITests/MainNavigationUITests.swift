import XCTest

extension XCUIApplication {
    /// Реальный маршрут 1.3.0 вместо удалённых вкладок сервисов.
    func openService(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let services = buttons["tab.services"]
        XCTAssertTrue(services.waitForExistence(timeout: 10), file: file, line: line)
        services.tap()
        let destination = buttons["service.\(name)"]
        XCTAssertTrue(destination.waitForExistence(timeout: 10), file: file, line: line)
        for _ in 0..<5 where !destination.isHittable { swipeUp() }
        destination.tap()
    }

    func openAppInfo(file: StaticString = #filePath, line: UInt = #line) {
        buttons["tab.settings"].tap()
        let info = buttons["settings.info"]
        XCTAssertTrue(info.waitForExistence(timeout: 10), file: file, line: line)
        for _ in 0..<12 where !info.isHittable { swipeUp() }
        info.tap()
    }
}

final class MainNavigationUITests: XCTestCase {
    func testCalendarRouteAndLocalDatesAreAvailableWithoutLocation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["ZIKR_UITEST_AUTH"] = "guest"
        app.launchEnvironment["ZIKR_UITEST_ONBOARDING"] = "completed"
        app.launch()
        app.openService("calendar")
        XCTAssertTrue(app.descendants(matching: .any)["calendar.screen"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        app.buttons["calendar.local"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["calendar.localDates"].waitForExistence(timeout: 10))
    }

    func testQiblaRequiresPhoneLocationAndKeepsNorthDial() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["ZIKR_UITEST_AUTH"] = "guest"
        app.launchEnvironment["ZIKR_UITEST_ONBOARDING"] = "completed"
        app.launch()
        app.openService("qibla")
        XCTAssertTrue(app.descendants(matching: .any)["qibla.screen"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["qibla.dial"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertFalse(app.buttons["qibla.city.dushanbe"].exists)
        XCTAssertFalse(app.textFields["qibla.latitude"].exists)
        XCTAssertFalse(app.buttons["qibla.forget"].exists)
    }

    func testHomeCounterReturnAndImplementedServicesOnly() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["ZIKR_UITEST_AUTH"] = "guest"
        app.launchEnvironment["ZIKR_UITEST_ONBOARDING"] = "completed"
        app.launch()
        XCTAssertTrue(app.buttons["home.open.zikr"].waitForExistence(timeout: 30))
        app.buttons["home.open.zikr"].tap()
        let total = app.descendants(matching: .any)["zikr.total"]
        XCTAssertTrue(total.waitForExistence(timeout: 10))
        let before = Int(((total.value as? String) ?? total.label).filter(\.isNumber)) ?? 0
        app.buttons["zikr.button"].tap()
        // Возврат из полного экрана, а не перезапуск: главная читает ту же модель.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let homeTotal = app.staticTexts["home.total"]
        XCTAssertTrue(homeTotal.waitForExistence(timeout: 10))
        let updated = NSPredicate { _, _ in
            Int(homeTotal.label.filter(\.isNumber)) == before + 1
        }
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: updated, object: homeTotal)], timeout: 10), .completed)
        app.buttons["tab.services"].tap()
        for id in ["zikr", "path", "map", "qibla", "calendar"] { XCTAssertTrue(app.buttons["service.\(id)"].exists) }
        for id in ["prayer", "names", "hijri", "quran", "words", "ramadan", "reminders", "activity"] {
            XCTAssertFalse(app.buttons["service.\(id)"].exists)
        }
        XCTAssertFalse(app.buttons["tab.zikr"].exists)
        XCTAssertFalse(app.buttons["tab.info"].exists)
        app.buttons["service.zikr"].tap()
        // Повторный тап активной вкладки должен закрыть вложенный экран.
        app.buttons["tab.services"].tap()
        XCTAssertTrue(app.buttons["service.zikr"].waitForExistence(timeout: 10))
        app.buttons["tab.settings"].tap()
        XCTAssertTrue(app.buttons["settings.lang.ru"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["settings.appearance"].exists)
    }
}
