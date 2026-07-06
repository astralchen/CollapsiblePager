import UIKit

@MainActor
final class CollapsiblePagerChildStore {
    private weak var owner: UIViewController?

    init(owner: UIViewController) {
        self.owner = owner
    }

    func makeRecord(
        for child: UIViewController,
        index: Int,
        managedTopInset: CGFloat,
        managedBottomInset: CGFloat = 0,
        pinThreshold: CGFloat = 0,
        initialPinAnchorY: CGFloat = 0
    ) -> CollapsiblePagerChildRecord? {
        guard let provider = child as? any CollapsiblePagerScrollProviding else {
            return nil
        }

        let scrollView = provider.pagerScrollView
        let baseContentInset = scrollView.contentInset
        let baseScrollIndicatorInsets = scrollView.verticalScrollIndicatorInsets
        let baseShowsVerticalScrollIndicator = scrollView.showsVerticalScrollIndicator
        let baseShowsHorizontalScrollIndicator = scrollView.showsHorizontalScrollIndicator
        let clampedTopInset = max(0, managedTopInset)
        applyManagedInsets(
            to: scrollView,
            baseContentInset: baseContentInset,
            baseScrollIndicatorInsets: baseScrollIndicatorInsets,
            topInset: clampedTopInset,
            bottomInset: managedBottomInset,
            pinThreshold: pinThreshold
        )
        resetInitialOffset(for: scrollView, managedTopInset: clampedTopInset, pinAnchorY: initialPinAnchorY)

        let mountView = CollapsiblePagerHeaderMountView(
            frame: CGRect(
                x: 0,
                y: -clampedTopInset,
                width: scrollView.bounds.width,
                height: clampedTopInset
            )
        )
        mountView.autoresizingMask = [.flexibleWidth]
        scrollView.addSubview(mountView)

        return CollapsiblePagerChildRecord(
            index: index,
            viewController: child,
            scrollView: scrollView,
            mountView: mountView,
            baseContentInset: baseContentInset,
            baseScrollIndicatorInsets: baseScrollIndicatorInsets,
            baseShowsVerticalScrollIndicator: baseShowsVerticalScrollIndicator,
            baseShowsHorizontalScrollIndicator: baseShowsHorizontalScrollIndicator,
            lastKnownContentOffsetY: scrollView.contentOffset.y
        )
    }

    func attach(_ record: CollapsiblePagerChildRecord, to container: UIView) {
        guard let owner, record.viewController.parent == nil else {
            return
        }

        owner.addChild(record.viewController)
        record.viewController.view.frame = container.bounds
        record.viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(record.viewController.view)
        record.viewController.didMove(toParent: owner)
    }

    func detach(_ record: CollapsiblePagerChildRecord) {
        guard record.viewController.parent != nil else {
            return
        }

        record.viewController.willMove(toParent: nil)
        record.viewController.view.removeFromSuperview()
        record.viewController.removeFromParent()
    }

    func updateManagedInset(
        for record: CollapsiblePagerChildRecord,
        managedTopInset: CGFloat,
        managedBottomInset: CGFloat = 0,
        pinThreshold: CGFloat = 0
    ) {
        let clampedTopInset = max(0, managedTopInset)
        applyManagedInsets(
            to: record.scrollView,
            baseContentInset: record.baseContentInset,
            baseScrollIndicatorInsets: record.baseScrollIndicatorInsets,
            topInset: clampedTopInset,
            bottomInset: managedBottomInset,
            pinThreshold: pinThreshold
        )
        record.mountView.frame = CGRect(
            x: 0,
            y: -clampedTopInset,
            width: record.scrollView.bounds.width,
            height: clampedTopInset
        )
    }

    private func applyManagedInsets(
        to scrollView: UIScrollView,
        baseContentInset: UIEdgeInsets,
        baseScrollIndicatorInsets: UIEdgeInsets,
        topInset: CGFloat,
        bottomInset: CGFloat,
        pinThreshold: CGFloat
    ) {
        var contentInset = baseContentInset
        contentInset.top = max(0, topInset)
        contentInset.bottom = managedBottomInset(
            for: scrollView,
            baseBottomInset: baseContentInset.bottom,
            layoutBottomInset: bottomInset,
            managedTopInset: topInset,
            pinThreshold: pinThreshold
        )
        if scrollView.contentInset != contentInset {
            scrollView.contentInset = contentInset
        }

        var indicatorInsets = baseScrollIndicatorInsets
        indicatorInsets.top = max(0, topInset)
        indicatorInsets.bottom = max(0, bottomInset)
        // Pager 已手动管理 indicator inset，避免 UIKit 再追加 safe area 或 bar 避让。
        if scrollView.automaticallyAdjustsScrollIndicatorInsets {
            scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        }
        if scrollView.verticalScrollIndicatorInsets != indicatorInsets {
            scrollView.verticalScrollIndicatorInsets = indicatorInsets
        }

        if scrollView.contentInsetAdjustmentBehavior != .never {
            scrollView.contentInsetAdjustmentBehavior = .never
        }
    }

    private func managedBottomInset(
        for scrollView: UIScrollView,
        baseBottomInset: CGFloat,
        layoutBottomInset: CGFloat,
        managedTopInset: CGFloat,
        pinThreshold: CGFloat
    ) -> CGFloat {
        let baseInset = max(0, baseBottomInset, layoutBottomInset)
        let clampedPinThreshold = max(0, pinThreshold)
        guard clampedPinThreshold > 0, scrollView.bounds.height > 0 else {
            return baseInset
        }

        let pinnedOffsetY = clampedPinThreshold - max(0, managedTopInset)
        let requiredInset = scrollView.bounds.height + pinnedOffsetY - scrollView.contentSize.height
        return max(baseInset, requiredInset)
    }

    private func resetInitialOffset(for scrollView: UIScrollView, managedTopInset: CGFloat, pinAnchorY: CGFloat) {
        scrollView.setContentOffset(
            CGPoint(x: scrollView.contentOffset.x, y: max(0, pinAnchorY) - managedTopInset),
            animated: false
        )
    }
}
