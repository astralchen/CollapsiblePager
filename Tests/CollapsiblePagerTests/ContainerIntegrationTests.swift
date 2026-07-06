import Testing
import UIKit
@testable import CollapsiblePager

@MainActor
@Test func reloadDataWithNoPagesKeepsPublicSelectedIndexZeroAndClearsEffectiveSelection() {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 0)
    pager.dataSource = dataSource

    pager.reloadData()

    #expect(pager.selectedIndex == 0)
    #expect(pager.effectiveSelectedIndex == nil)
    #expect(pager.tabBarItemCountForTesting == 0)
    #expect(pager.pageContainerPageCountForTesting == 0)
    #expect(pager.loadedChildIndexesForTesting.isEmpty)
}

@MainActor
@Test func pagingBounceConfigurationAppliesToPageContainer() {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.paging.bouncesHorizontally = false
    let pager = CollapsiblePagerViewController(configuration: configuration)

    pager.loadViewIfNeeded()
    #expect(pager.pageContainerBouncesForTesting == false)
    #expect(pager.pageContainerAlwaysBouncesHorizontallyForTesting == false)

    pager.configuration.paging.bouncesHorizontally = true
    #expect(pager.pageContainerBouncesForTesting)
    #expect(pager.pageContainerAlwaysBouncesHorizontallyForTesting == false)
}

@MainActor
@Test func reloadDataConnectsHeaderTabBarPageContainerAndFirstChild() {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 3)
    pager.dataSource = dataSource

    pager.reloadData()

    #expect(dataSource.headerRequestCount == 1)
    #expect(pager.tabBarItemCountForTesting == 3)
    #expect(pager.pageContainerPageCountForTesting == 3)
    #expect(pager.loadedChildIndexesForTesting == [0, 1])
    #expect(pager.pageContainerLoadedPageIndexesForTesting == [0, 1])
    #expect(pager.effectiveSelectedIndex == 0)
}

@MainActor
@Test func reloadDataClampsSelectionWhenPageCountShrinks() {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 3)
    pager.dataSource = dataSource
    pager.reloadData()

    pager.selectPage(at: 2, animated: false)
    dataSource.pageCount = 1
    pager.reloadData()

    #expect(pager.selectedIndex == 0)
    #expect(pager.effectiveSelectedIndex == 0)
    #expect(pager.tabBarItemCountForTesting == 1)
    #expect(pager.loadedChildIndexesForTesting == [0])
}

@MainActor
@Test func adjacentAnimatedSelectionCommitsAfterPageContainerCompletes() {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 3)
    let delegate = SelectionRecorder()
    pager.dataSource = dataSource
    pager.delegate = delegate
    pager.reloadData()

    pager.selectPage(at: 1, animated: true)
    #expect(pager.selectedIndex == 0)
    #expect(pager.effectiveSelectedIndex == 0)
    #expect(pager.loadedChildIndexesForTesting == [0, 1])

    pager.completePendingPageTransitionForTesting(targetIndex: 1)

    #expect(pager.selectedIndex == 1)
    #expect(pager.effectiveSelectedIndex == 1)
    #expect(pager.loadedChildIndexesForTesting == [0, 1, 2])
    #expect(delegate.selectedIndexes == [1])
}

@MainActor
@Test func supersededAnimatedPageCompletionDoesNotCommitIntermediatePage() {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 3)
    let delegate = SelectionRecorder()
    pager.dataSource = dataSource
    pager.delegate = delegate
    pager.reloadData()

    pager.selectPage(at: 1, animated: false)
    pager.tapTabItemForTesting(at: 0)
    pager.tapTabItemForTesting(at: 2)

    #expect(pager.selectedIndex == 1)
    #expect(pager.effectiveSelectedIndex == 1)
    #expect(delegate.selectedIndexes == [1])

    pager.completePendingPageTransitionForTesting(targetIndex: 0)

    #expect(pager.selectedIndex == 1)
    #expect(pager.effectiveSelectedIndex == 1)
    #expect(delegate.selectedIndexes == [1])

    pager.completePendingPageTransitionForTesting(targetIndex: 2)

    #expect(pager.selectedIndex == 2)
    #expect(pager.effectiveSelectedIndex == 2)
    #expect(delegate.selectedIndexes == [1, 2])
}

@MainActor
@Test func pageWindowPrunesVisitedControllersOutsideCurrentNeighborhood() {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 6)
    pager.dataSource = dataSource

    pager.reloadData()
    for index in 1..<6 {
        pager.selectPage(at: index, animated: false)
    }

    #expect(pager.selectedIndex == 5)
    #expect(pager.loadedChildIndexesForTesting == [4, 5])
    #expect(pager.pageContainerLoadedPageIndexesForTesting == [4, 5])
}

@MainActor
@Test func nonAdjacentAnimatedSelectionUsesDirectSourceTargetTransition() {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 20)
    let delegate = SelectionRecorder()
    pager.dataSource = dataSource
    pager.delegate = delegate
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()
    pager.selectPage(at: 19, animated: false)

    #expect(pager.loadedChildIndexesForTesting == [18, 19])
    #expect(pager.pageContainerLoadedPageIndexesForTesting == [18, 19])

    pager.selectPage(at: 0, animated: true)

    #expect(pager.selectedIndex == 0)
    #expect(pager.effectiveSelectedIndex == 0)
    #expect(pager.loadedChildIndexesForTesting == [0, 1])
    #expect(pager.pageContainerLoadedPageIndexesForTesting == [0, 1])
    #expect(delegate.selectedIndexes == [19, 0])
}

