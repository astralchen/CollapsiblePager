import CoreGraphics

struct IndicatorFocusRect: Sendable, Equatable {
    var itemFrame: CGRect
    var titleFrame: CGRect

    static func make(
        itemFrames: [CGRect],
        titleFrames: [CGRect],
        position: PagePosition
    ) -> IndicatorFocusRect? {
        guard itemFrames.indices.contains(position.fromIndex),
              itemFrames.indices.contains(position.toIndex),
              titleFrames.indices.contains(position.fromIndex),
              titleFrames.indices.contains(position.toIndex) else {
            return nil
        }

        return IndicatorFocusRect(
            itemFrame: itemFrames[position.fromIndex].interpolated(to: itemFrames[position.toIndex], progress: position.progress),
            titleFrame: titleFrames[position.fromIndex].interpolated(to: titleFrames[position.toIndex], progress: position.progress)
        )
    }

    func indicatorFrame(
        widthMode: CollapsiblePagerIndicatorWidthMode,
        height: CGFloat,
        bottomInset: CGFloat
    ) -> CGRect {
        let indicatorHeight = max(0, height)
        let width = indicatorWidth(for: widthMode)
        return CGRect(
            x: itemFrame.midX - width / 2,
            y: itemFrame.maxY - bottomInset - indicatorHeight,
            width: width,
            height: indicatorHeight
        )
    }

    private func indicatorWidth(for widthMode: CollapsiblePagerIndicatorWidthMode) -> CGFloat {
        switch widthMode {
        case let .fixed(width):
            return max(0, width)
        case .title:
            return max(0, titleFrame.width)
        case .item:
            return max(0, itemFrame.width)
        case let .ratio(ratio):
            return max(0, itemFrame.width * ratio)
        }
    }
}

private extension CGRect {
    func interpolated(to other: CGRect, progress: CGFloat) -> CGRect {
        let clampedProgress = progress.clamped(to: 0...1)
        return CGRect(
            x: origin.x.interpolated(to: other.origin.x, progress: clampedProgress),
            y: origin.y.interpolated(to: other.origin.y, progress: clampedProgress),
            width: size.width.interpolated(to: other.size.width, progress: clampedProgress),
            height: size.height.interpolated(to: other.size.height, progress: clampedProgress)
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
