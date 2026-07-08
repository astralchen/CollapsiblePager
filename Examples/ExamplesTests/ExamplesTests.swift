import CollapsiblePager
import Testing
import UIKit
@testable import Examples

@MainActor
struct ExamplesTests {
    @Test func applicationRootUsesTabBarNavigationPagerHierarchy() throws {
        let dataSource = DemoPagerDataSource()
        let rootViewController = DemoPagerFactory.makeApplicationRoot(dataSource: dataSource)

        let tabBarController = rootViewController
        let viewControllers = try #require(tabBarController.viewControllers)
        let navigationController = try #require(tabBarController.viewControllers?.first as? UINavigationController)
        let pager = try #require(navigationController.viewControllers.first as? CollapsiblePagerViewController)

        #expect(viewControllers.count == 2)
        #expect(tabBarController.selectedViewController === navigationController)
        #expect(navigationController.navigationBar.prefersLargeTitles == false)
        #expect(navigationController.tabBarItem.title == "Pager")
        #expect(navigationController.tabBarItem.image != nil)
        #expect(navigationController.tabBarItem.selectedImage != nil)
        #expect(navigationController.tabBarItem.image?.renderingMode == .alwaysTemplate)
        #expect(navigationController.tabBarItem.selectedImage?.renderingMode == .alwaysTemplate)
        #expect(pager.navigationItem.largeTitleDisplayMode == .never)
        #expect(pager.dataSource === dataSource)
        #expect(pager.delegate === dataSource)
        #expect(pager.configuration.refreshHandoffMode == .container)
        #expect(pager.containerRefreshHostScrollView.refreshControl?.attributedTitle?.string == "Container refresh")
        #expect(pager.effectiveSelectedIndex == 0)
        #expect(dataSource.headerViewController.parent === pager)
        #expect(dataSource.headerViewController.view === dataSource.headerView)
    }

    @Test func refreshHandoffValidationTabCoversAllModes() throws {
        let dataSource = DemoPagerDataSource()
        let rootViewController = DemoPagerFactory.makeApplicationRoot(dataSource: dataSource)
        let viewControllers = try #require(rootViewController.viewControllers)
        try #require(viewControllers.count == 2)

        let refreshNavigationController = try #require(viewControllers[1] as? UINavigationController)
        let refreshHandoffModeController = try #require(
            refreshNavigationController.viewControllers.first as? DemoRefreshHandoffModeViewController
        )

        #expect(refreshNavigationController.navigationBar.prefersLargeTitles == false)
        #expect(refreshNavigationController.tabBarItem.title == "Refresh")
        #expect(refreshNavigationController.tabBarItem.image != nil)
        #expect(refreshNavigationController.tabBarItem.selectedImage != nil)
        #expect(refreshNavigationController.tabBarItem.image?.renderingMode == .alwaysTemplate)
        #expect(refreshNavigationController.tabBarItem.selectedImage?.renderingMode == .alwaysTemplate)
        #expect(refreshHandoffModeController.navigationItem.title == "Refresh Handoff")
        #expect(refreshHandoffModeController.availableRefreshHandoffModesForTesting == [.none, .container, .child])

        refreshHandoffModeController.loadViewIfNeeded()
        let modeMenuItem = try #require(refreshHandoffModeController.navigationItem.rightBarButtonItem)

        #expect(modeMenuItem.accessibilityIdentifier == "refresh-mode-menu-button")
        #expect(modeMenuItem.title == "None")
        #expect(refreshHandoffModeController.view.subviews.allSatisfy { !($0 is UISegmentedControl) })