@MainActor
@Test func pageTransitionForwardsChildAppearanceLifecycleWhenVisible() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = LifecycleDataSource(pageCount: 2)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.beginAppearanceTransition(true, animated: false)
    pager.endAppearanceTransition()

    let firstChild = try #require(dataSource.child(at: 0))
    #expect(firstChild.events == ["willAppear", "didAppear"])

    pager.selectPage(at: 1, animated: false)

    let secondChild = try #require(dataSource.child(at: 1))
    #expect(firstChild.events == ["willAppear", "didAppear", "willDisappear", "didDisappear"])
    #expect(secondChild.events == ["willAppear", "didAppear"])
}

@MainActor
@Test func navigationPushAndPopForwardsChildAppearanceLifecycle() throws {
    let rootPager = CollapsiblePagerViewController()
    let rootDataSource = LifecycleDataSource(pageCount: 1)
    rootPager.dataSource = rootDataSource
    rootPager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    rootPager.reloadData()

    let navigationController = UINavigationController(rootViewController: rootPager)
    navigationController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = navigationController
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    navigationController.view.layoutIfNeeded()

    let rootChild = try #require(rootDataSource.child(at: 0))
    #expect(rootChild.animatedEvents == ["willAppear:false", "didAppear:false"])

    let pushedPager = CollapsiblePagerViewController()
    let pushedDataSource = LifecycleDataSource(pageCount: 1)
    pushedPager.dataSource = pushedDataSource
    pushedPager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    pushedPager.reloadData()

    navigationController.pushViewController(pushedPager, animated: false)
    navigationController.view.layoutIfNeeded()

    let pushedChild = try #require(pushedDataSource.child(at: 0))
    #expect(rootChild.animatedEvents == [
        "willAppear:false",
        "didAppear:false",
        "willDisappear:false",
        "didDisappear:false",
    ])
    #expect(pushedChild.animatedEvents == ["willAppear:false", "didAppear:false"])

    navigationController.popViewController(animated: false)
    navigationController.view.layoutIfNeeded()

    #expect(rootChild.animatedEvents == [
        "willAppear:false",
        "didAppear:false",
        "willDisappear:false",
        "didDisappear:false",
        "willAppear:false",
        "didAppear:false",
    ])
    #expect(pushedChild.animatedEvents == [
        "willAppear:false",
        "didAppear:false",
        "willDisappear:false",
        "didDisappear:false",
    ])
}

@MainActor
@Test func pushedPagerWithHiddenBottomBarUpdatesChildScrollIndicatorInset() throws {
    let rootPager = CollapsiblePagerViewController()
    let rootDataSource = DemoDataSource(pageCount: 1)
    rootPager.dataSource = rootDataSource
    rootPager.reloadData()

    let navigationController = UINavigationController(rootViewController: rootPager)
    let tabBarController = UITabBarController()
    tabBarController.viewControllers = [navigationController]
    tabBarController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = tabBarController
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    tabBarController.view.layoutIfNeeded()
    navigationController.view.layoutIfNeeded()
    rootPager.view.layoutIfNeeded()

    let rootScrollView = try #require(rootPager.childScrollViewForTesting(at: 0))
    let visibleTabBarBottomInset = rootPager.view.safeAreaInsets.bottom
    #expect(rootScrollView.verticalScrollIndicatorInsets.bottom == visibleTabBarBottomInset)

    let pushedPager = CollapsiblePagerViewController()
    let pushedDataSource = DemoDataSource(pageCount: 1)
    pushedPager.dataSource = pushedDataSource
    pushedPager.hidesBottomBarWhenPushed = true
    pushedPager.reloadData()

    navigationController.pushViewController(pushedPager, animated: false)
    tabBarController.view.layoutIfNeeded()
    navigationController.view.layoutIfNeeded()
    pushedPager.view.layoutIfNeeded()

    let pushedScrollView = try #require(pushedPager.childScrollViewForTesting(at: 0))
    let hiddenTabBarBottomInset = pushedPager.view.safeAreaInsets.bottom
    #expect(hiddenTabBarBottomInset < visibleTabBarBottomInset)
    #expect(pushedScrollView.automaticallyAdjustsScrollIndicatorInsets == false)
    #expect(pushedScrollView.verticalScrollIndicatorInsets.bottom == hiddenTabBarBottomInset)
}

@MainActor
@Test func embeddedPagerPinsHeaderToOwnBoundsWhenPlacedBelowNavigationChrome() throws {
    let host = UIViewController()
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource

    let navigationController = UINavigationController(rootViewController: host)
    navigationController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = navigationController
    window.makeKeyAndVisible()
    defer { window.isHidden = true }

    host.addChild(pager)
    host.view.addSubview(pager.view)
    pager.view.frame = CGRect(x: 0, y: 220, width: 390, height: 624)
    pager.didMove(toParent: host)

    pager.reloadData()
    navigationController.view.layoutIfNeeded()
    pager.view.layoutIfNeeded()

    #expect(pager.headerFrameForTesting == CGRect(x: 0, y: 0, width: 390, height: 260))
    #expect(pager.tabBarFrameForTesting == CGRect(x: 0, y: 260, width: 390, height: 48))
}

@MainActor
@Test func adjacentTabBarSelectionAnimatesScrollAndControllerTransition() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = LifecycleDataSource(pageCount: 2)
    let delegate = SelectionRecorder()
    pager.dataSource = dataSource
    pager.delegate = delegate
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()
    pager.beginAppearanceTransition(true, animated: false)
    pager.endAppearanceTransition()

    pager.tapTabItemForTesting(at: 1)

    let firstChild = try #require(dataSource.child(at: 0))
    let secondChild = try #require(dataSource.child(at: 1))
    #expect(pager.selectedIndex == 0)
    #expect(pager.effectiveSelectedIndex == 0)
    #expect(delegate.selectedIndexes.isEmpty)
    #expect(firstChild.animatedEvents.suffix(1) == ["willDisappear:true"])
    #expect(secondChild.animatedEvents == ["willAppear:true"])

    pager.completePendingPageTransitionForTesting(targetIndex: 1)

    #expect(pager.selectedIndex == 1)
    #expect(pager.effectiveSelectedIndex == 1)
    #expect(delegate.selectedIndexes == [1])
    #expect(firstChild.animatedEvents.suffix(2) == ["willDisappear:true", "didDisappear:true"])
    #expect(secondChild.animatedEvents == ["willAppear:true", "didAppear:true"])
}

