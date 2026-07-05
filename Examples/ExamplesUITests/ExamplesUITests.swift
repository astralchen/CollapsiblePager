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
    func testPullDownRevealsHeaderBeforeRowsOverscroll() throws {
        let app = XCUIApplication()
        app.launch()

        let table = app.tables["demo-list-long"]
        XCTAssertTrue(table.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["demo-header-progress"].waitForExistence(timeout: 8))

        table.swipeUp()
        XCTAssertTrue(table.cells["demo-list-long-row-10"].waitForExistence(timeout: 8))

        let title = app.staticTexts["CollapsiblePager Demo"]
        for _ in 0..<3 where !title.isHittable {
            table.swipeDown()
        }

        XCTAssertTrue(title.isHittable)
        XCTAssertTrue(app.staticTexts["demo-header-selection"].isHittable)
        XCTAssertTrue(app.staticTexts["demo-header-progress"].isHittable)
    }

    @MainActor
    func testRefreshHandoffTabSwitchesAllModes() throws {
        let app = XCUIApplication()
        app.launch()

        let refreshTab = app.tabBars.buttons["Refresh"]
        XCTAssertTrue(refreshTab.waitForExistence(timeout: 5))
        refreshTab.tap()

        let navigationBar = app.navigationBars["Refresh Handoff"]
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Refresh Handoff: None"].waitForExistence(timeout: 5))

        let modeMenuButton = navigationBar.buttons["refresh-mode-menu-button"]
        XCTAssertTrue(modeMenuButton.waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls["refresh-mode-segmented-control"].exists)

        selectRefreshHandoffMode("Container", in: app)
        XCTAssertTrue(app.staticTexts["Refresh Handoff: Container"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tables["refresh-mode-container-list"].waitForExistence(timeout: 5))

        selectRefreshHandoffMode("Child", in: app)
        XCTAssertTrue(app.staticTexts["Refresh Handoff: Child"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tables["refresh-mode-child-list"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func selectRefreshHandoffMode(_ title: String, in app: XCUIApplication) {
        let modeMenuButton = app.navigationBars["Refresh Handoff"].buttons["refresh-mode-menu-button"]
        modeMenuButton.tap()

        let menuItem = app.menuItems[title]
        if menuItem.waitForExistence(timeout: 2) {
            menuItem.tap()
        } else {
            app.buttons[title].tap()
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
