import CoreGraphics
import Foundation

/// `CollapsiblePager` 的整体配置。
///
/// 配置描述容器自身的通用布局和交互策略，不包含业务内容。
@MainActor
public struct CollapsiblePagerConfiguration {
    /// Header 布局配置。
    public var header: CollapsiblePagerHeaderConfiguration

    /// TabBar 布局和指示器配置。
    public var tabBar: CollapsiblePagerTabBarConfiguration

    /// 横向分页配置。
    public var paging: CollapsiblePagerPagingConfiguration

    /// Header 完全展开后继续下拉时的刷新移交语义。
    public var refreshMode: CollapsiblePagerRefreshMode

    /// 创建配置。
    public init(
        header: CollapsiblePagerHeaderConfiguration = .default,
        tabBar: CollapsiblePagerTabBarConfiguration = .default,
        paging: CollapsiblePagerPagingConfiguration = .default,
        refreshMode: CollapsiblePagerRefreshMode = .none
    ) {
        self.header = header
        self.tabBar = tabBar
        self.paging = paging
        self.refreshMode = refreshMode
    }

    /// V1 默认配置。
    public static let `default` = CollapsiblePagerConfiguration()
}

/// Header 高度配置。
public struct CollapsiblePagerHeaderConfiguration: Sendable, Equatable {
    /// Header 高度模式。
    public var heightMode: CollapsiblePagerHeaderHeightMode

    /// Header 顶部相对 safe area 的视觉行为。
    public var topBehavior: CollapsiblePagerHeaderTopBehavior

    /// 创建 Header 配置。
    public init(
        heightMode: CollapsiblePagerHeaderHeightMode = .fixed(max: 260, min: 0),
        topBehavior: CollapsiblePagerHeaderTopBehavior = .insideSafeArea
    ) {
        self.heightMode = heightMode
        self.topBehavior = topBehavior
    }

    /// V1 默认 Header 配置。
    public static let `default` = CollapsiblePagerHeaderConfiguration()
}

/// Header 高度来源。
public enum CollapsiblePagerHeaderHeightMode: Sendable, Equatable {
    /// 使用固定最大和最小高度。
    case fixed(max: CGFloat, min: CGFloat)
}

/// Header 顶部视觉是否延伸到顶部安全区域外。
public enum CollapsiblePagerHeaderTopBehavior: Sendable, Equatable {
    /// Header 从 safe area top 或导航栏底部开始。
    case insideSafeArea

    /// Header 从容器顶部开始；TabBar 和 child 内容仍保持在吸顶安全位置内。
    case extendsUnderTopSafeArea
}

/// Header 高度变化后如何修正当前视觉位置。
public enum CollapsiblePagerHeaderOffsetPolicy: Sendable, Equatable {
    /// 保持 Header 与内容的屏幕视觉位置。
    case preserveVisualPosition

    /// 保持当前折叠进度。
    case preserveCollapseProgress

    /// 重置到完全展开。
    case resetToExpanded

    /// 重置到完全折叠。
    case resetToCollapsed
}

/// TabBar 配置。
public struct CollapsiblePagerTabBarConfiguration: Sendable, Equatable {
    /// TabBar 高度。
    public var height: CGFloat

    /// TabBar 相对 Header 的布局位置。
    public var placement: CollapsiblePagerTabBarPlacement

    /// TabBar 吸顶策略。
    public var pinning: CollapsiblePagerTabBarPinning

    /// 默认 indicator 配置。
    public var indicator: CollapsiblePagerIndicatorConfiguration

    /// 创建 TabBar 配置。
    public init(
        height: CGFloat = 48,
        placement: CollapsiblePagerTabBarPlacement = .belowHeader,
        pinning: CollapsiblePagerTabBarPinning = .pinBelowNavigationBar(offset: 0),
        indicator: CollapsiblePagerIndicatorConfiguration = .default
    ) {
        self.height = height
        self.placement = placement
        self.pinning = pinning
        self.indicator = indicator
    }

    /// V1 默认 TabBar 配置。
    public static let `default` = CollapsiblePagerTabBarConfiguration()
}

/// TabBar 的默认布局位置。
public enum CollapsiblePagerTabBarPlacement: Sendable, Equatable {
    /// TabBar 位于 Header 下方。
    case belowHeader
}

/// TabBar 吸顶位置。
public enum CollapsiblePagerTabBarPinning: Sendable, Equatable {
    /// 吸附在导航栏底部；无导航栏时回退到 safe area top。
    case pinBelowNavigationBar(offset: CGFloat)
}

/// 默认下划线 indicator 配置。
public struct CollapsiblePagerIndicatorConfiguration: Sendable, Equatable {
    /// Indicator 高度。
    public var height: CGFloat

    /// Indicator 圆角半径。
    public var cornerRadius: CGFloat

    /// Indicator 宽度模式。
    public var widthMode: CollapsiblePagerIndicatorWidthMode

    /// 创建 indicator 配置。
    public init(
        height: CGFloat = 3,
        cornerRadius: CGFloat = 1.5,
        widthMode: CollapsiblePagerIndicatorWidthMode = .fixed(28)
    ) {
        self.height = height
        self.cornerRadius = cornerRadius
        self.widthMode = widthMode
    }

    /// V1 默认 indicator 配置。
    public static let `default` = CollapsiblePagerIndicatorConfiguration()
}

/// Indicator 宽度计算方式。
public enum CollapsiblePagerIndicatorWidthMode: Sendable, Equatable {
    /// 固定宽度。
    case fixed(CGFloat)

    /// 使用标题宽度。
    case title

    /// 使用整个 item 宽度。
    case item

    /// 使用 item 宽度比例。
    case ratio(CGFloat)
}

/// 横向分页配置。
public struct CollapsiblePagerPagingConfiguration: Sendable, Equatable {
    /// 是否允许用户横向滑动切页。
    public var allowsSwipeToChangePage: Bool

    /// 横向 paging scroll view 是否允许回弹。
    public var bouncesHorizontally: Bool

    /// Tab 点击触发的默认动画时长。
    public var tabSelectionAnimationDuration: TimeInterval

    /// 创建横向分页配置。
    public init(
        allowsSwipeToChangePage: Bool = true,
        bouncesHorizontally: Bool = true,
        tabSelectionAnimationDuration: TimeInterval = 0.28
    ) {
        self.allowsSwipeToChangePage = allowsSwipeToChangePage
        self.bouncesHorizontally = bouncesHorizontally
        self.tabSelectionAnimationDuration = tabSelectionAnimationDuration
    }

    /// V1 默认分页配置。
    public static let `default` = CollapsiblePagerPagingConfiguration()
}

/// Header 完全展开后的刷新移交语义。
public enum CollapsiblePagerRefreshMode: Sendable, Equatable {
    /// 不移交刷新。
    case none

    /// 移交给外部整体刷新机制。
    case overall

    /// 移交给当前 child 的外部刷新机制。
    case child
}
