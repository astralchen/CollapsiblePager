import UIKit

@MainActor
final class CollapsiblePagerTabItemView: UIControl {
    private let titleLabel = UILabel()

    var onPrimaryAction: (@MainActor () -> Void)?

    var selectionProgress: CGFloat = 0 {
        didSet {
            selectionProgress = selectionProgress.clamped(to: 0...1)
            updateAppearance()
            setNeedsLayout()
        }
    }

    override var isEnabled: Bool {
        didSet {
            updateAppearance()
        }
    }

    init(title: String) {
        super.init(frame: .zero)
        commonInit()
        setTitle(title)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTitle(_ title: String) {
        titleLabel.text = title
        accessibilityLabel = title
        setNeedsLayout()
    }

    func titleFrame(in view: UIView) -> CGRect {
        convert(titleLabel.frame, to: view)
    }

    override func sendActions(for controlEvents: UIControl.Event) {
        if controlEvents.contains(.touchUpInside) {
            onPrimaryAction?()
            return
        }

        super.sendActions(for: controlEvents)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let fittingSize = CGSize(width: bounds.width, height: bounds.height)
        let labelSize = titleLabel.sizeThatFits(fittingSize)
        titleLabel.frame = CGRect(
            x: (bounds.width - labelSize.width) / 2,
            y: (bounds.height - labelSize.height) / 2,
            width: min(labelSize.width, bounds.width),
            height: min(labelSize.height, bounds.height)
        )
    }

    private func commonInit() {
        isAccessibilityElement = true
        accessibilityTraits = .button
        addTarget(self, action: #selector(handleTouchUpInside), for: .touchUpInside)

        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true
        addSubview(titleLabel)

        updateAppearance()
    }

    @objc private func handleTouchUpInside() {
        onPrimaryAction?()
    }

    private func updateAppearance() {
        let clampedProgress = selectionProgress.clamped(to: 0...1)

        isSelected = clampedProgress == 1
        titleLabel.font = font(for: clampedProgress)

        if isEnabled {
            titleLabel.textColor = UIColor.interpolated(
                from: .secondaryLabel,
                to: .label,
                progress: clampedProgress,
                traitCollection: traitCollection
            )
        } else {
            titleLabel.textColor = .tertiaryLabel
        }

        var traits: UIAccessibilityTraits = .button
        if isSelected {
            traits.insert(.selected)
        }
        if !isEnabled {
            traits.insert(.notEnabled)
        }
        accessibilityTraits = traits
    }

    private func font(for progress: CGFloat) -> UIFont {
        let clampedProgress = progress.clamped(to: 0...1)
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .subheadline)
        let regularWeight = UIFont.Weight.regular.rawValue
        let selectedWeight = UIFont.Weight.semibold.rawValue
        let weight = regularWeight + (selectedWeight - regularWeight) * clampedProgress
        let font = UIFont.systemFont(ofSize: descriptor.pointSize, weight: UIFont.Weight(rawValue: weight))
        return UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: font)
    }
}

private extension UIColor {
    static func interpolated(
        from startColor: UIColor,
        to endColor: UIColor,
        progress: CGFloat,
        traitCollection: UITraitCollection
    ) -> UIColor {
        let progress = progress.clamped(to: 0...1)
        let start = startColor.resolvedColor(with: traitCollection)
        let end = endColor.resolvedColor(with: traitCollection)

        var startRed: CGFloat = 0
        var startGreen: CGFloat = 0
        var startBlue: CGFloat = 0
        var startAlpha: CGFloat = 0
        var endRed: CGFloat = 0
        var endGreen: CGFloat = 0
        var endBlue: CGFloat = 0
        var endAlpha: CGFloat = 0

        guard start.getRed(&startRed, green: &startGreen, blue: &startBlue, alpha: &startAlpha),
              end.getRed(&endRed, green: &endGreen, blue: &endBlue, alpha: &endAlpha) else {
            return progress == 1 ? endColor : startColor
        }

        return UIColor(
            red: startRed.interpolated(to: endRed, progress: progress),
            green: startGreen.interpolated(to: endGreen, progress: progress),
            blue: startBlue.interpolated(to: endBlue, progress: progress),
            alpha: startAlpha.interpolated(to: endAlpha, progress: progress)
        )
    }
}

private extension CGFloat {
    func interpolated(to other: CGFloat, progress: CGFloat) -> CGFloat {
        self + (other - self) * progress
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
