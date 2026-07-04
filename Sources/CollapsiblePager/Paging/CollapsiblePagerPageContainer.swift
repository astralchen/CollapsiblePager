import UIKit

@MainActor
final class CollapsiblePagerPageContainer: UIView, UIScrollViewDelegate {
    let scrollView: UIScrollView
    private var pageViews: [Int: UIView] = [:]
    var pageCount: Int = 0 {
        didSet {
            pageCount = max(0, pageCount)
            updateContentSize()
            removeOutOfRangePageViews()
        }
    }
    var onPagePositionChanged: (@MainActor (PagePosition?) -> Void)?
    var onPageTransitionCompleted: (@MainActor (Int) -> Void)?

    override init(frame: CGRect) {
        scrollView = UIScrollView(frame: .zero)
        super.init(frame: frame)
        configureScrollView()
    }

    required init?(coder: NSCoder) {
        scrollView = UIScrollView(frame: .zero)
        super.init(coder: coder)
        configureScrollView()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        updateContentSize()
        layoutPageViews()
    }

    func setPageCount(_ pageCount: Int) {
        self.pageCount = pageCount
    }

    func apply(paging: CollapsiblePagerPagingConfiguration) {
        scrollView.isScrollEnabled = paging.allowsSwipeToChangePage
        scrollView.bounces = paging.bouncesHorizontally
    }

    func pageView(at index: Int) -> UIView? {
        guard pageCount > 0, (0..<pageCount).contains(index) else {
            return nil
        }

        if let pageView = pageViews[index] {
            return pageView
        }

        let pageView = UIView()
        pageViews[index] = pageView
        scrollView.addSubview(pageView)
        setNeedsLayout()
        layoutIfNeeded()
        return pageView
    }

    func removeAllPageViews() {
        pageViews.values.forEach { $0.removeFromSuperview() }
        pageViews.removeAll()
    }

    func removePageView(at index: Int) {
        pageViews[index]?.removeFromSuperview()
        pageViews[index] = nil
    }

    var loadedPageIndexes: [Int] {
        pageViews.keys.sorted()
    }

    func scrollToPage(at index: Int, animated: Bool) {
        guard pageCount > 0, (0..<pageCount).contains(index), scrollView.bounds.width > 0 else {
            return
        }

        let offset = CGPoint(x: CGFloat(index) * scrollView.bounds.width, y: 0)
        scrollView.setContentOffset(offset, animated: animated)
        if !animated {
            emitPagePosition(isInteractive: false)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        emitPagePosition(isInteractive: scrollView.isDragging || scrollView.isDecelerating)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        emitPagePosition(isInteractive: false)
        onPageTransitionCompleted?(currentPageIndex())
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        emitPagePosition(isInteractive: false)
        onPageTransitionCompleted?(currentPageIndex())
    }

    private func configureScrollView() {
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.alwaysBounceVertical = false
        scrollView.delegate = self
        addSubview(scrollView)
    }

    private func updateContentSize() {
        scrollView.contentSize = CGSize(width: bounds.width * CGFloat(pageCount), height: bounds.height)
    }

    private func layoutPageViews() {
        for (index, pageView) in pageViews {
            pageView.frame = CGRect(
                x: CGFloat(index) * bounds.width,
                y: 0,
                width: bounds.width,
                height: bounds.height
            )
        }
    }

    private func removeOutOfRangePageViews() {
        let indexesToRemove = pageViews.keys.filter { !(0..<pageCount).contains($0) }
        for index in indexesToRemove {
            pageViews[index]?.removeFromSuperview()
            pageViews[index] = nil
        }
    }

    private func emitPagePosition(isInteractive: Bool) {
        guard scrollView.bounds.width > 0 else {
            onPagePositionChanged?(nil)
            return
        }

        let rawPosition = scrollView.contentOffset.x / scrollView.bounds.width
        onPagePositionChanged?(PagePosition.make(rawPosition: rawPosition, pageCount: pageCount, isInteractive: isInteractive))
    }

    private func currentPageIndex() -> Int {
        guard pageCount > 0, scrollView.bounds.width > 0 else {
            return 0
        }

        let rawIndex = (scrollView.contentOffset.x / scrollView.bounds.width).rounded()
        return Int(rawIndex).clamped(to: 0...(pageCount - 1))
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
