import UIKit

@MainActor
final class CollapsiblePagerContainerRefreshHostScrollView: UIScrollView, UIScrollViewDelegate {
    var shouldBeginRefreshPan: (@MainActor (UIPanGestureRecognizer) -> Bool)?
    var onRefreshPanWillBegin: (@MainActor () -> Void)?
    var onShouldScrollToTop: (@MainActor (UIScrollView) -> Bool)?
    var onDidScroll: (@MainActor (UIScrollView) -> Void)?
    var onScrollInteractionDidEnd: (@MainActor (UIScrollView) -> Void)?
    private var configuredRefreshBaselineTop: CGFloat = 0
    private var statusBarScrollToTopActivationInset: CGFloat = 0

    private var effectiveNeutralContentInsetTop: CGFloat {
        configuredRefreshBaselineTop + statusBarScrollToTopActivationInset
    }

    var neutralBaselineContentOffsetY: CGFloat {
        -configuredRefreshBaselineTop
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateContentSizeForCurrentBaseline()
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let superAllowsBegin = super.gestureRecognizerShouldBegin(gestureRecognizer)
        guard superAllowsBegin,
              gestureRecognizer === panGestureRecognizer,
              let pan = gestureRecognizer as? UIPanGestureRecognizer else {
            return superAllowsBegin
        }

        let shouldBegin = shouldBeginRefreshPan?(pan) ?? false
        if shouldBegin {
            onRefreshPanWillBegin?()
        }
        return shouldBegin
    }

    func resetOffsetIfIdle() {
        guard !isTracking,
              !isDragging,
              !isDecelerating,
              contentOffset.y != neutralBaselineContentOffsetY || contentOffset.x != 0 else {
            return
        }

        setContentOffset(CGPoint(x: 0, y: neutralBaselineContentOffsetY), animated: false)
    }

    func setRefreshOverscrollOffsetY(_ overscrollOffsetY: CGFloat) {
        setContentOffset(
            CGPoint(x: 0, y: neutralBaselineContentOffsetY + min(0, overscrollOffsetY)),
            animated: false
        )
    }

    func usesNeutralRefreshContentInset() -> Bool {
        abs(contentInset.top - effectiveNeutralContentInsetTop) < 0.5
    }

    func setStatusBarScrollToTopActivationEnabled(_ isEnabled: Bool) {
        let nextInset: CGFloat = isEnabled ? 1 : 0
        guard abs(nextInset - statusBarScrollToTopActivationInset) >= 0.5 else {
            return
        }

        let previousBaseline = neutralBaselineContentOffsetY
        let offsetFromBaseline = contentOffset.y - previousBaseline
        statusBarScrollToTopActivationInset = nextInset
        applyEffectiveNeutralContentInsetTop()
        updateContentSizeForCurrentBaseline()
        setContentOffset(
            CGPoint(x: 0, y: neutralBaselineContentOffsetY + min(0, offsetFromBaseline)),
            animated: false
        )
    }

    func updateRefreshBaselineTop(_ top: CGFloat) {
        let nextTop = max(0, top)
        guard abs(nextTop - configuredRefreshBaselineTop) >= 0.5 else {
            return
        }

        let previousBaseline = neutralBaselineContentOffsetY
        let offsetFromBaseline = contentOffset.y - previousBaseline
        configuredRefreshBaselineTop = nextTop
        applyEffectiveNeutralContentInsetTop()

        let nextBaseline = neutralBaselineContentOffsetY
        updateContentSizeForCurrentBaseline()
        setContentOffset(
            CGPoint(x: 0, y: nextBaseline + min(0, offsetFromBaseline)),
            animated: false
        )
    }

    func clampToNeutralBaselineIfNeeded() -> Bool {
        guard usesNeutralRefreshContentInset(),
              contentOffset.y > neutralBaselineContentOffsetY else {
            return false
        }

        setContentOffset(CGPoint(x: 0, y: neutralBaselineContentOffsetY), animated: false)
        return true
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        onDidScroll?(scrollView)
    }

    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        onShouldScrollToTop?(scrollView) ?? true
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !decelerate else {
            return
        }

        onScrollInteractionDidEnd?(scrollView)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        onScrollInteractionDidEnd?(scrollView)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        onScrollInteractionDidEnd?(scrollView)
    }

    private func configure() {
        backgroundColor = .clear
        bounces = true
        alwaysBounceVertical = true
        alwaysBounceHorizontal = false
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        scrollsToTop = false
        delegate = self
    }

    private func updateContentSizeForCurrentBaseline() {
        let nextContentSize = CGSize(
            width: bounds.width,
            height: max(0, bounds.height - configuredRefreshBaselineTop)
        )
        guard contentSize != nextContentSize else {
            return
        }

        contentSize = nextContentSize
    }

    private func applyEffectiveNeutralContentInsetTop() {
        var nextInset = contentInset
        nextInset.top = effectiveNeutralContentInsetTop
        guard contentInset != nextInset else {
            return
        }

        contentInset = nextInset
    }
}
