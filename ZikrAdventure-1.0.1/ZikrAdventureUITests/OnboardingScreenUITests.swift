import XCTest

final class OnboardingScreenUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(_ fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ZIKR_UITEST_AUTH"] = "guest"
        app.launchEnvironment["ZIKR_UITEST_ONBOARDING"] = fixture
        app.launch()
        return app
    }

    func testThreeStepsLanguageAndRelaunchPreserveProgress() {
        let app = launch("fresh")
        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 60))
        let settingsTab = app.buttons["tab.settings"]
        // XCTest can enumerate the presenting controller behind a modal; it must not accept taps.
        if settingsTab.exists { XCTAssertFalse(settingsTab.isHittable) }
        XCTAssertEqual(app.staticTexts["onboarding.title"].label, "Astaghfirullah")
        app.buttons["onboarding.language.ru"].tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["onboarding.title"], "Астагфируллах"))
        next.tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["onboarding.title"], "Путь Сиры"))
        next.tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["onboarding.title"], "С уважением"))
        next.tap()
        assertCounter(app, value: "123")
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "ZIKR_UITEST_ONBOARDING")
        app.launch()
        assertCounter(app, value: "123")
        XCTAssertFalse(app.buttons["onboarding.skip"].exists)
    }

    func testSkipAndExistingUser() {
        let app = launch("fresh")
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 60))
        app.buttons["onboarding.skip"].tap()
        assertCounter(app, value: "123")
        app.terminate()
        app.launchEnvironment["ZIKR_UITEST_ONBOARDING"] = "completed"
        app.launch()
        assertCounter(app, value: "123")
        XCTAssertFalse(app.buttons["onboarding.skip"].exists)
    }

    func testLanguageThemeAndWebReferenceScreenshots() {
        let app = XCUIApplication()
        app.launchEnvironment["ZIKR_UITEST_AUTH"] = "guest"
        app.launchEnvironment["ZIKR_UITEST_ONBOARDING"] = "fresh"
        for style in ["Light", "Dark"] {
            app.launchArguments = ["-AppleInterfaceStyle", style]
            app.launch()
            XCTAssertTrue(app.buttons["onboarding.next"].waitForExistence(timeout: 60))
            for language in ["ru", "en", "uz", "tg", "kk", "ky"] {
                app.buttons["onboarding.language.\(language)"].tap()
                // Wait for the committed selection, not a screenshot of the previous language.
                let selected = NSPredicate(format: "isSelected == true")
                XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: selected, object: app.buttons["onboarding.language.\(language)"])], timeout: 5), .completed)
                capture(app, "native-\(style)-\(language)-1")
            }
            app.buttons["onboarding.next"].tap()
            capture(app, "native-\(style)-ky-2")
            app.buttons["onboarding.next"].tap()
            capture(app, "native-\(style)-ky-3")
            app.terminate()
            app.launchEnvironment["ZIKR_UITEST_WEB_ONBOARDING"] = "1"
            app.launch()
            XCTAssertTrue(app.webViews.buttons["Skip"].waitForExistence(timeout: 60))
            capture(app, "web-\(style)-en-1")
            app.terminate()
            app.launchEnvironment.removeValue(forKey: "ZIKR_UITEST_WEB_ONBOARDING")
        }
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertCounter(_ app: XCUIApplication, value: String) {
        XCTAssertTrue(app.buttons["zikr.button"].waitForExistence(timeout: 60))
        let counter = app.descendants(matching: .any)["zikr.total"].firstMatch
        let predicate = NSPredicate(format: "value == %@ OR label == %@", value, value)
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: counter)], timeout: 10), .completed)
    }

    private func waitForLabel(_ element: XCUIElement, _ label: String) -> Bool {
        XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)], timeout: 10) == .completed
    }
}
