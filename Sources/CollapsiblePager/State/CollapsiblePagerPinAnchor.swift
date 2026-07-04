import CoreGraphics

struct PinAnchor: Sendable, Equatable {
    private(set) var value: CGFloat

    init(value: CGFloat) {
        self.value = value
    }

    mutating func update(to nextValue: CGFloat) -> CGFloat {
        let delta = nextValue - value
        value = nextValue
        return delta
    }
}
