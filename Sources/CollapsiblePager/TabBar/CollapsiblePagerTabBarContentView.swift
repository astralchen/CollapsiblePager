import UIKit

@MainActor
final class CollapsiblePagerTabBarContentView: UIView {
    var onRequestSelection: (@MainActor (Int) -> Void)?

    let contentScrollView = UIScrollView()
    let itemLayoutView = UIView()
    let indicatorContainerView = CollapsiblePagerTabBarIndicatorContainerView()

    private(set) var itemViews: [CollapsiblePagerTabItemView] = []
    private var currentPosition: PagePosition?
    private var configuration = CollapsiblePagerTabBarConfiguration.default

    var itemCount: Int {
        itemViews.count
    }

    var indicatorFrameInSelf: CGRect? {
        guard let indicatorFrame = indicatorContainerView.indicatorFrame else {
            return nil
        }

        return indicatorContainerView.convert(indicatorFrame, to: self)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(configuration: CollapsiblePagerTabBarConfiguration) {
        self.configuration = configuration
        indicatorContainerView.apply(configuration: configuration.indicator)
        setNeedsLayout()
    }

    func reloadTitles(_ titles: [String]) {
        itemViews.forEach { $0.removeFromSuperview() }
        itemViews = titles.enumerated().map { index, title in
            let itemView = CollapsiblePagerTabItemView(title: title)
            itemView.tag = index
            itemView.onPrimaryAction = { [weak self] in
                self?.onRequestSelection?(index)
            }
            itemLayoutView.addSubview(itemView)
            return itemView
        }

        currentPosition = nil
        indicatorContainerView.updateIndicatorFrame(nil)
        updateSelectionProgress()
        setNeedsLayout()
    }

    func itemView(at index: Int) -> CollapsiblePagerTabItemView? {
        guard itemViews.indices.contains(index) else {
            return nil
        }
        return itemViews[index]
    }

    func update(position: PagePosition?) {
        currentPosition = position
        updateSelectionProgress()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layoutContentHierarchy()
        itemViews.forEach { $0.layoutIfNeeded() }
        updateIndicatorFrame()
    }

    private func commonInit() {
        contentScrollView.showsHorizontalScrollIndicator = false
        contentScrollView.showsVerticalScrollIndicator = false
        contentScrollView.bounces = false
        contentScrollView.isScrollEnabled = false
        contentScrollView.contentInsetAdjustmentBehavior = .never

        addSubview(contentScrollView)
        contentScrollView.addSubview(itemLayoutView)
        itemLayoutView.addSubview(indicatorContainerView)
    }

    private func layoutContentHierarchy() {
        contentScrollView.frame = bounds
        contentScrollView.contentSize = bounds.size
        contentScrollView.contentOffset = .zero
        itemLayoutView.frame = CGRect(origin: .zero, size: bounds.size)
        indicatorContainerView.frame = itemLayoutView.bounds

        guard !itemViews.isEmpty else {
            return
        }

        let itemWidth = bounds.width / CGFloat(itemViews.count)
        for (index, itemView) in itemViews.enumerated() {
            itemView.frame = CGRect(
                x: CGFloat(index) * itemWidth,
                y: 0,
                width: itemWidth,
                height: bounds.height
            )
        }
    }

    private func updateSelectionProgress() {
        for (index, itemView) in itemViews.enumerated() {
            itemView.selectionProgress = selectionProgress(for: index)
        }
    }

    private func selectionProgress(for index: Int) -> CGFloat {
        guard let currentPosition else {
            return 0
        }

        if currentPosition.fromIndex == currentPosition.toIndex {
            return index == currentPosition.fromIndex ? 1 : 0
        }

        if index == currentPosition.fromIndex {
            return 1 - currentPosition.progress
        }
        if index == currentPosition.toIndex {
            return currentPosition.progress
        }
        return 0
    }

    private func updateIndicatorFrame() {
        guard let currentPosition,
              !itemViews.isEmpty else {
            indicatorContainerView.updateIndicatorFrame(nil)
            return
        }

        let itemFrames = itemViews.map(\.frame)
        let titleFrames = itemViews.map { $0.titleFrame(in: itemLayoutView) }
        guard let focusRect = IndicatorFocusRect.make(
            itemFrames: itemFrames,
            titleFrames: titleFrames,
            position: currentPosition
        ) else {
            indicatorContainerView.updateIndicatorFrame(nil)
            return
        }

        let frame = focusRect.indicatorFrame(
            widthMode: configuration.indicator.widthMode,
            height: configuration.indicator.height,
            bottomInset: 0
        )
        indicatorContainerView.updateIndicatorFrame(frame)
    }
}
