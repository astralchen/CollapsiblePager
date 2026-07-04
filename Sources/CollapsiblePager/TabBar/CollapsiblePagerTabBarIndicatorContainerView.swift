import UIKit

@MainActor
final class CollapsiblePagerTabBarIndicatorContainerView: UIView {
    private let indicatorView = CollapsiblePagerUnderlineIndicatorView()

    var indicatorFrame: CGRect? {
        indicatorView.isHidden ? nil : indicatorView.frame
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        addSubview(indicatorView)
        indicatorView.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(configuration: CollapsiblePagerIndicatorConfiguration) {
        indicatorView.configuration = configuration
    }

    func updateIndicatorFrame(_ frame: CGRect?) {
        guard let frame else {
            indicatorView.isHidden = true
            indicatorView.frame = .zero
            return
        }

        indicatorView.frame = frame
        indicatorView.isHidden = false
    }
}
