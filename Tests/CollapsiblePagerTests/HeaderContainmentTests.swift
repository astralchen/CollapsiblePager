import Testing
import UIKit
@testable import CollapsiblePager

@MainActor
@Test func headerViewControllerContainmentSurvivesHostMigration() {
    let pager = CollapsiblePagerViewController()
    pager.loadViewIfNeeded()
    let coordinator = CollapsiblePagerHeaderHostCoordinator(owner: pager)
    let header = UIViewController()
    let mount = CollapsiblePagerHeaderMountView()
    let fixed = CollapsiblePagerFixedHeaderContainer()

    coordinator.setContent(.viewController(header), initialContainer: mount)
    #expect(header.parent === pager)

    coordinator.moveHost(to: fixed, reason: .horizontalPaging)
    #expect(header.parent === pager)

    coordinator.moveHost(to: mount, reason: .currentChild)
    #expect(header.parent === pager)
}

@MainActor
@Test func replacingHeaderViewControllerRemovesOldContainment() {
    let pager = CollapsiblePagerViewController()
    pager.loadViewIfNeeded()
    let coordinator = CollapsiblePagerHeaderHostCoordinator(owner: pager)
    let oldHeader = UIViewController()
    let newHeader = UIViewController()
    let mount = CollapsiblePagerHeaderMountView()

    coordinator.setContent(.viewController(oldHeader), initialContainer: mount)
    coordinator.setContent(.viewController(newHeader), initialContainer: mount)

    #expect(oldHeader.parent == nil)
    #expect(oldHeader.view.superview == nil)
    #expect(newHeader.parent === pager)
}

@MainActor
@Test func headerViewControllerReceivesPagerAppearanceLifecycle() {
    let header = LifecycleHeaderViewController()
    let dataSource = HeaderLifecycleDataSource(header: header)
    let pager = CollapsiblePagerViewController()
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.beginAppearanceTransition(true, animated: false)
    pager.endAppearanceTransition()

    #expect(header.animatedEvents == ["willAppear:false", "didAppear:false"])

    pager.beginAppearanceTransition(false, animated: true)
    pager.endAppearanceTransition()

    #expect(header.animatedEvents == [
        "willAppear:false",
        "didAppear:false",
        "willDisappear:true",
        "didDisappear:true",
    ])
}

@MainActor
@Test func visiblePagerReplacesHeaderViewControllerWithAppearanceLifecycle() {
    let oldHeader = LifecycleHeaderViewController()
    let newHeader = LifecycleHeaderViewController()
    let dataSource = HeaderLifecycleDataSource(header: oldHeader)
    let pager = CollapsiblePagerViewController()
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.beginAppearanceTransition(true, animated: false)
    pager.endAppearanceTransition()

    dataSource.header = newHeader
    pager.reloadData()

    #expect(oldHeader.animatedEvents == [
        "willAppear:false",
        "didAppear:false",
        "willDisappear:false",
        "didDisappear:false",
    ])
    #expect(newHeader.animatedEvents == ["willAppear:false", "didAppear:false"])
    #expect(oldHeader.parent == nil)
    #expect(newHeader.parent === pager)
}

@MainActor
@Test func fixedHeaderContainerPassesThroughEmptyHits() {
    let fixed = CollapsiblePagerFixedHeaderContainer(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let child = UIView(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
    fixed.addSubview(child)

    #expect(fixed.hitTest(CGPoint(x: 1, y: 1), with: nil) == nil)
    #expect(fixed.hitTest(CGPoint(x: 15, y: 15), with: nil) === child)
}

@MainActor
private final class HeaderLifecycleDataSource: CollapsiblePagerViewControllerDataSource {
    var header: UIViewController

    init(header: UIViewController) {
        self.header = header
    }

    func numberOfPages(in pagerViewController: CollapsiblePagerViewController) -> Int {
        1
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, titleForPageAt index: Int) -> String {
        "Page"
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, viewControllerForPageAt index: Int) -> UIViewController {
        HeaderLifecycleChildViewController()
    }

    func headerContent(in pagerViewController: CollapsiblePagerViewController) -> CollapsiblePagerHeaderContent {
        .viewController(header)
    }
}

@MainActor
private final class HeaderLifecycleChildViewController: UIViewController, CollapsiblePagerScrollProviding {
    let scrollView = UIScrollView()

    var pagerScrollView: UIScrollView {
        scrollView
    }

    override func loadView() {
        view = scrollView
    }
}

@MainActor
private final class LifecycleHeaderViewController: UIViewController {
    private(set) var animatedEvents: [String] = []

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        animatedEvents.append("willAppear:\(animated)")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animatedEvents.append("didAppear:\(animated)")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        animatedEvents.append("willDisappear:\(animated)")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        animatedEvents.append("didDisappear:\(animated)")
    }
}