        for mode in refreshHandoffModeController.availableRefreshHandoffModesForTesting {
            refreshHandoffModeController.selectRefreshHandoffModeForTesting(mode)
            #expect(refreshHandoffModeController.navigationItem.rightBarButtonItem?.title == mode.demoTitleForTesting)

            let pager = try #require(refreshHandoffModeController.pagerForTesting(mode: mode))
            #expect(pager.configuration.refreshHandoffMode == mode)
            let dataSource = try #require(refreshHandoffModeController.dataSourceForTesting(mode: mode))
            #expect(dataSource.headerViewController.parent === pager)
            #expect(dataSource.headerViewController.view === dataSource.headerView)
            if mode == .child {
                #expect(pager.configuration.headerPullDownRefreshBehavior == .suppressesChildRefresh)
                #expect(
                    dataSource.headerView.subtitleTextForTesting ==
                    "Child mode: header pull-down is suppressed; pull from list content to trigger child refresh."
                )
            } else {
                #expect(pager.configuration.headerPullDownRefreshBehavior == .allowsChildRefresh)
            }
            #expect(pager.effectiveSelectedIndex == 0)
        }
    }

    @Test func navigationBarButtonPushesPagerAndKeepsBackGestureEnabled() throws {
        let dataSource = DemoPagerDataSource()
        let rootViewController = DemoPagerFactory.makeApplicationRoot(dataSource: dataSource)
        let navigationController = try #require(rootViewController.viewControllers?.first as? UINavigationController)
        let rootPager = try #require(navigationController.viewControllers.first as? CollapsiblePagerViewController)
        let pushButton = try #require(rootPager.navigationItem.rightBarButtonItem)

        navigationController.loadViewIfNeeded()

        #expect(pushButton.image != nil)
        #expect(pushButton.accessibilityIdentifier == "push-pager-button")
        #expect(pushButton.accessibilityLabel == "Push Pager")

        let action = try #require(pushButton.action)
        #expect(UIApplication.shared.sendAction(action, to: pushButton.target, from: pushButton, for: nil))

        let pushedPager = try #require(navigationController.viewControllers.last as? CollapsiblePagerViewController)
        let popGesture = try #require(navigationController.interactivePopGestureRecognizer)

        #expect(navigationController.viewControllers.count == 2)
        #expect(pushedPager !== rootPager)
        #expect(pushedPager.navigationItem.title == "Pushed Pager")
        #expect(pushedPager.navigationItem.largeTitleDisplayMode == .never)
        #expect(pushedPager.hidesBottomBarWhenPushed)
        #expect(pushedPager.dataSource != nil)
        #expect(pushedPager.delegate != nil)
        #expect(popGesture.isEnabled)
    }

    @Test func demoRefreshControlIsPreservedAsChildOwnedUIKitControl() throws {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        scrollView.contentInset.top = 308
        let refreshController = DemoRefreshController()

        refreshController.attach(to: scrollView, title: "Child refresh")
        scrollView.layoutIfNeeded()

        let refreshControl = try #require(scrollView.refreshControl)

        #expect(refreshControl.attributedTitle?.string == "Child refresh")
        #expect(scrollView.subviews.allSatisfy { $0.accessibilityIdentifier != "demo-refresh-view" })
    }

    @Test func longListUsesRefreshableBottomLoadMoreToAppendRows() async throws {
        let listViewController = DemoListViewController(
            title: "Long",
            rowCount: 60,
            refreshTitle: nil,
            loadMoreConfiguration: DemoLoadMoreConfiguration(
                batchSize: 3,
                maximumAdditionalRows: 6,
                delayNanoseconds: 0
            ),
            accessibilityID: "demo-list-long"
        )

        listViewController.loadViewIfNeeded()
        makeVisibleForTesting(listViewController)

        #expect(listViewController.tableView.numberOfRows(inSection: 0) == 60)

        listViewController.beginLoadingMoreForTesting()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(listViewController.tableView.numberOfRows(inSection: 0) == 63)
        let appendedCell = listViewController.tableView(
            listViewController.tableView,
            cellForRowAt: IndexPath(row: 62, section: 0)
        )
        #expect(
            appendedCell.textLabel?.text == "Long row 63"
        )
    }

    @Test func programmaticBottomOffsetDoesNotAutomaticallyLoadMoreRows() async throws {
        let listViewController = DemoListViewController(
            title: "Long",
            rowCount: 60,
            refreshTitle: nil,
            loadMoreConfiguration: DemoLoadMoreConfiguration(
                batchSize: 4,
                maximumAdditionalRows: 12,
                delayNanoseconds: 0
            ),
            accessibilityID: "demo-list-long"
        )

        listViewController.loadViewIfNeeded()
        makeVisibleForTesting(listViewController)
        listViewController.tableView.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        listViewController.tableView.contentInset = UIEdgeInsets(top: 308, left: 0, bottom: 83, right: 0)
        listViewController.tableView.layoutIfNeeded()

        let bottomOffsetY = max(
            -listViewController.tableView.adjustedContentInset.top,
            listViewController.tableView.contentSize.height
                + listViewController.tableView.adjustedContentInset.bottom
                - listViewController.tableView.bounds.height
        )
        listViewController.tableView.setContentOffset(CGPoint(x: 0, y: bottomOffsetY), animated: false)

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(listViewController.tableView.numberOfRows(inSection: 0) == 60)
    }

    @Test func noMoreFooterIncludesBottomObstructionWhenInsetChangesDuringLoadMore() async throws {
        let listViewController = DemoListViewController(
            title: "Long",
            rowCount: 60,
            refreshTitle: nil,
            loadMoreConfiguration: DemoLoadMoreConfiguration(
                batchSize: 4,
                maximumAdditionalRows: 4,
                delayNanoseconds: 50_000_000
            ),
            accessibilityID: "demo-list-long"
        )

        listViewController.loadViewIfNeeded()
        makeVisibleForTesting(listViewController)
        listViewController.tableView.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        listViewController.tableView.layoutIfNeeded()

        listViewController.beginLoadingMoreForTesting()
        listViewController.tableView.contentInset = UIEdgeInsets(top: 308, left: 0, bottom: 83, right: 0)
        listViewController.tableView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 308, left: 0, bottom: 83, right: 0)

        try await Task.sleep(nanoseconds: 450_000_000)

        #expect(listViewController.tableView.numberOfRows(inSection: 0) == 64)
        #expect(listViewController.tableView.contentInset.bottom >= 83 + DemoLoadMoreFooterMetrics.reservedExtent)
    }

    @Test func longListLoadedRowsPersistWhenDataSourceRecreatesController() async throws {
        let dataSource = DemoPagerDataSource(pages: [
            DemoPagerDataSource.Page(
                title: "Long",
                rowCount: 60,
                refreshTitle: nil,
                accessibilityID: "demo-list-long",
                loadMoreConfiguration: DemoLoadMoreConfiguration(
                    batchSize: 4,
                    maximumAdditionalRows: 12,
                    delayNanoseconds: 0
                )
            ),
            DemoPagerDataSource.Page(title: "Short", rowCount: 8, refreshTitle: nil, accessibilityID: "demo-list-short"),
            DemoPagerDataSource.Page(title: "Empty", rowCount: 0, refreshTitle: nil, accessibilityID: "demo-list-empty"),
        ])
        let pager = CollapsiblePagerViewController()

        let firstLongList = try #require(
            dataSource.pagerViewController(pager, viewControllerForPageAt: 0) as? DemoListViewController
        )
        firstLongList.loadViewIfNeeded()
        makeVisibleForTesting(firstLongList)

        for (index, expectedRowCount) in [64, 68, 72].enumerated() {
            firstLongList.beginLoadingMoreForTesting()
            try await waitForRowCount(expectedRowCount, in: firstLongList.tableView)
            if index < 2 {
                try await Task.sleep(nanoseconds: 300_000_000)
            }
        }

        makeHiddenForTesting(firstLongList)

        let recreatedLongList = try #require(
            dataSource.pagerViewController(pager, viewControllerForPageAt: 0) as? DemoListViewController
        )
        recreatedLongList.loadViewIfNeeded()

        #expect(recreatedLongList.tableView.numberOfRows(inSection: 0) == 72)
    }

    @Test func recreatedLongListKeepsVisibleNoMoreFooterAfterUnload() async throws {
        let dataSource = DemoPagerDataSource(pages: [
            DemoPagerDataSource.Page(
                title: "Long",
                rowCount: 60,
                refreshTitle: nil,
                accessibilityID: "demo-list-long",
                loadMoreConfiguration: DemoLoadMoreConfiguration(
                    batchSize: 4,
                    maximumAdditionalRows: 12,
                    delayNanoseconds: 0
                )
            ),
            DemoPagerDataSource.Page(title: "Short", rowCount: 8, refreshTitle: nil, accessibilityID: "demo-list-short"),
            DemoPagerDataSource.Page(title: "Empty", rowCount: 0, refreshTitle: nil, accessibilityID: "demo-list-empty"),
        ])
        let pager = CollapsiblePagerViewController()

        let firstLongList = try #require(
            dataSource.pagerViewController(pager, viewControllerForPageAt: 0) as? DemoListViewController
        )
        firstLongList.loadViewIfNeeded()
        configurePagerManagedInsetsForTesting(firstLongList.tableView)
        makeVisibleForTesting(firstLongList)

        for (index, expectedRowCount) in [64, 68, 72].enumerated() {
            firstLongList.beginLoadingMoreForTesting()
            try await waitForRowCount(expectedRowCount, in: firstLongList.tableView)
            if index < 2 {
                try await Task.sleep(nanoseconds: 300_000_000)
            }
        }

        reserveNoMoreFooterInsetForTesting(firstLongList.tableView)
        let visibleFooterOffsetY = maximumVerticalOffsetY(in: firstLongList.tableView)
        firstLongList.tableView.setContentOffset(CGPoint(x: 0, y: visibleFooterOffsetY), animated: false)
        makeHiddenForTesting(firstLongList)

        let recreatedLongList = try #require(
            dataSource.pagerViewController(pager, viewControllerForPageAt: 0) as? DemoListViewController
        )
        recreatedLongList.loadViewIfNeeded()
        configurePagerManagedInsetsForTesting(recreatedLongList.tableView)
        reserveNoMoreFooterInsetForTesting(recreatedLongList.tableView)
        let rowContentBottomOffsetY = maximumVerticalOffsetY(in: recreatedLongList.tableView, bottomInset: 83)
        recreatedLongList.tableView.setContentOffset(CGPoint(x: 0, y: rowContentBottomOffsetY), animated: false)
        makeVisibleForTesting(recreatedLongList)

        #expect(recreatedLongList.tableView.numberOfRows(inSection: 0) == 72)
        #expect(recreatedLongList.tableView.contentOffset.y >= maximumVerticalOffsetY(in: recreatedLongList.tableView) - 0.5)
    }

    @Test func offscreenLongListLoadMoreCompletionDoesNotAppendRows() async throws {
        let listViewController = DemoListViewController(
            title: "Long",
            rowCount: 60,
            refreshTitle: nil,
            loadMoreConfiguration: DemoLoadMoreConfiguration(
                batchSize: 4,
                maximumAdditionalRows: 12,
                delayNanoseconds: 50_000_000
            ),
            accessibilityID: "demo-list-long"
        )

        listViewController.loadViewIfNeeded()
        makeVisibleForTesting(listViewController)
        listViewController.beginLoadingMoreForTesting()
        makeHiddenForTesting(listViewController)

        try await Task.sleep(nanoseconds: 120_000_000)

        #expect(listViewController.tableView.numberOfRows(inSection: 0) == 60)
    }

    @Test func emptyListCentersEmptyStateBelowPinnedTabBarWhenCollapsed() throws {
        let listViewController = DemoListViewController(
            title: "Empty",
            rowCount: 0,
            refreshTitle: nil,
            accessibilityID: "demo-list-empty"
        )

        listViewController.loadViewIfNeeded()
        let hostView = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        listViewController.view.frame = hostView.bounds
        hostView.addSubview(listViewController.view)
        listViewController.tableView.contentInset = UIEdgeInsets(top: 308, left: 0, bottom: 796, right: 0)
        listViewController.tableView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 308, left: 0, bottom: 83, right: 0)
        listViewController.tableView.layoutIfNeeded()
        listViewController.tableView.setContentOffset(CGPoint(x: 0, y: -48), animated: false)
        listViewController.scrollViewDidScroll(listViewController.tableView)
        hostView.setNeedsLayout()
        hostView.layoutIfNeeded()
        listViewController.tableView.layoutIfNeeded()

        #expect(listViewController.tableView.backgroundView?.accessibilityIdentifier == "demo-list-empty-background")
        let emptyLabel = try #require(
            findSubview(in: listViewController.tableView.backgroundView, accessibilityIdentifier: "demo-list-empty-empty")
        )
        let labelFrame = emptyLabel.convert(emptyLabel.bounds, to: hostView)
        let visibleContentCenterY = (48 + (844 - 83)) / 2.0

        #expect(abs(labelFrame.midX - 195) < 0.5)
        #expect(abs(labelFrame.midY - visibleContentCenterY) < 0.5)
    }
}