@MainActor
@Test func nonAdjacentTabBarSelectionSkipsScrollAnimationAndCommitsImmediately() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = LifecycleDataSource(pageCount: 3)
    let delegate = SelectionRecorder()
    pager.dataSource = dataSource
    pager.delegate = delegate
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()
    pager.beginAppearanceTransition(true, animated: false)
    pager.endAppearanceTransition()

    pager.tapTabItemForTesting(at: 2)

    let firstChild = try #require(dataSource.child(at: 0))
    let thirdChild = try #require(dataSource.child(at: 2))
    #expect(pager.selectedIndex == 2)
    #expect(pager.effectiveSelectedIndex == 2)
    #expect(delegate.selectedIndexes == [2])
    #expect(firstChild.animatedEvents.suffix(2) == ["willDisappear:false", "didDisappear:false"])
    #expect(thirdChild.animatedEvents == ["willAppear:false", "didAppear:false"])
}

@MainActor
@Test func tabBarSelectionToEmptyPageKeepsPinnedHeaderState() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 3)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let longScrollView = try #require(pager.childScrollViewForTesting(at: 0))
    longScrollView.contentSize = CGSize(width: 390, height: 1200)
    longScrollView.setContentOffset(CGPoint(x: 0, y: -48), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.collapseProgressForTesting == 1)
    #expect(pager.tabBarFrameForTesting.minY == 0)

    pager.tapTabItemForTesting(at: 2)
    pager.view.layoutIfNeeded()

    let emptyScrollView = try #require(pager.childScrollViewForTesting(at: 2))
    #expect(pager.selectedIndex == 2)
    #expect(pager.effectiveSelectedIndex == 2)
    #expect(pager.collapseProgressForTesting == 1)
    #expect(pager.tabBarFrameForTesting.minY == 0)
    #expect(emptyScrollView.contentOffset.y == -48)
}

@MainActor
@Test func tabBarSelectionBackToScrolledLongPagePreservesChildOffset() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 3)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let longScrollView = try #require(pager.childScrollViewForTesting(at: 0))
    let preservedOffsetY: CGFloat = 520
    longScrollView.contentSize = CGSize(width: 390, height: 2000)
    longScrollView.setContentOffset(CGPoint(x: 0, y: preservedOffsetY), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.collapseProgressForTesting == 1)

    pager.tapTabItemForTesting(at: 1)
    pager.view.layoutIfNeeded()

    let shortScrollView = try #require(pager.childScrollViewForTesting(at: 1))
    #expect(shortScrollView.contentOffset.y == -48)

    pager.tapTabItemForTesting(at: 0)
    pager.view.layoutIfNeeded()

    let returnedLongScrollView = try #require(pager.childScrollViewForTesting(at: 0))
    #expect(returnedLongScrollView === longScrollView)
    #expect(pager.selectedIndex == 0)
    #expect(pager.effectiveSelectedIndex == 0)
    #expect(pager.collapseProgressForTesting == 1)
    #expect(returnedLongScrollView.contentOffset.y == preservedOffsetY)
}

@MainActor
@Test func tabBarSelectionBackFromEmptyRestoresUnloadedLongChildOffset() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 3)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let longScrollView = try #require(pager.childScrollViewForTesting(at: 0))
    let preservedOffsetY: CGFloat = 520
    longScrollView.contentSize = CGSize(width: 390, height: 2000)
    longScrollView.setContentOffset(CGPoint(x: 0, y: preservedOffsetY), animated: false)
    pager.view.layoutIfNeeded()

    pager.tapTabItemForTesting(at: 2)
    pager.view.layoutIfNeeded()

    #expect(pager.loadedChildIndexesForTesting == [1, 2])

    pager.tapTabItemForTesting(at: 0)
    pager.view.layoutIfNeeded()

    let returnedLongScrollView = try #require(pager.childScrollViewForTesting(at: 0))
    returnedLongScrollView.contentSize = CGSize(width: 390, height: 2000)
    pager.view.layoutIfNeeded()

    #expect(pager.selectedIndex == 0)
    #expect(pager.effectiveSelectedIndex == 0)
    #expect(pager.collapseProgressForTesting == 1)
    #expect(returnedLongScrollView.contentOffset.y == preservedOffsetY)
}

@MainActor
@Test func horizontalPagingSuppressesChildScrollIndicatorsUntilStable() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 3)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let longScrollView = try #require(pager.childScrollViewForTesting(at: 0))
    let shortScrollView = try #require(pager.childScrollViewForTesting(at: 1))
    #expect(longScrollView.showsVerticalScrollIndicator)
    #expect(shortScrollView.showsVerticalScrollIndicator)

    let interactivePosition = try #require(PagePosition.make(rawPosition: 0.5, pageCount: 3, isInteractive: true))
    pager.updatePagePositionForTesting(interactivePosition)

    #expect(longScrollView.showsVerticalScrollIndicator == false)
    #expect(shortScrollView.showsVerticalScrollIndicator == false)
    #expect(longScrollView.showsHorizontalScrollIndicator == false)
    #expect(shortScrollView.showsHorizontalScrollIndicator == false)

    let stablePosition = try #require(PagePosition.make(rawPosition: 0, pageCount: 3, isInteractive: false))
    pager.updatePagePositionForTesting(stablePosition)

    #expect(longScrollView.showsVerticalScrollIndicator)
    #expect(shortScrollView.showsVerticalScrollIndicator)
    #expect(longScrollView.showsHorizontalScrollIndicator)
    #expect(shortScrollView.showsHorizontalScrollIndicator)
}

