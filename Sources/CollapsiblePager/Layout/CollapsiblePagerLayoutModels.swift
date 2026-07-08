import CoreGraphics

struct CollapsiblePagerEdgeInsets: Sendable, Equatable {
    var top: CGFloat
    var left: CGFloat
    var bottom: CGFloat
    var right: CGFloat

    init(top: CGFloat = 0, left: CGFloat = 0, bottom: CGFloat = 0, right: CGFloat = 0) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
}

struct CollapsiblePagerHeaderHeights: Sendable, Equatable {
    var maxHeight: CGFloat
    var minHeight: CGFloat

    init(maxHeight: CGFloat, minHeight: CGFloat) {
        self.maxHeight = maxHeight
        self.minHeight = minHeight
    }

    var normalized: CollapsiblePagerHeaderHeights {
        let normalizedMax = max(0, maxHeight)
        let normalizedMin = min(max(0, minHeight), normalizedMax)
        return CollapsiblePagerHeaderHeights(maxHeight: normalizedMax, minHeight: normalizedMin)
    }

    var collapseRange: CGFloat {
        let heights = normalized
        return heights.maxHeight - heights.minHeight
    }
}

struct CollapsiblePagerLayoutInput: Sendable, Equatable {
    var containerBounds: CGRect
    var safeAreaInsets: CollapsiblePagerEdgeInsets
    var bottomObstructionInset: CGFloat
    var navigationBarMaxY: CGFloat?
    var headerHeights: CollapsiblePagerHeaderHeights
    var headerTopBehavior: CollapsiblePagerHeaderTopBehavior
    var tabBarHeight: CGFloat
    var tabBarPlacement: CollapsiblePagerTabBarPlacement
    var tabBarPinning: CollapsiblePagerTabBarPinning
    var pinAnchorY: CGFloat

    init(
        containerBounds: CGRect,
        safeAreaInsets: CollapsiblePagerEdgeInsets,
        bottomObstructionInset: CGFloat = 0,
        navigationBarMaxY: CGFloat?,
        headerHeights: CollapsiblePagerHeaderHeights,
        headerTopBehavior: CollapsiblePagerHeaderTopBehavior = .insideSafeArea,
        tabBarHeight: CGFloat,
        tabBarPlacement: CollapsiblePagerTabBarPlacement,
        tabBarPinning: CollapsiblePagerTabBarPinning,
        pinAnchorY: CGFloat
    ) {
        self.containerBounds = containerBounds
        self.safeAreaInsets = safeAreaInsets
        self.bottomObstructionInset = bottomObstructionInset
        self.navigationBarMaxY = navigationBarMaxY
        self.headerHeights = headerHeights
        self.headerTopBehavior = headerTopBehavior
        self.tabBarHeight = tabBarHeight
        self.tabBarPlacement = tabBarPlacement
        self.tabBarPinning = tabBarPinning
        self.pinAnchorY = pinAnchorY
    }

    static let defaultTestValue = CollapsiblePagerLayoutInput(
        containerBounds: CGRect(x: 0, y: 0, width: 390, height: 844),
        safeAreaInsets: CollapsiblePagerEdgeInsets(top: 47, left: 0, bottom: 34, right: 0),
        navigationBarMaxY: 91,
        headerHeights: CollapsiblePagerHeaderHeights(maxHeight: 260, minHeight: 0),
        headerTopBehavior: .insideSafeArea,
        tabBarHeight: 48,
        tabBarPlacement: .belowHeader,
        tabBarPinning: .pinBelowNavigationBar(offset: 0),
        pinAnchorY: 0
    )
}

struct CollapsiblePagerLayoutOutput: Sendable, Equatable {
    var pageContainerFrame: CGRect
    var headerFrame: CGRect
    var headerVisibleHeight: CGFloat
    var collapseProgress: CGFloat
    var tabBarFrame: CGRect
    var childContentInset: CollapsiblePagerEdgeInsets
    var pinThreshold: CGFloat
}

struct CollapsiblePagerHeaderOffsetTransition: Sendable, Equatable {
    var nextPinAnchorY: CGFloat
    var contentOffsetCorrectionY: CGFloat
}
