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
        let navigationController = try #require(tabBarController.viewControllers?.first as? UINavigationController)
        let pager = try #require(navigationController.viewControllers.first as? CollapsiblePagerViewController)

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
        #expect(pager.effectiveSelectedIndex == 0)
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
        #expect(pushedPager.dataSource != nil)
        #expect(pushedPager.delegate != nil)
        #expect(popGesture.isEnabled)
    }
}
