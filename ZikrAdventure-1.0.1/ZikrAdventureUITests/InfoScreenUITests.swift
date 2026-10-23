// InfoScreenUITests.swift
// ZKR-48: нативный экран «Инфо» — список, лист темы, легенда, закрытие кнопкой и затемнением.
// Не зависит от языка: элементы ищутся по accessibilityIdentifier.

import XCTest

final class InfoScreenUITests: XCTestCase {
    /// T("onb.skip") на всех 6 языках index.html.
    private static let skipTitles = ["Пропустить", "Skip", "O‘tkazib yuborish", "Гузаштан", "Өткізу", "Өткөрүү"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testInfoListOpensAndClosesSheets() {
        let app = XCUIApplication()
        app.launch()
        skipOnboardingIfShown(app)

        let infoTab = app.buttons["tab.info"]
        XCTAssertTrue(infoTab.waitForExistence(timeout: 10))
        infoTab.tap()

        for row in ["about", "how", "sources", "privacy", "legend"] {
            XCTAssertTrue(app.buttons["info.row.\(row)"].waitForExistence(timeout: 10), "нет строки \(row)")
        }

        // Тема: заголовок + текст, закрытие кнопкой.
        app.buttons["info.row.about"].tap()
        XCTAssertTrue(app.staticTexts["info.sheet.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["info.sheet.body"].exists)
        app.buttons["info.sheet.close"].tap()
        XCTAssertTrue(waitForDisappearance(app.buttons["info.sheet.close"]))

        // Легенда: закрытие нажатием на затемнение над листом.
        app.buttons["info.row.legend"].tap()
        XCTAssertTrue(app.buttons["info.sheet.close"].waitForExistence(timeout: 5))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        XCTAssertTrue(waitForDisappearance(app.buttons["info.sheet.close"]))

        // Уход с вкладки закрывает лист; возврат — снова список.
        app.buttons["info.row.privacy"].tap()
        XCTAssertTrue(app.buttons["info.sheet.close"].waitForExistence(timeout: 5))
        app.buttons["tab.zikr"].tap()
        XCTAssertTrue(waitForDisappearance(app.buttons["info.row.about"]))
        infoTab.tap()
        XCTAssertTrue(app.buttons["info.row.about"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["info.sheet.close"].exists)
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

    private func waitForDisappearance(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