@MainActor
@Test func reloadDataRevealsHeaderBeforeRows() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    #expect(scrollView.contentInset.top == 308)
    #expect(scrollView.contentOffset.y == -308)
    #expect(pager.headerFrameForTesting == CGRect(x: 0, y: 0, width: 390, height: 260))
    #expect(pager.tabBarFrameForTesting == CGRect(x: 0, y: 260, width: 390, height: 48))
}

@MainActor
@Test func childVerticalScrollUpdatesCollapseAndPinsTabBar() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    scrollView.contentSize = CGSize(width: 390, height: 1200)
    scrollView.setContentOffset(CGPoint(x: 0, y: -48), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.collapseProgressForTesting == 1)
    #expect(pager.tabBarFrameForTesting.minY == 0)
}

@MainActor
@Test func reloadHeaderLayoutPreservesVisualPositionWhenHeaderHeightChanges() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.header.heightMode = .fixed(max: 260, min: 0)
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.setContentOffset(CGPoint(x: 0, y: -178), animated: false)
    pager.view.layoutIfNeeded()

    #expect(abs(pager.collapseProgressForTesting - 0.5) < 0.001)

    pager.configuration.header.heightMode = .fixed(max: 360, min: 0)
    pager.view.layoutIfNeeded()

    #expect(abs(pager.collapseProgressForTesting - (130.0 / 360.0)) < 0.001)
    #expect(scrollView.contentInset.top == 408)
    #expect(scrollView.contentOffset.y == -278)
    #expect(pager.headerFrameForTesting.height == 230)
    #expect(scrollView.contentOffset.y + scrollView.contentInset.top == 130)
}

@MainActor
@Test func reloadHeaderLayoutCanResetToExpandedOrCollapsed() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.setContentOffset(CGPoint(x: 0, y: -48), animated: false)
    pager.view.layoutIfNeeded()

    pager.reloadHeaderLayout(offsetPolicy: .resetToExpanded)
    pager.view.layoutIfNeeded()
    #expect(pager.collapseProgressForTesting == 0)
    #expect(scrollView.contentOffset.y == -308)

    pager.reloadHeaderLayout(offsetPolicy: .resetToCollapsed)
    pager.view.layoutIfNeeded()
    #expect(pager.collapseProgressForTesting == 1)
    #expect(scrollView.contentOffset.y == -48)
}

@MainActor
@Test func headerHostUsesCurrentChildMountWhenExpandedAndFixedOverlayWhenPinned() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 2)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let firstMount = try #require(pager.headerMountViewForTesting(at: 0))
    #expect(pager.headerHostSuperviewForTesting === firstMount)

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.setContentOffset(CGPoint(x: 0, y: -48), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.collapseProgressForTesting == 1)
    #expect(pager.headerHostSuperviewForTesting === pager.fixedHeaderContainerForTesting)
}

@MainActor
@Test func expandedHeaderHostInsideChildMountDoesNotCoverTabBarSpacer() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let mountView = try #require(pager.headerMountViewForTesting(at: 0))
    let headerHostView = try #require(mountView.subviews.first)

    #expect(mountView.bounds.height == 308)
    #expect(headerHostView.frame == CGRect(x: 0, y: 0, width: 390, height: 260))
}

@MainActor
@Test func topBounceKeepsHeaderHostInFixedOverlayToAvoidTabBarOverlap() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .none
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.setContentOffset(CGPoint(x: 0, y: -330), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.collapseProgressForTesting == 0)
    #expect(pager.activeRefreshHandoffForTesting == nil)
    #expect(pager.headerHostSuperviewForTesting === pager.fixedHeaderContainerForTesting)
    #expect(pager.tabBarFrameForTesting.minY == pager.headerFrameForTesting.maxY)

    let mountView = try #require(pager.headerMountViewForTesting(at: 0))
    scrollView.setContentOffset(CGPoint(x: 0, y: -308), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.headerHostSuperviewForTesting === mountView)
}

@MainActor
@Test func headerHostMovesToTargetChildMountAfterCompletedPageSelection() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 2)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()
    pager.tapTabItemForTesting(at: 1)

    #expect(pager.headerHostSuperviewForTesting === pager.fixedHeaderContainerForTesting)

    pager.completePendingPageTransitionForTesting(targetIndex: 1)
    pager.view.layoutIfNeeded()

    let secondMount = try #require(pager.headerMountViewForTesting(at: 1))
    #expect(pager.headerHostSuperviewForTesting === secondMount)
}

@MainActor
@Test func pagerBlocksHorizontalPagingFromHeaderArea() {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 2)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    pager.reloadData()
    pager.view.layoutIfNeeded()

    let allowed = pager.shouldBeginHorizontalPagingForTesting(
        translation: CGSize(width: -80, height: 4),
        location: CGPoint(x: 120, y: pager.headerFrameForTesting.midY)
    )

    #expect(allowed == false)
}

@MainActor
@Test func pagerAllowsHorizontalPagingFromPageContentArea() {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 2)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    pager.reloadData()
    pager.view.layoutIfNeeded()

    let allowed = pager.shouldBeginHorizontalPagingForTesting(
        translation: CGSize(width: -80, height: 4),
        location: CGPoint(x: 120, y: pager.tabBarFrameForTesting.maxY + 80)
    )

    #expect(allowed)
}

@MainActor
@Test func pullDownDoesNotBeginRefreshHandoffUntilHeaderExpanded() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .child
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.setContentOffset(CGPoint(x: 0, y: -120), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.activeRefreshHandoffForTesting == nil)
}

