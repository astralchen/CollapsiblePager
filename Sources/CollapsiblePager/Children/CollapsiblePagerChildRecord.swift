import UIKit

@MainActor
final class CollapsiblePagerChildRecord {
    let index: Int
    let viewController: UIViewController
    let scrollView: UIScrollView
    let mountView: CollapsiblePagerHeaderMountView
    let baseContentInset: UIEdgeInsets
    let baseScrollIndicatorInsets: UIEdgeInsets
    let baseShowsVerticalScrollIndicator: Bool
    let baseShowsHorizontalScrollIndicator: Bool
    var lastManagedContentInset: UIEdgeInsets
    var lastKnownContentOffsetY: CGFloat

    init(
        index: Int,
        viewController: UIViewController,
        scrollView: UIScrollView,
        mountView: CollapsiblePagerHeaderMountView,
        baseContentInset: UIEdgeInsets = .zero,
        baseScrollIndicatorInsets: UIEdgeInsets = .zero,
        baseShowsVerticalScrollIndicator: Bool = true,
        baseShowsHorizontalScrollIndicator: Bool = true,
        lastManagedContentInset: UIEdgeInsets = .zero,
        lastKnownContentOffsetY: CGFloat
    ) {
        self.index = index
        self.viewController = viewController
        self.scrollView = scrollView
        self.mountView = mountView
        self.baseContentInset = baseContentInset
        self.baseScrollIndicatorInsets = baseScrollIndicatorInsets
        self.baseShowsVerticalScrollIndicator = baseShowsVerticalScrollIndicator
        self.baseShowsHorizontalScrollIndicator = baseShowsHorizontalScrollIndicator
        self.lastManagedContentInset = lastManagedContentInset
        self.lastKnownContentOffsetY = lastKnownContentOffsetY
    }
}
