import CoreGraphics

struct CollapsiblePagerState: Sendable, Equatable {
    var selectedIndex: Int
    var effectiveSelectedIndex: Int?
    var pendingSelectedIndex: Int?
    var pageCount: Int
    var pagePosition: PagePosition?
    var pinAnchorY: CGFloat

    static func initial(pageCount: Int) -> CollapsiblePagerState {
        let clampedPageCount = max(0, pageCount)
        return CollapsiblePagerState(
            selectedIndex: 0,
            effectiveSelectedIndex: clampedPageCount == 0 ? nil : 0,
            pendingSelectedIndex: nil,
            pageCount: clampedPageCount,
            pagePosition: PagePosition.make(rawPosition: 0, pageCount: clampedPageCount, isInteractive: false),
            pinAnchorY: 0
        )
    }
}