@MainActor
@Test func pullDownBeginsChildRefreshHandoffWhenExpandedAndAtTop() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .child
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.setContentOffset(CGPoint(x: 0, y: -330), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.activeRefreshHandoffForTesting == .childScrollView(index: 0))
    #expect(pager.containerRefreshHostScrollViewForTesting.contentOffset.y == 0)
}

@MainActor
@Test func pullDownInContainerModeRoutesOverscrollToContainerRefreshHost() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .container
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = TrackingDataSource()
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()
    let initialHeaderFrame = pager.headerFrameForTesting

    let scrollView = try #require(dataSource.child(at: 0)?.trackingScrollView)
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.simulatedTracking = true
    scrollView.simulatedDragging = true
    scrollView.setContentOffset(CGPoint(x: 0, y: -330), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.activeRefreshHandoffForTesting == .containerHost(index: 0))
    #expect(scrollView.contentOffset.y == -308)
    #expect(pager.containerRefreshHostScrollViewForTesting.contentOffset.y == -22)
    #expect(pager.headerFrameForTesting.minY == initialHeaderFrame.minY + 22)
    #expect(pager.tabBarFrameForTesting.minY == pager.headerFrameForTesting.maxY)
    #expect(pager.headerHostSuperviewForTesting === pager.fixedHeaderContainerForTesting)
}

@MainActor
@Test func pendingContainerRefreshProxyKeepsHeaderInFixedOverlayBeforeHandoffCommits() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .container
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.setContentOffset(CGPoint(x: 0, y: -308), animated: false)
    pager.view.layoutIfNeeded()

    pager.applyContainerRefreshProxyOverscrollForTesting(-24)

    #expect(pager.activeRefreshHandoffForTesting == nil)
    #expect(try containerRefreshProxyOverscrollOffsetY(in: pager) == -24)
    #expect(pager.headerHostSuperviewForTesting === pager.fixedHeaderContainerForTesting)
}

@MainActor
@Test func activeContainerRefreshHostPanDoesNotResetWhenOffsetTouchesBaseline() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .container
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    let host = try #require(
        pager.containerRefreshHostScrollViewForTesting as? CollapsiblePagerContainerRefreshHostScrollView
    )
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.setContentOffset(CGPoint(x: 0, y: -308), animated: false)
    pager.view.layoutIfNeeded()

    host.setContentOffset(CGPoint(x: 0, y: host.neutralBaselineContentOffsetY - 1), animated: false)
    #expect(host.contentOffset.y == host.neutralBaselineContentOffsetY - 1)
    host.scrollViewDidScroll(host)
    #expect(pager.activeRefreshHandoffForTesting == .containerHost(index: 0))

    host.setContentOffset(CGPoint(x: 0, y: host.neutralBaselineContentOffsetY), animated: false)
    #expect(host.contentOffset.y == host.neutralBaselineContentOffsetY)
    host.scrollViewDidScroll(host)
    #expect(pager.activeRefreshHandoffForTesting == .containerHost(index: 0))

    host.scrollViewDidEndDragging(host, willDecelerate: false)
    #expect(pager.activeRefreshHandoffForTesting == nil)
}

@MainActor
@Test func proxiedContainerRefreshOverscrollSurvivesIdleHostBaselineCorrection() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .container
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = TrackingDataSource()
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(dataSource.child(at: 0)?.trackingScrollView)
    let host = try #require(
        pager.containerRefreshHostScrollViewForTesting as? CollapsiblePagerContainerRefreshHostScrollView
    )
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.simulatedTracking = true
    scrollView.simulatedDragging = true

    scrollView.setContentOffset(CGPoint(x: 0, y: -305), animated: false)
    pager.view.layoutIfNeeded()
    #expect(pager.collapseProgressForTesting > 0)

    scrollView.setContentOffset(CGPoint(x: 0, y: -330), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.activeRefreshHandoffForTesting == .containerHost(index: 0))
    #expect(scrollView.contentOffset.y == -308)
    #expect(host.contentOffset.y == -22)

    host.setContentOffset(CGPoint(x: 0, y: 0), animated: false)

    #expect(host.contentOffset.y == -22)
    #expect(pager.headerFrameForTesting.minY == 22)
    #expect(pager.tabBarFrameForTesting.minY == pager.headerFrameForTesting.maxY)
}

@MainActor
@Test func proxiedContainerRefreshOverscrollCancelsWhenChildLeavesExpandedTop() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .container
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = TrackingDataSource()
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(dataSource.child(at: 0)?.trackingScrollView)
    let host = try #require(
        pager.containerRefreshHostScrollViewForTesting as? CollapsiblePagerContainerRefreshHostScrollView
    )
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.simulatedTracking = true
    scrollView.simulatedDragging = true

    scrollView.setContentOffset(CGPoint(x: 0, y: -330), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.activeRefreshHandoffForTesting == .containerHost(index: 0))
    #expect(host.contentOffset.y == -22)

    scrollView.setContentOffset(CGPoint(x: 0, y: -303), animated: false)
    pager.view.layoutIfNeeded()

    let mountView = try #require(pager.headerMountViewForTesting(at: 0))
    #expect(pager.collapseProgressForTesting > 0)
    #expect(pager.activeRefreshHandoffForTesting == nil)
    #expect(host.contentOffset.y == 0)
    #expect(pager.headerHostSuperviewForTesting === mountView)
}

@MainActor
@Test func rejectedContainerHostPanDoesNotStartProxyDuringSameChildGesture() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .container
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = TrackingDataSource()
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(dataSource.child(at: 0)?.trackingScrollView)
    let host = try #require(
        pager.containerRefreshHostScrollViewForTesting as? CollapsiblePagerContainerRefreshHostScrollView
    )
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.simulatedTracking = true
    scrollView.simulatedDragging = true

    #expect(
        pager.shouldBeginContainerRefreshHostPanForTesting(
            translation: CGSize(width: 0, height: -2),
            velocity: CGSize(width: 0, height: -320)
        ) == false
    )

    scrollView.setContentOffset(CGPoint(x: 0, y: -330), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.activeRefreshHandoffForTesting == nil)
    #expect(try containerRefreshProxyOverscrollOffsetY(in: pager) == 0)
    #expect(host.contentOffset.y == host.neutralBaselineContentOffsetY)
    #expect(scrollView.contentOffset.y == -308)
}

