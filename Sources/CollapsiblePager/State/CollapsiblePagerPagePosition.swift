import CoreGraphics

enum PageDirection: Sendable, Equatable {
    case backward
    case forward
    case stationary
}

struct PagePosition: Sendable, Equatable {
    var rawPosition: CGFloat
    var fromIndex: Int
    var toIndex: Int
    var progress: CGFloat
    var direction: PageDirection
    var isInteractive: Bool

    init(
        rawPosition: CGFloat,
        fromIndex: Int,
        toIndex: Int,
        progress: CGFloat,
        direction: PageDirection,
        isInteractive: Bool
    ) {
        self.rawPosition = rawPosition
        self.fromIndex = fromIndex
        self.toIndex = toIndex
        self.progress = progress.clamped(to: 0...1)
        self.direction = direction
        self.isInteractive = isInteractive
    }

    static func make(rawPosition: CGFloat, pageCount: Int, isInteractive: Bool) -> PagePosition? {
        guard pageCount > 0 else {
            return nil
        }

        let lastIndex = pageCount - 1
        let clampedRawPosition = rawPosition.clamped(to: 0...CGFloat(lastIndex))
        let lowerIndex = Int(clampedRawPosition.rounded(.down))
        let upperIndex = Int(clampedRawPosition.rounded(.up))
        let progress = clampedRawPosition - CGFloat(lowerIndex)
        let direction: PageDirection = lowerIndex == upperIndex ? .stationary : .forward

        return PagePosition(
            rawPosition: clampedRawPosition,
            fromIndex: lowerIndex,
            toIndex: upperIndex,
            progress: progress,
            direction: direction,
            isInteractive: isInteractive
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
