import CoreGraphics
import Testing
@testable import CollapsiblePager

@Test func systemBackGestureWinsOnFirstPageLeadingSwipe() {
    let arbiter = GestureArbiter()
    let input = GestureArbiterInput(
        translation: CGSize(width: 48, height: 4),
        isOnFirstPage: true,
        startsAtLeadingEdge: true,
        isInHeader: true
    )

    #expect(arbiter.gesturePriority(for: input) == .systemBack)
}

@Test func headerHorizontalGestureDoesNotStartPaging() {
    let arbiter = GestureArbiter()
    let input = GestureArbiterInput(
        translation: CGSize(width: -60, height: 3),
        isOnFirstPage: false,
        startsAtLeadingEdge: false,
        isInHeader: true
    )

    #expect(arbiter.gesturePriority(for: input) == .ignored)
}

@Test func horizontalIntentOutsideHeaderStartsPaging() {
    let arbiter = GestureArbiter()
    let input = GestureArbiterInput(
        translation: CGSize(width: -60, height: 8),
        isOnFirstPage: false,
        startsAtLeadingEdge: false,
        isInHeader: false
    )

    #expect(arbiter.gesturePriority(for: input) == .horizontalPaging)
}

@Test func verticalIntentKeepsVerticalScrollingPriority() {
    let arbiter = GestureArbiter()
    let input = GestureArbiterInput(
        translation: CGSize(width: 8, height: 60),
        isOnFirstPage: false,
        startsAtLeadingEdge: false,
        isInHeader: false
    )

    #expect(arbiter.gesturePriority(for: input) == .verticalScrolling)
}

@Test func refreshAnimationBlocksHorizontalPaging() {
    let arbiter = GestureArbiter()
    let input = GestureArbiterInput(
        translation: CGSize(width: -60, height: 2),
        isOnFirstPage: false,
        startsAtLeadingEdge: false,
        isInHeader: false,
        isRefreshAnimationActive: true
    )

    #expect(arbiter.gesturePriority(for: input) == .ignored)
}