@MainActor
@Test func idleChildOverscrollDoesNotStartContainerProxyHandoff() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .container
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = TrackingDataSource()
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(dataSource.child(at: 0)?.trackingScrollView)
    let host = try #require(
        pager.containerRefreshHostScrollViewForTesting as? CollapsiblePagerContainerRefreshHostScrollView
    )
    scrollView.contentSize = CGSize(width: 390, height: 2000)

    scrollView.setContentOffset(CGPoint(x: 0, y: -330), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.activeRefreshHandoffForTesting == nil)
    #expect(try containerRefreshProxyOverscrollOffsetY(in: pager) == 0)
    #expect(host.contentOffset.y == host.neutralBaselineContentOffsetY)
    #expect(scrollView.contentOffset.y == -308)
}

@MainActor
@Test func proxiedContainerRefreshOverscrollUpdatesProxyWhileTrackedChildOverscrollChanges() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .container
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = TrackingDataSource()
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(dataSource.child(at: 0)?.trackingScrollView)
    let host = pager.containerRefreshHostScrollViewForTesting
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.simulatedTracking = true
    scrollView.simulatedDragging = true

    scrollView.setContentOffset(CGPoint(x: 0, y: -330), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.activeRefreshHandoffForTesting == .containerHost(index: 0))
    #expect(host.contentOffset.y == -22)

    scrollView.setContentOffset(CGPoint(x: 0, y: -309), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.collapseProgressForTesting == 0)
    #expect(pager.activeRefreshHandoffForTesting == .containerHost(index: 0))
    #expect(host.contentOffset.y == -1)
    #expect(try containerRefreshProxyOverscrollOffsetY(in: pager) == -1)
    #expect(pager.headerHostSuperviewForTesting === pager.fixedHeaderContainerForTesting)
}

@MainActor
@Test func proxiedContainerRefreshOverscrollFinishesWhenTrackedChildPanEndsIdle() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .container
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = TrackingDataSource()
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(dataSource.child(at: 0)?.trackingScrollView)
    let host = try #require(
        pager.containerRefreshHostScrollViewForTesting as? CollapsiblePagerContainerRefreshHostScrollView
    )
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.simulatedTracking = true
    scrollView.simulatedDragging = true

    scrollView.setContentOffset(CGPoint(x: 0, y: -330), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.activeRefreshHandoffForTesting == .containerHost(index: 0))
    #expect(try containerRefreshProxyOverscrollOffsetY(in: pager) == -22)
    #expect(host.contentOffset.y == -22)

    scrollView.simulatedTracking = false
    scrollView.simulatedDragging = false
    pager.finishProxiedContainerRefreshHandoffForTesting(at: 0)

    #expect(pager.activeRefreshHandoffForTesting == nil)
    #expect(try containerRefreshProxyOverscrollOffsetY(in: pager) == 0)
    #expect(host.contentOffset.y == host.neutralBaselineContentOffsetY)
}

@MainActor
@Test func proxiedContainerRefreshOverscrollReleasesProxyWhenExternalInsetTakesOwnership() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .container
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = TrackingDataSource()
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(dataSource.child(at: 0)?.trackingScrollView)
    let host = try #require(
        pager.containerRefreshHostScrollViewForTesting as? CollapsiblePagerContainerRefreshHostScrollView
    )
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.simulatedTracking = true
    scrollView.simulatedDragging = true

    scrollView.setContentOffset(CGPoint(x: 0, y: -330), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.activeRefreshHandoffForTesting == .containerHost(index: 0))
    #expect(try containerRefreshProxyOverscrollOffsetY(in: pager) == -22)

    var externalInset = host.contentInset
    externalInset.top += 60
    host.contentInset = externalInset
    host.scrollViewDidScroll(host)

    #expect(pager.activeRefreshHandoffForTesting == .containerHost(index: 0))
    #expect(try containerRefreshProxyOverscrollOffsetY(in: pager) == 0)
}

@MainActor
@Test func activeContainerRefreshHostPanContinuesWhenInitialMotionIsZero() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .container
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = TrackingDataSource()
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(dataSource.child(at: 0)?.trackingScrollView)
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.simulatedTracking = true
    scrollView.simulatedDragging = true

    scrollView.setContentOffset(CGPoint(x: 0, y: -330), animated: false)
    pager.view.layoutIfNeeded()
    scrollView.setContentOffset(CGPoint(x: 0, y: -309), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.activeRefreshHandoffForTesting == .containerHost(index: 0))
    #expect(try containerRefreshProxyOverscrollOffsetY(in: pager) == -1)
    #expect(
        pager.shouldBeginContainerRefreshHostPanForTesting(
            translation: .zero,
            velocity: .zero
        )
    )
}

@MainActor
@Test func containerRefreshHostPanTakesOwnershipFromProxyOverscroll() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .container
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = TrackingDataSource()
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(dataSource.child(at: 0)?.trackingScrollView)
    let host = try #require(
        pager.containerRefreshHostScrollViewForTesting as? CollapsiblePagerContainerRefreshHostScrollView
    )
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.simulatedTracking = true
    scrollView.simulatedDragging = true

    scrollView.setContentOffset(CGPoint(x: 0, y: -330), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.activeRefreshHandoffForTesting == .containerHost(index: 0))
    #expect(try containerRefreshProxyOverscrollOffsetY(in: pager) == -22)
    #expect(host.gestureRecognizerShouldBegin(host.panGestureRecognizer))

    #expect(try containerRefreshProxyOverscrollOffsetY(in: pager) == 0)
    host.setContentOffset(CGPoint(x: 0, y: host.neutralBaselineContentOffsetY - 40), animated: false)
    host.scrollViewDidScroll(host)
    #expect(host.contentOffset.y == host.neutralBaselineContentOffsetY - 40)
}

