import UIKit

@MainActor
final class CollapsiblePagerContainerRefreshHostScrollView: UIScrollView, UIScrollViewDelegate {
    var shouldBeginRefreshPan: (@MainActor (UIPanGestureRecognizer) -> Bool)?
    var onRefreshPanWillBegin: (@MainActor () -> Void)?
    var onDidScroll: (@MainActor (UIScrollView) -> Void)?
    var onScrollInteractionDidEnd: (@MainActor (UIScrollView) -> Void)?
    private var configuredRefreshBaselineTop: CGFloat = 0

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
        abs(contentInset.top - configuredRefreshBaselineTop) < 0.5
    }

    func updateRefreshBaselineTop(_ top: CGFloat) {
        let nextTop = max(0, top)
        guard abs(nextTop - configuredRefreshBaselineTop) >= 0.5 else {
            return
        }

        let previousBaseline = neutralBaselineContentOffsetY
        let offsetFromBaseline = contentOffset.y - previousBaseline
        configuredRefreshBaselineTop = nextTop

        var nextInset = contentInset
        nextInset.top = nextTop
        contentInset = nextInset

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
}
