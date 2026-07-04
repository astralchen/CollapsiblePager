import CoreGraphics

struct CollapsiblePagerLayoutEngine: Sendable {
    func layout(_ input: CollapsiblePagerLayoutInput) -> CollapsiblePagerLayoutOutput {
        let bounds = input.containerBounds
        let headerHeights = input.headerHeights.normalized
        let pinThreshold = headerHeights.collapseRange
        let clampedPinAnchorY = input.pinAnchorY.clamped(to: 0...pinThreshold)
        let headerVisibleHeight = headerHeights.maxHeight - clampedPinAnchorY
        let collapseProgress = pinThreshold == 0 ? 1 : clampedPinAnchorY / pinThreshold
        let pinY = Self.pinY(safeAreaInsets: input.safeAreaInsets, navigationBarMaxY: input.navigationBarMaxY, pinning: input.tabBarPinning)
        let contentTopY = max(bounds.minY, pinY)
        let tabBarY = Self.tabBarY(
            placement: input.tabBarPlacement,
            headerVisibleHeight: headerVisibleHeight,
            contentTopY: contentTopY,
            pinY: pinY
        )
        let tabBarHeight = max(0, input.tabBarHeight)
        let tabBarFrame = CGRect(x: bounds.minX, y: tabBarY, width: bounds.width, height: tabBarHeight)
        let headerTopY = Self.headerTopY(
            bounds: bounds,
            contentTopY: contentTopY,
            behavior: input.headerTopBehavior
        )
        let headerFrame = CGRect(
            x: bounds.minX,
            y: headerTopY,
            width: bounds.width,
            height: max(0, tabBarFrame.minY - headerTopY)
        )
        let managedTopInset = headerHeights.maxHeight + tabBarHeight

        return CollapsiblePagerLayoutOutput(
            pageContainerFrame: CGRect(
                x: bounds.minX,
                y: contentTopY,
                width: bounds.width,
                height: max(0, bounds.maxY - contentTopY)
            ),
            headerFrame: headerFrame,
            headerVisibleHeight: headerVisibleHeight,
            collapseProgress: collapseProgress,
            tabBarFrame: tabBarFrame,
            childContentInset: CollapsiblePagerEdgeInsets(top: managedTopInset, bottom: input.safeAreaInsets.bottom),
            pinThreshold: pinThreshold
        )
    }

    func headerOffsetTransition(
        from previousHeights: CollapsiblePagerHeaderHeights,
        to nextHeights: CollapsiblePagerHeaderHeights,
        currentPinAnchorY: CGFloat,
        policy: CollapsiblePagerHeaderOffsetPolicy
    ) -> CollapsiblePagerHeaderOffsetTransition {
        let previous = previousHeights.normalized
        let next = nextHeights.normalized
        let previousRange = previous.collapseRange
        let nextRange = next.collapseRange
        let currentPin = currentPinAnchorY.clamped(to: 0...previousRange)
        let nextPin: CGFloat
        let correction: CGFloat

        switch policy {
        case .preserveVisualPosition:
            nextPin = currentPin.clamped(to: 0...nextRange)
            correction = next.maxHeight - previous.maxHeight
        case .preserveCollapseProgress:
            let progress = previousRange == 0 ? 1 : currentPin / previousRange
            nextPin = (progress * nextRange).clamped(to: 0...nextRange)
            correction = nextPin - currentPin
        case .resetToExpanded:
            nextPin = 0
            correction = -currentPin
        case .resetToCollapsed:
            nextPin = nextRange
            correction = nextPin - currentPin
        }

        return CollapsiblePagerHeaderOffsetTransition(
            nextPinAnchorY: nextPin,
            contentOffsetCorrectionY: correction
        )
    }

    private static func pinY(
        safeAreaInsets: CollapsiblePagerEdgeInsets,
        navigationBarMaxY: CGFloat?,
        pinning: CollapsiblePagerTabBarPinning
    ) -> CGFloat {
        switch pinning {
        case let .pinBelowNavigationBar(offset):
            return max(navigationBarMaxY ?? safeAreaInsets.top, safeAreaInsets.top) + offset
        }
    }

    private static func headerTopY(
        bounds: CGRect,
        contentTopY: CGFloat,
        behavior: CollapsiblePagerHeaderTopBehavior
    ) -> CGFloat {
        switch behavior {
        case .insideSafeArea:
            return contentTopY
        case .extendsUnderTopSafeArea:
            return bounds.minY
        }
    }

    private static func tabBarY(
        placement: CollapsiblePagerTabBarPlacement,
        headerVisibleHeight: CGFloat,
        contentTopY: CGFloat,
        pinY: CGFloat
    ) -> CGFloat {
        switch placement {
        case .belowHeader:
            return max(contentTopY + headerVisibleHeight, pinY)
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
