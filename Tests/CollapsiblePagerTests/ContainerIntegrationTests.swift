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
