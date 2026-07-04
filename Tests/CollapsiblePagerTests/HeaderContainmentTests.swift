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
@Test func fixedHeaderContainerPassesThroughEmptyHits() {
    let fixed = CollapsiblePagerFixedHeaderContainer(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let child = UIView(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
    fixed.addSubview(child)

    #expect(fixed.hitTest(CGPoint(x: 1, y: 1), with: nil) == nil)
    #expect(fixed.hitTest(CGPoint(x: 15, y: 15), with: nil) === child)
}
