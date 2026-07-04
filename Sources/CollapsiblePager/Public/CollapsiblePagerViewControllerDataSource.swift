import UIKit

/// Header 内容来源。
@MainActor
public enum CollapsiblePagerHeaderContent {
    /// 由调用方提供普通 view。
    case view(UIView)

    /// 由调用方提供 view controller，容器会负责标准 UIKit containment。
    case viewController(UIViewController)
}

/// `CollapsiblePagerViewController` 的内容数据源。
///
/// Data source 只提供 Header、标题和 child view controller，不参与滚动状态提交。
@MainActor
public protocol CollapsiblePagerViewControllerDataSource: AnyObject {
    /// 返回页面数量；负数会被容器夹取为 `0`。
    func numberOfPages(in pagerViewController: CollapsiblePagerViewController) -> Int

    /// 返回指定页面的标题。
    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, titleForPageAt index: Int) -> String

    /// 返回指定页面的 child view controller。
    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, viewControllerForPageAt index: Int) -> UIViewController

    /// 返回 Header 内容。
    func headerContent(in pagerViewController: CollapsiblePagerViewController) -> CollapsiblePagerHeaderContent
}
