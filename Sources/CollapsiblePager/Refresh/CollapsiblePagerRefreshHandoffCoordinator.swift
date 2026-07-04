enum RefreshHandoff: Sendable, Equatable {
    case externalScrollView(scope: CollapsiblePagerRefreshMode, index: Int)
}

struct RefreshHandoffCoordinator: Sendable, Equatable {
    var mode: CollapsiblePagerRefreshMode
    private(set) var activeHandoff: RefreshHandoff?

    init(mode: CollapsiblePagerRefreshMode) {
        self.mode = mode
    }

    mutating func tryBeginHandoff(headerIsExpanded: Bool, childIsAtTop: Bool, index: Int) -> RefreshHandoff? {
        guard activeHandoff == nil,
              headerIsExpanded,
              childIsAtTop,
              mode != .none else {
            return nil
        }

        let handoff = RefreshHandoff.externalScrollView(scope: mode, index: index)
        activeHandoff = handoff
        return handoff
    }

    mutating func resetGesture() {
        activeHandoff = nil
    }
}
