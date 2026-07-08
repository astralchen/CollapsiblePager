import CoreGraphics

enum PageRequestSource: Sendable, Equatable {
    case tabTap
    case api
    case gesture
}

struct PageRequest: Sendable, Equatable {
    var source: PageRequestSource
    var fromIndex: Int
    var targetIndex: Int
    var animated: Bool

    init(source: PageRequestSource, fromIndex: Int, targetIndex: Int, animated: Bool) {
        self.source = source
        self.fromIndex = fromIndex
        self.targetIndex = targetIndex
        self.animated = animated
    }
}

enum PageTransitionCompletionResult: Sendable, Equatable {
    case committed
    case cancelled
    case ignored
}

struct PageRequestPipeline: Sendable {
    func request(_ request: PageRequest, state: inout CollapsiblePagerState) -> Bool {
        guard state.pageCount > 0,
              isValid(request.targetIndex, in: state),
              isValid(request.fromIndex, in: state) else {
            return false
        }

        if request.targetIndex == state.effectiveSelectedIndex {
            guard state.pendingSelectedIndex != nil else {
                return false
            }

            cancel(sourceIndex: request.targetIndex, state: &state)
            return true
        }

        guard request.targetIndex != state.pendingSelectedIndex else {
            return false
        }

        state.pendingSelectedIndex = request.targetIndex
        state.pendingPageRequestSource = request.source
        state.pagePosition = PagePosition(
            rawPosition: CGFloat(request.fromIndex),
            fromIndex: request.fromIndex,
            toIndex: request.targetIndex,
            progress: 0,
            direction: direction(from: request.fromIndex, to: request.targetIndex),
            isInteractive: request.source == .gesture
        )
        return true
    }

    @discardableResult
    func complete(targetIndex: Int, state: inout CollapsiblePagerState) -> PageTransitionCompletionResult {
        guard state.pageCount > 0 else {
            state.pendingSelectedIndex = nil
            state.pendingPageRequestSource = nil
            state.effectiveSelectedIndex = nil
            state.pagePosition = nil
            return .ignored
        }

        guard isValid(targetIndex, in: state) else {
            return .ignored
        }

        guard state.pendingSelectedIndex == targetIndex else {
            if state.pendingSelectedIndex != nil, state.effectiveSelectedIndex == targetIndex {
                cancel(sourceIndex: targetIndex, state: &state)
                return .cancelled
            }
            if state.pendingPageRequestSource == .gesture,
               isSettledPosition(targetIndex, in: state) {
                commit(targetIndex: targetIndex, state: &state)
                return .committed
            }
            return .ignored
        }

        commit(targetIndex: targetIndex, state: &state)
        return .committed
    }

    func cancel(sourceIndex: Int, state: inout CollapsiblePagerState) {
        guard state.pageCount > 0, isValid(sourceIndex, in: state) else {
            state.pendingSelectedIndex = nil
            state.pendingPageRequestSource = nil
            state.effectiveSelectedIndex = nil
            state.pagePosition = nil
            return
        }

        state.selectedIndex = sourceIndex
        state.effectiveSelectedIndex = sourceIndex
        state.pendingSelectedIndex = nil
        state.pendingPageRequestSource = nil
        state.pagePosition = PagePosition.make(rawPosition: CGFloat(sourceIndex), pageCount: state.pageCount, isInteractive: false)
    }

    private func commit(targetIndex: Int, state: inout CollapsiblePagerState) {
        state.selectedIndex = targetIndex
        state.effectiveSelectedIndex = targetIndex
        state.pendingSelectedIndex = nil
        state.pendingPageRequestSource = nil
        state.pagePosition = PagePosition.make(rawPosition: CGFloat(targetIndex), pageCount: state.pageCount, isInteractive: false)
    }

    private func isValid(_ index: Int, in state: CollapsiblePagerState) -> Bool {
        (0..<state.pageCount).contains(index)
    }

    private func isSettledPosition(_ index: Int, in state: CollapsiblePagerState) -> Bool {
        guard let position = state.pagePosition,
              position.fromIndex == index,
              position.toIndex == index,
              position.progress == 0,
              !position.isInteractive else {
            return false
        }

        return true
    }

    private func direction(from sourceIndex: Int, to targetIndex: Int) -> PageDirection {
        if targetIndex > sourceIndex {
            return .forward
        } else if targetIndex < sourceIndex {
            return .backward
        } else {
            return .stationary
        }
    }
}