@MainActor
private func makeVisibleForTesting(_ viewController: UIViewController) {
    viewController.beginAppearanceTransition(true, animated: false)
    viewController.endAppearanceTransition()
}

@MainActor
private func makeHiddenForTesting(_ viewController: UIViewController) {
    viewController.beginAppearanceTransition(false, animated: false)
    viewController.endAppearanceTransition()
}

@MainActor
private func waitForRowCount(_ expectedRowCount: Int, in tableView: UITableView) async throws {
    for _ in 0..<20 {
        if tableView.numberOfRows(inSection: 0) == expectedRowCount {
            return
        }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
    #expect(tableView.numberOfRows(inSection: 0) == expectedRowCount)
}

@MainActor
private func configurePagerManagedInsetsForTesting(_ tableView: UITableView) {
    tableView.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    tableView.contentInsetAdjustmentBehavior = .never
    tableView.automaticallyAdjustsScrollIndicatorInsets = false
    tableView.contentInset = UIEdgeInsets(top: 308, left: 0, bottom: 83, right: 0)
    tableView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 308, left: 0, bottom: 83, right: 0)
    tableView.layoutIfNeeded()
}

@MainActor
private func reserveNoMoreFooterInsetForTesting(_ tableView: UITableView) {
    var contentInset = tableView.contentInset
    contentInset.bottom = 83 + DemoLoadMoreFooterMetrics.reservedExtent
    tableView.contentInset = contentInset
}

@MainActor
private func maximumVerticalOffsetY(in scrollView: UIScrollView, bottomInset: CGFloat? = nil) -> CGFloat {
    max(
        -scrollView.contentInset.top,
        scrollView.contentSize.height + (bottomInset ?? scrollView.contentInset.bottom) - scrollView.bounds.height
    )
}

@MainActor
private func findSubview(in view: UIView?, accessibilityIdentifier: String) -> UIView? {
    guard let view else {
        return nil
    }
    if view.accessibilityIdentifier == accessibilityIdentifier {
        return view
    }
    for subview in view.subviews {
        if let match = findSubview(in: subview, accessibilityIdentifier: accessibilityIdentifier) {
            return match
        }
    }
    return nil
}
