import CoreGraphics

/// `CollapsiblePagerViewController` 的状态变化回调。
///
/// Delegate 不承载刷新生命周期；刷新触发、任务和结束时机均由外部机制负责。
@MainActor
public protocol CollapsiblePagerViewControllerDelegate: AnyObject {
    /// 页面选择完成提交后调用。
    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, didSelectPageAt index: Int)

    /// Header 折叠进度变化时调用，范围为 `0...1`。
    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, didUpdateCollapseProgress progress: CGFloat)

    /// 布局上下文更新后调用。
    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, didUpdateLayout context: CollapsiblePagerLayoutContext)
}
