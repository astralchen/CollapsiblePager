import Testing
@testable import CollapsiblePager

@Test func pageRequestDoesNotCommitUntilCompletion() {
    var state = CollapsiblePagerState.initial(pageCount: 3)
    let pipeline = PageRequestPipeline()

    let accepted = pipeline.request(.init(source: .api, fromIndex: 0, targetIndex: 2, animated: true), state: &state)

    #expect(accepted)
    #expect(state.selectedIndex == 0)
    #expect(state.pendingSelectedIndex == 2)

    pipeline.complete(targetIndex: 2, state: &state)

    #expect(state.selectedIndex == 2)
    #expect(state.effectiveSelectedIndex == 2)
    #expect(state.pendingSelectedIndex == nil)
}

@Test func cancelledPageRequestRollsBackPendingSelection() {
    var state = CollapsiblePagerState.initial(pageCount: 3)
    let pipeline = PageRequestPipeline()

    _ = pipeline.request(.init(source: .gesture, fromIndex: 0, targetIndex: 1, animated: true), state: &state)
    pipeline.cancel(sourceIndex: 0, state: &state)

    #expect(state.selectedIndex == 0)
    #expect(state.effectiveSelectedIndex == 0)
    #expect(state.pendingSelectedIndex == nil)
}

@Test func pageRequestIgnoresEmptyAndOutOfRangeState() {
    var emptyState = CollapsiblePagerState.initial(pageCount: 0)
    var populatedState = CollapsiblePagerState.initial(pageCount: 2)
    let pipeline = PageRequestPipeline()

    #expect(pipeline.request(.init(source: .api, fromIndex: 0, targetIndex: 0, animated: false), state: &emptyState) == false)
    #expect(emptyState.effectiveSelectedIndex == nil)
    #expect(pipeline.request(.init(source: .api, fromIndex: 0, targetIndex: 4, animated: false), state: &populatedState) == false)
    #expect(populatedState.selectedIndex == 0)
    #expect(populatedState.pendingSelectedIndex == nil)
}

@Test func consecutivePageRequestsKeepLastPendingTarget() {
    var state = CollapsiblePagerState.initial(pageCount: 4)
    let pipeline = PageRequestPipeline()

    #expect(pipeline.request(.init(source: .tabTap, fromIndex: 0, targetIndex: 1, animated: false), state: &state))
    #expect(pipeline.request(.init(source: .tabTap, fromIndex: 0, targetIndex: 3, animated: false), state: &state))

    #expect(state.selectedIndex == 0)
    #expect(state.pendingSelectedIndex == 3)

    pipeline.complete(targetIndex: 3, state: &state)

    #expect(state.selectedIndex == 3)
    #expect(state.pendingSelectedIndex == nil)
}

@Test func repeatedRequestToSamePendingTargetKeepsCurrentPagePosition() {
    var state = CollapsiblePagerState.initial(pageCount: 3)
    let pipeline = PageRequestPipeline()

    #expect(pipeline.request(.init(source: .tabTap, fromIndex: 0, targetIndex: 1, animated: true), state: &state))
    let inFlightPosition = PagePosition.make(rawPosition: 0.67, pageCount: 3, isInteractive: false)
    state.pagePosition = inFlightPosition

    #expect(pipeline.request(.init(source: .tabTap, fromIndex: 0, targetIndex: 1, animated: true), state: &state) == false)
    #expect(state.selectedIndex == 0)
    #expect(state.effectiveSelectedIndex == 0)
    #expect(state.pendingSelectedIndex == 1)
    #expect(state.pagePosition == inFlightPosition)
}

@Test func requestBackToCurrentSelectionCancelsPendingTarget() {
    var state = CollapsiblePagerState.initial(pageCount: 3)
    let pipeline = PageRequestPipeline()

    #expect(pipeline.request(.init(source: .tabTap, fromIndex: 0, targetIndex: 1, animated: true), state: &state))
    #expect(pipeline.request(.init(source: .tabTap, fromIndex: 0, targetIndex: 0, animated: true), state: &state))

    #expect(state.selectedIndex == 0)
    #expect(state.effectiveSelectedIndex == 0)
    #expect(state.pendingSelectedIndex == nil)
    #expect(state.pendingPageRequestSource == nil)
    #expect(state.pagePosition == PagePosition.make(rawPosition: 0, pageCount: 3, isInteractive: false))
}

@Test func staleTransitionCompletionDoesNotCommitSupersededTarget() {
    var state = CollapsiblePagerState.initial(pageCount: 3)
    let pipeline = PageRequestPipeline()

    #expect(pipeline.request(.init(source: .tabTap, fromIndex: 0, targetIndex: 1, animated: true), state: &state))
    #expect(pipeline.request(.init(source: .tabTap, fromIndex: 0, targetIndex: 2, animated: true), state: &state))

    pipeline.complete(targetIndex: 1, state: &state)

    #expect(state.selectedIndex == 0)
    #expect(state.effectiveSelectedIndex == 0)
    #expect(state.pendingSelectedIndex == 2)
}

@Test func gestureCompletionCommitsSettledIntermediatePageAfterOvershootingPendingTarget() {
    var state = CollapsiblePagerState.initial(pageCount: 3)
    state.selectedIndex = 2
    state.effectiveSelectedIndex = 2
    state.pagePosition = PagePosition.make(rawPosition: 2, pageCount: 3, isInteractive: false)
    let pipeline = PageRequestPipeline()

    #expect(pipeline.request(.init(source: .gesture, fromIndex: 2, targetIndex: 1, animated: true), state: &state))
    #expect(pipeline.request(.init(source: .gesture, fromIndex: 2, targetIndex: 0, animated: true), state: &state))
    state.pagePosition = PagePosition.make(rawPosition: 1, pageCount: 3, isInteractive: false)

    let result = pipeline.complete(targetIndex: 1, state: &state)

    #expect(result == .committed)
    #expect(state.selectedIndex == 1)
    #expect(state.effectiveSelectedIndex == 1)
    #expect(state.pendingSelectedIndex == nil)
}