@MainActor
@Test func containerRefreshHostUsesNeutralOuterScrollBaselineForVisibleRefreshReveal() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .container
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    let host = pager.containerRefreshHostScrollViewForTesting

    #expect(scrollView.contentInset.top == 308)
    #expect(host.contentInset.top == 0)
    #expect(host.contentOffset.y == 0)
    #expect(host.frame == pager.view.bounds)
    #expect(pager.pinnedSurfaceSuperviewForTesting === host)
}

@MainActor
@Test func containerRefreshHostBaselineStartsBelowNavigationChrome() throws {
    let dataSource = DemoDataSource(pageCount: 1)
    let pager = CollapsiblePagerViewController()
    pager.dataSource = dataSource

    let navigationController = UINavigationController(rootViewController: pager)
    navigationController.navigationBar.prefersLargeTitles = false
    navigationController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = navigationController
    window.makeKeyAndVisible()
    defer { window.isHidden = true }

    pager.reloadData()
    navigationController.view.layoutIfNeeded()
    pager.view.layoutIfNeeded()

    let host = try #require(
        pager.containerRefreshHostScrollViewForTesting as? CollapsiblePagerContainerRefreshHostScrollView
    )
    let refreshBaselineTop = navigationController.navigationBar.convert(
        navigationController.navigationBar.bounds,
        to: pager.view
    ).maxY

    #expect(refreshBaselineTop > 0)
    #expect(host.frame == pager.view.bounds)
    #expect(host.contentInset.top == refreshBaselineTop)
    #expect(host.contentOffset.y == -refreshBaselineTop)
    #expect(host.contentSize.height - host.bounds.height + host.contentInset.bottom == host.neutralBaselineContentOffsetY)
    #expect(pager.headerFrameForTesting.minY == refreshBaselineTop)
    #expect(pager.tabBarFrameForTesting.minY == pager.headerFrameForTesting.maxY)
}

@MainActor
@Test func activeContainerRefreshHostClampsAboveNeutralBaseline() throws {
    let dataSource = DemoDataSource(pageCount: 1)
    let pager = CollapsiblePagerViewController()
    pager.dataSource = dataSource

    let navigationController = UINavigationController(rootViewController: pager)
    navigationController.navigationBar.prefersLargeTitles = false
    navigationController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = navigationController
    window.makeKeyAndVisible()
    defer { window.isHidden = true }

    pager.reloadData()
    navigationController.view.layoutIfNeeded()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    let host = try #require(
        pager.containerRefreshHostScrollViewForTesting as? CollapsiblePagerContainerRefreshHostScrollView
    )
    let expectedHeaderFrame = pager.headerFrameForTesting
    let expectedTabBarFrame = pager.tabBarFrameForTesting
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.setContentOffset(CGPoint(x: 0, y: -308), animated: false)
    pager.view.layoutIfNeeded()

    host.setContentOffset(CGPoint(x: 0, y: host.neutralBaselineContentOffsetY - 12), animated: false)
    host.scrollViewDidScroll(host)
    #expect(pager.activeRefreshHandoffForTesting == .containerHost(index: 0))

    host.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
    host.scrollViewDidScroll(host)

    #expect(host.contentOffset.y == host.neutralBaselineContentOffsetY)
    #expect(pager.activeRefreshHandoffForTesting == .containerHost(index: 0))
    #expect(pager.headerFrameForTesting == expectedHeaderFrame)
    #expect(pager.tabBarFrameForTesting == expectedTabBarFrame)

    host.scrollViewDidEndDragging(host, willDecelerate: false)
    #expect(pager.activeRefreshHandoffForTesting == nil)
    #expect(host.contentOffset.y == host.neutralBaselineContentOffsetY)
}

@MainActor
@Test func containerRefreshHostPanRequiresContainerModeExpandedHeaderAndTopChild() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .container
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    scrollView.contentSize = CGSize(width: 390, height: 2000)

    #expect(
        pager.shouldBeginContainerRefreshHostPanForTesting(
            translation: CGSize(width: 0, height: 40),
            velocity: CGSize(width: 0, height: 120)
        )
    )
    #expect(
        pager.shouldBeginContainerRefreshHostPanForTesting(
            translation: .zero,
            velocity: CGSize(width: 0, height: 160)
        )
    )

    scrollView.setContentOffset(CGPoint(x: 0, y: -120), animated: false)
    pager.view.layoutIfNeeded()

    #expect(
        pager.shouldBeginContainerRefreshHostPanForTesting(
            translation: CGSize(width: 0, height: 40),
            velocity: CGSize(width: 0, height: 120)
        ) == false
    )
}

@MainActor
@Test func containerRefreshHostPanHasPriorityOverLoadedChildPan() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .container
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    #expect(pager.containerRefreshHostPanHasPriorityOverChildPanForTesting(at: 0))
}

@MainActor
@Test func headerPullDownRefreshGateDefaultsToAllowingChildRefresh() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .child
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    #expect(pager.headerPullDownGateHasPriorityOverChildPanForTesting(at: 0))
    #expect(
        pager.shouldBeginHeaderPullDownGateForTesting(
            translation: CGSize(width: 0, height: 40),
            velocity: CGSize(width: 0, height: 120)
        ) == false
    )
}

