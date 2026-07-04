import UIKit

@MainActor
final class CollapsiblePagerScrollObservation {
    private var contentOffsetObservation: NSKeyValueObservation?
    private var contentSizeObservation: NSKeyValueObservation?

    init(
        scrollView: UIScrollView,
        offsetHandler: @escaping @MainActor (UIScrollView) -> Void,
        contentSizeHandler: @escaping @MainActor (UIScrollView) -> Void
    ) {
        contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { scrollView, _ in
            // 受管 UIScrollView 的 offset 变化来自 UIKit 主线程滚动回调，统一回到 MainActor 更新布局状态。
            MainActor.assumeIsolated {
                offsetHandler(scrollView)
            }
        }
        contentSizeObservation = scrollView.observe(\.contentSize, options: [.new]) { scrollView, _ in
            // 业务内容高度变化会改变短页是否能滚到吸顶阈值，需要在主线程重算受管 inset。
            MainActor.assumeIsolated {
                contentSizeHandler(scrollView)
            }
        }
    }

    deinit {
        contentOffsetObservation?.invalidate()
        contentSizeObservation?.invalidate()
    }
}
