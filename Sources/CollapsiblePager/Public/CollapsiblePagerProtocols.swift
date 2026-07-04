import UIKit

/// 由 child view controller 显式提供参与协调的主滚动视图。
///
/// V1 不自动查找 scroll view。调用方需要确保返回的滚动视图属于当前 child 的视图层级，
/// 并且只在 `MainActor` 上访问。
@MainActor
public protocol CollapsiblePagerScrollProviding: AnyObject {
    /// 参与 Header 折叠、吸顶和刷新 handoff 的主滚动视图。
    var pagerScrollView: UIScrollView { get }
}
