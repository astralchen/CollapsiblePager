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
}
