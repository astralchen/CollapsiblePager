import UIKit

@MainActor
final class CollapsiblePagerHeaderHostView: UIView {
    private(set) var contentView: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        clipsToBounds = true
    }

    func setContentView(_ view: UIView?) {
        if contentView !== view {
            contentView?.removeFromSuperview()
        }

        contentView = view

        guard let view, view.superview !== self else {
            return
        }

        view.frame = bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(view)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView?.frame = bounds
    }
}
