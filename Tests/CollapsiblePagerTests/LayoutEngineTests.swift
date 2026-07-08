import CoreGraphics
import Testing
@testable import CollapsiblePager

@Test func expandedLayoutUsesManagedTopInset() {
    let input = CollapsiblePagerLayoutInput(
        containerBounds: CGRect(x: 0, y: 0, width: 390, height: 844),
        safeAreaInsets: .init(top: 47, left: 0, bottom: 34, right: 0),
        navigationBarMaxY: 91,
        headerHeights: .init(maxHeight: 260, minHeight: 0),
        tabBarHeight: 48,
        tabBarPlacement: .belowHeader,
        tabBarPinning: .pinBelowNavigationBar(offset: 0),
        pinAnchorY: 0
    )

    let output = CollapsiblePagerLayoutEngine().layout(input)

    #expect(output.pageContainerFrame == CGRect(x: 0, y: 91, width: 390, height: 753))
    #expect(output.headerFrame == CGRect(x: 0, y: 91, width: 390, height: 260))
    #expect(output.headerVisibleHeight == 260)
    #expect(output.collapseProgress == 0)
    #expect(output.childContentInset.top == 308)
    #expect(output.tabBarFrame.minY == 351)
}

@Test func layoutUsesBottomObstructionWhenItExceedsSafeArea() {
    var input = CollapsiblePagerLayoutInput.defaultTestValue
    input.safeAreaInsets.bottom = 34
    input.bottomObstructionInset = 88

    let output = CollapsiblePagerLayoutEngine().layout(input)

    #expect(output.childContentInset.bottom == 88)
}

@Test func pinnedLayoutKeepsTabBarAtPinY() {
    var input = CollapsiblePagerLayoutInput.defaultTestValue
    input.pinAnchorY = 260

    let output = CollapsiblePagerLayoutEngine().layout(input)

    #expect(output.headerVisibleHeight == 0)
    #expect(output.collapseProgress == 1)
    #expect(output.tabBarFrame.minY == 91)
}

@Test func headerCanExtendUnderTopSafeAreaWithoutMovingTabBarOrRows() {
    var input = CollapsiblePagerLayoutInput.defaultTestValue
    input.headerTopBehavior = .extendsUnderTopSafeArea

    let output = CollapsiblePagerLayoutEngine().layout(input)

    #expect(output.pageContainerFrame == CGRect(x: 0, y: 91, width: 390, height: 753))
    #expect(output.headerFrame == CGRect(x: 0, y: 0, width: 390, height: 351))
    #expect(output.tabBarFrame == CGRect(x: 0, y: 351, width: 390, height: 48))
    #expect(output.childContentInset.top == 308)
}

@Test func headerHeightTransitionPreservesVisualPosition() {
    let transition = CollapsiblePagerLayoutEngine().headerOffsetTransition(
        from: .init(maxHeight: 260, minHeight: 0),
        to: .init(maxHeight: 300, minHeight: 0),
        currentPinAnchorY: 120,
        policy: .preserveVisualPosition
    )

    #expect(transition.nextPinAnchorY == 120)
    #expect(transition.contentOffsetCorrectionY == -40)
}

@Test func headerHeightTransitionPreservesCollapseProgress() {
    let transition = CollapsiblePagerLayoutEngine().headerOffsetTransition(
        from: .init(maxHeight: 260, minHeight: 60),
        to: .init(maxHeight: 360, minHeight: 60),
        currentPinAnchorY: 50,
        policy: .preserveCollapseProgress
    )

    #expect(transition.nextPinAnchorY == 75)
    #expect(transition.contentOffsetCorrectionY == -75)
}

@Test func headerHeightTransitionCanResetToExpandedOrCollapsed() {
    let expanded = CollapsiblePagerLayoutEngine().headerOffsetTransition(
        from: .init(maxHeight: 260, minHeight: 0),
        to: .init(maxHeight: 360, minHeight: 60),
        currentPinAnchorY: 80,
        policy: .resetToExpanded
    )
    let collapsed = CollapsiblePagerLayoutEngine().headerOffsetTransition(
        from: .init(maxHeight: 260, minHeight: 0),
        to: .init(maxHeight: 360, minHeight: 60),
        currentPinAnchorY: 80,
        policy: .resetToCollapsed
    )

    #expect(expanded.nextPinAnchorY == 0)
    #expect(expanded.contentOffsetCorrectionY == -180)
    #expect(collapsed.nextPinAnchorY == 300)
    #expect(collapsed.contentOffsetCorrectionY == 120)
}
