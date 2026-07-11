import XCTest

final class TallySmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchesIntoOnboardingOrCounters() throws {
        let app = XCUIApplication()
        app.launch()

        if app.buttons["Skip"].waitForExistence(timeout: 3) {
            app.buttons["Skip"].tap()
        }

        XCTAssertTrue(app.staticTexts["Tally"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Counters"].exists)
        XCTAssertTrue(app.tabBars.buttons["Sessions"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }

    func testCreateMenuSeparatesCountersAndFolders() throws {
        let app = XCUIApplication()
        app.launch()
        if app.buttons["Skip"].waitForExistence(timeout: 2) {
            app.buttons["Skip"].tap()
        }

        let createButton = app.buttons["Create"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        XCTAssertTrue(app.buttons["New Counter"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["New Folder"].exists)
    }
}
