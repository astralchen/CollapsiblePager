import UIKit

@MainActor
final class CollapsiblePagerUnderlineIndicatorView: UIView {
    var configuration: CollapsiblePagerIndicatorConfiguration {
        didSet {
            updateAppearance()
        }
    }

    init(configuration: CollapsiblePagerIndicatorConfiguration = .default) {
        self.configuration = configuration
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateAppearance() {
        backgroundColor = .systemYellow
        layer.cornerRadius = max(0, configuration.cornerRadius)
        layer.masksToBounds = true
    }
}
