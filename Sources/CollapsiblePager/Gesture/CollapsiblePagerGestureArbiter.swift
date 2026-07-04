import CoreGraphics

enum GesturePriority: Sendable, Equatable {
    case systemBack
    case horizontalPaging
    case verticalScrolling
    case ignored
}

struct GestureArbiterInput: Sendable, Equatable {
    var translation: CGSize
    var isOnFirstPage: Bool
    var startsAtLeadingEdge: Bool
    var isInHeader: Bool
    var isRefreshAnimationActive: Bool
    var isLayoutReloadActive: Bool

    init(
        translation: CGSize,
        isOnFirstPage: Bool,
        startsAtLeadingEdge: Bool,
        isInHeader: Bool,
        isRefreshAnimationActive: Bool = false,
        isLayoutReloadActive: Bool = false
    ) {
        self.translation = translation
        self.isOnFirstPage = isOnFirstPage
        self.startsAtLeadingEdge = startsAtLeadingEdge
        self.isInHeader = isInHeader
        self.isRefreshAnimationActive = isRefreshAnimationActive
        self.isLayoutReloadActive = isLayoutReloadActive
    }
}

struct GestureArbiter: Sendable {
    func gesturePriority(for input: GestureArbiterInput) -> GesturePriority {
        let horizontalIntent = abs(input.translation.width) > abs(input.translation.height)
        let verticalIntent = abs(input.translation.height) >= abs(input.translation.width)

        if input.isOnFirstPage,
           input.startsAtLeadingEdge,
           horizontalIntent,
           input.translation.width > 0 {
            return .systemBack
        }

        if input.isRefreshAnimationActive || input.isLayoutReloadActive {
            return horizontalIntent ? .ignored : .verticalScrolling
        }

        if input.isInHeader, horizontalIntent {
            return .ignored
        }

        if horizontalIntent {
            return .horizontalPaging
        }
        if verticalIntent {
            return .verticalScrolling
        }
        return .ignored
    }
}