@MainActor
@Test func headerPullDownRefreshGateSuppressesChildRefreshWhenConfigured() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .child
    configuration.headerPullDownRefreshBehavior = .suppressesChildRefresh
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    #expect(pager.headerPullDownGateHasPriorityOverChildPanForTesting(at: 0))
    #expect(
        pager.shouldBeginHeaderPullDownGateForTesting(
            translation: CGSize(width: 0, height: 40),
            velocity: CGSize(width: 0, height: 120)
        )
    )
    #expect(
        pager.shouldBeginHeaderPullDownGateForTesting(
            translation: .zero,
            velocity: CGSize(width: 0, height: 160)
        )
    )
}

@MainActor
@Test func activeRefreshHandoffBlocksHorizontalPaging() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .child
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = DemoDataSource(pageCount: 2)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.setContentOffset(CGPoint(x: 0, y: -330), animated: false)
    pager.view.layoutIfNeeded()

    let allowed = pager.shouldBeginHorizontalPagingForTesting(
        translation: CGSize(width: -80, height: 4),
        location: CGPoint(x: 120, y: pager.tabBarFrameForTesting.maxY + 80)
    )

    #expect(allowed == false)
}

@MainActor
@Test func shortPageCanScrollEnoughToCollapseAfterSelection() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 3)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()
    pager.selectPage(at: 1, animated: false)
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 1))
    scrollView.contentSize = CGSize(width: 390, height: 80)
    pager.view.layoutIfNeeded()

    let pinnedOffsetY = -48.0
    let maxScrollableOffsetY = scrollView.contentSize.height + scrollView.contentInset.bottom - scrollView.bounds.height
    #expect(maxScrollableOffsetY >= pinnedOffsetY)
}

@MainActor
private final class DemoDataSource: CollapsiblePagerViewControllerDataSource {
    var pageCount: Int
    private(set) var headerRequestCount = 0

    init(pageCount: Int) {
        self.pageCount = pageCount
    }

    func numberOfPages(in pagerViewController: CollapsiblePagerViewController) -> Int {
        pageCount
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, titleForPageAt index: Int) -> String {
        "Page \(index)"
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, viewControllerForPageAt index: Int) -> UIViewController {
        DemoChildViewController()
    }

    func headerContent(in pagerViewController: CollapsiblePagerViewController) -> CollapsiblePagerHeaderContent {
        headerRequestCount += 1
        return .view(UIView())
    }
}

@MainActor
private final class DemoChildViewController: UIViewController, CollapsiblePagerScrollProviding {
    let scrollView = UIScrollView()
    var pagerScrollView: UIScrollView { scrollView }

    override func loadView() {
        view = scrollView
    }
}

@MainActor
private final class TrackingDataSource: CollapsiblePagerViewControllerDataSource {
    private let children = [TrackingChildViewController()]

    func child(at index: Int) -> TrackingChildViewController? {
        guard children.indices.contains(index) else {
            return nil
        }
        return children[index]
    }

    func numberOfPages(in pagerViewController: CollapsiblePagerViewController) -> Int {
        children.count
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, titleForPageAt index: Int) -> String {
        "Page \(index)"
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, viewControllerForPageAt index: Int) -> UIViewController {
        children[index]
    }

    func headerContent(in pagerViewController: CollapsiblePagerViewController) -> CollapsiblePagerHeaderContent {
        .view(UIView())
    }
}

@MainActor
private final class TrackingChildViewController: UIViewController, CollapsiblePagerScrollProviding {
    let trackingScrollView = TrackingScrollView()
    var pagerScrollView: UIScrollView { trackingScrollView }

    override func loadView() {
        view = trackingScrollView
    }
}

private final class TrackingScrollView: UIScrollView {
    var simulatedTracking = false
    var simulatedDragging = false

    override var isTracking: Bool {
        simulatedTracking
    }

    override var isDragging: Bool {
        simulatedDragging
    }
}

@MainActor
private func containerRefreshProxyOverscrollOffsetY(
    in pager: CollapsiblePagerViewController
) throws -> CGFloat {
    let value = Mirror(reflecting: pager).children.first {
        $0.label == "containerRefreshProxyOverscrollOffsetY"
    }?.value as? CGFloat
    return try #require(value)
}

@MainActor
private final class SelectionRecorder: CollapsiblePagerViewControllerDelegate {
    private(set) var selectedIndexes: [Int] = []

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, didSelectPageAt index: Int) {
        selectedIndexes.append(index)
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, didUpdateCollapseProgress progress: CGFloat) {
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, didUpdateLayout context: CollapsiblePagerLayoutContext) {
    }
}

@MainActor
private final class LifecycleDataSource: CollapsiblePagerViewControllerDataSource {
    private let children: [LifecycleChildViewController]

    init(pageCount: Int) {
        children = (0..<pageCount).map { _ in LifecycleChildViewController() }
    }

    func child(at index: Int) -> LifecycleChildViewController? {
        guard children.indices.contains(index) else {
            return nil
        }
        return children[index]
    }

    func numberOfPages(in pagerViewController: CollapsiblePagerViewController) -> Int {
        children.count
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, titleForPageAt index: Int) -> String {
        "Page \(index)"
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, viewControllerForPageAt index: Int) -> UIViewController {
        children[index]
    }

    func headerContent(in pagerViewController: CollapsiblePagerViewController) -> CollapsiblePagerHeaderContent {
        .view(UIView())
    }
}

@MainActor
private final class LifecycleChildViewController: UIViewController, CollapsiblePagerScrollProviding {
    let scrollView = UIScrollView()
    private(set) var events: [String] = []
    private(set) var animatedEvents: [String] = []

    var pagerScrollView: UIScrollView { scrollView }

    override func loadView() {
        view = scrollView
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        events.append("willAppear")
        animatedEvents.append("willAppear:\(animated)")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        events.append("didAppear")
        animatedEvents.append("didAppear:\(animated)")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        events.append("willDisappear")
        animatedEvents.append("willDisappear:\(animated)")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        events.append("didDisappear")
        animatedEvents.append("didDisappear:\(animated)")
    }
}
