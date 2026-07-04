import UIKit

@MainActor
final class CollapsiblePagerTabBarView: UIView {
    var onRequestSelection: (@MainActor (Int) -> Void)?

    private let contentView = CollapsiblePagerTabBarContentView()
    private let separatorView = UIView()

    var itemCount: Int {
        contentView.itemCount
    }

    var indicatorFrame: CGRect? {
        contentView.indicatorFrameInSelf
    }

    var contentViewForTesting: UIView {
        contentView
    }

    var contentScrollViewForTesting: UIScrollView {
        contentView.contentScrollView
    }

    var itemLayoutViewForTesting: UIView {
        contentView.itemLayoutView
    }

    var indicatorContainerViewForTesting: UIView {
        contentView.indicatorContainerView
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
        contentView.apply(configuration: configuration)
        setNeedsLayout()
    }

    func reloadTitles(_ titles: [String]) {
        contentView.reloadTitles(titles)
        setNeedsLayout()
    }

    func itemView(at index: Int) -> CollapsiblePagerTabItemView? {
        contentView.itemView(at: index)
    }

    func update(position: PagePosition?) {
        contentView.update(position: position)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layoutItemViews()
        layoutSeparator()
    }

    private func commonInit() {
        backgroundColor = .systemBackground
        contentView.onRequestSelection = { [weak self] index in
            self?.onRequestSelection?(index)
        }

        separatorView.backgroundColor = .separator
        addSubview(contentView)
        addSubview(separatorView)
    }

    private func layoutItemViews() {
        contentView.frame = bounds
    }

    private func layoutSeparator() {
        let separatorHeight = 1 / max(UIScreen.main.scale, 1)
        separatorView.frame = CGRect(
            x: 0,
            y: bounds.height - separatorHeight,
            width: bounds.width,
            height: separatorHeight
        )
    }
}
