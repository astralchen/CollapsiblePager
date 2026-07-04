import CoreGraphics

/// 对外可观察的布局快照。
public struct CollapsiblePagerLayoutContext: Sendable, Equatable {
    /// 当前 Header 可见高度。
    public var headerVisibleHeight: CGFloat

    /// 当前折叠进度，范围为 `0...1`。
    public var collapseProgress: CGFloat

    /// 当前有效页面选择；没有页面时为 `nil`。
    public var effectiveSelectedIndex: Int?

    /// 创建布局快照。
    public init(
        headerVisibleHeight: CGFloat = 0,
        collapseProgress: CGFloat = 1,
        effectiveSelectedIndex: Int? = nil
    ) {
        self.headerVisibleHeight = headerVisibleHeight
        self.collapseProgress = collapseProgress
        self.effectiveSelectedIndex = effectiveSelectedIndex
    }
}
