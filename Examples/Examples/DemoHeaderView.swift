import UIKit

@MainActor
final class DemoHeaderView: UIView {
    var onReloadLayout: (() -> Void)?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let selectionLabel = UILabel()
    private let progressLabel = UILabel()
    private let reloadButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func setSelectionText(_ text: String) {
        selectionLabel.text = text
    }

    func setProgress(_ progress: CGFloat) {
        progressLabel.text = "Collapse: \(Int(progress * 100))%"
    }

    private func configure() {
        accessibilityIdentifier = "demo-header"
        backgroundColor = .secondarySystemBackground

        titleLabel.text = "CollapsiblePager Demo"
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.adjustsFontForContentSizeCategory = true

        subtitleLabel.text = "Header, equal-width tabs, paging, and external refresh controls."
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.adjustsFontForContentSizeCategory = true

        selectionLabel.text = "Selected: Long"
        selectionLabel.font = .preferredFont(forTextStyle: .headline)
        selectionLabel.adjustsFontForContentSizeCategory = true

        progressLabel.text = "Collapse: 0%"
        progressLabel.font = .preferredFont(forTextStyle: .caption1)
        progressLabel.textColor = .secondaryLabel
        progressLabel.adjustsFontForContentSizeCategory = true

        reloadButton.setTitle("Reload Header Layout", for: .normal)
        reloadButton.addTarget(self, action: #selector(reloadTapped), for: .touchUpInside)

        let stackView = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel,
            selectionLabel,
            progressLabel,
            reloadButton,
        ])
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
        ])
    }

    @objc private func reloadTapped() {
        onReloadLayout?()
    }
}
