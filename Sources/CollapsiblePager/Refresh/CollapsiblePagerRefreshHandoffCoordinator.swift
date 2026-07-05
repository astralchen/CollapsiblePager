enum RefreshHandoff: Sendable, Equatable {
    case containerHost(index: Int)
    case childScrollView(index: Int)
}

struct RefreshHandoffCoordinator: Sendable, Equatable {
    var mode: CollapsiblePagerRefreshHandoffMode
    private(set) var activeHandoff: RefreshHandoff?

    init(mode: CollapsiblePagerRefreshHandoffMode) {
        self.mode = mode
    }

    mutating func tryBeginHandoff(headerIsExpanded: Bool, childIsAtTop: Bool, index: Int) -> RefreshHandoff? {
        guard activeHandoff == nil,
              headerIsExpanded,
              childIsAtTop,
              mode != .none else {
            return nil
        }

        let handoff: RefreshHandoff
        switch mode {
        case .none:
            return nil
        case .container:
            handoff = .containerHost(index: index)
        case .child:
            handoff = .childScrollView(index: index)
        }
        activeHandoff = handoff
        return handoff
    }

    mutating func resetGesture() {
        activeHandoff = nil
    }
}
