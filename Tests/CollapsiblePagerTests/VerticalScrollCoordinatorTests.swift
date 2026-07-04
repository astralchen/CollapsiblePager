import Testing
import UIKit
@testable import CollapsiblePager

@Test func topBounceDoesNotPropagatePinDelta() {
    var model = VerticalScrollModel(pinAnchorY: 0, pinThreshold: 260, managedTopInset: 308)

    let result = model.handleCurrentOffsetY(-340)

    #expect(result.pinDeltaY == 0)
    #expect(result.shouldSyncNonCurrentChildren == false)
}

@Test func fullyPinnedOverscrollDoesNotPropagatePinDelta() {
    var model = VerticalScrollModel(pinAnchorY: 260, pinThreshold: 260, managedTopInset: 308)

    let result = model.handleCurrentOffsetY(20)

    #expect(result.pinAnchorY == 260)
    #expect(result.pinDeltaY == 0)
    #expect(result.shouldSyncNonCurrentChildren == false)
}

@MainActor
@Test func verticalCoordinatorIgnoresNonCurrentAndHorizontalPagingEvents() {
    let current = makeRecord(index: 0, offsetY: -308)
    let other = makeRecord(index: 1, offsetY: -308)
    let coordinator = CollapsiblePagerVerticalScrollCoordinator(
        pinAnchorY: 0,
        pinThreshold: 260,
        managedTopInset: 308
    )
    coordinator.replaceRecords([current, other], currentIndex: 0)

    other.scrollView.contentOffset.y = -280
    #expect(coordinator.handleScrollViewDidScroll(other.scrollView) == nil)

    coordinator.isHorizontalPagingActive = true
    current.scrollView.contentOffset.y = -280
    #expect(coordinator.handleScrollViewDidScroll(current.scrollView) == nil)
}

@MainActor
@Test func verticalCoordinatorIgnoresEventsDuringGuardedOffsetUpdate() {
    let current = makeRecord(index: 0, offsetY: -308)
    let coordinator = CollapsiblePagerVerticalScrollCoordinator(
        pinAnchorY: 0,
        pinThreshold: 260,
        managedTopInset: 308
    )
    coordinator.replaceRecords([current], currentIndex: 0)

    var result: VerticalScrollModelResult?
    coordinator.performGuardedOffsetUpdate {
        current.scrollView.contentOffset.y = -280
        result = coordinator.handleScrollViewDidScroll(current.scrollView)
    }

    #expect(result == nil)
    #expect(coordinator.pinAnchorY == 0)
}

@MainActor
@Test func verticalCoordinatorSyncsNonCurrentChildrenByPinDeltaOnly() throws {
    let current = makeRecord(index: 0, offsetY: -308)
    let other = makeRecord(index: 1, offsetY: -308)
    let coordinator = CollapsiblePagerVerticalScrollCoordinator(
        pinAnchorY: 0,
        pinThreshold: 260,
        managedTopInset: 308
    )
    coordinator.replaceRecords([current, other], currentIndex: 0)

    current.scrollView.contentOffset.y = -288
    let firstResult = try #require(coordinator.handleScrollViewDidScroll(current.scrollView))

    #expect(firstResult.pinDeltaY == 20)
    #expect(other.scrollView.contentOffset.y == -288)

    current.scrollView.contentOffset.y = 0
    let secondResult = try #require(coordinator.handleScrollViewDidScroll(current.scrollView))

    #expect(secondResult.pinAnchorY == 260)
    #expect(secondResult.pinDeltaY == 240)
    #expect(other.scrollView.contentOffset.y == -48)
}

@MainActor
private func makeRecord(index: Int, offsetY: CGFloat) -> CollapsiblePagerChildRecord {
    let scrollView = UIScrollView()
    scrollView.contentOffset.y = offsetY
    return CollapsiblePagerChildRecord(
        index: index,
        viewController: UIViewController(),
        scrollView: scrollView,
        mountView: CollapsiblePagerHeaderMountView(),
        lastKnownContentOffsetY: offsetY
    )
}
