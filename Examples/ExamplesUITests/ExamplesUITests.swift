import XCTest

final class ExamplesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPagerLaunchesAndSwitchesTabs() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["CollapsiblePager Demo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Short"].waitForExistence(timeout: 5))

        app.buttons["Short"].tap()
        XCTAssertTrue(app.tables["demo-list-short"].waitForExistence(timeout: 5))

        app.buttons["Empty"].tap()
        XCTAssertTrue(app.staticTexts["No rows in Empty"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testNavigationButtonPushesPagerAndEdgeSwipeReturns() throws {
        let app = XCUIApplication()
        app.launch()

        let pushButton = app.navigationBars["CollapsiblePager"].buttons["Push Pager"]
        XCTAssertTrue(pushButton.waitForExistence(timeout: 5))

        pushButton.tap()
        XCTAssertTrue(app.navigationBars["Pushed Pager"].waitForExistence(timeout: 5))

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)

        XCTAssertTrue(app.navigationBars["CollapsiblePager"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
