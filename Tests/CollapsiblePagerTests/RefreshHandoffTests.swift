import Testing
@testable import CollapsiblePager

@Test func refreshHandoffRequiresExpandedHeaderAndTopChild() {
    var coordinator = RefreshHandoffCoordinator(mode: .child)

    #expect(coordinator.tryBeginHandoff(headerIsExpanded: false, childIsAtTop: true, index: 0) == nil)
    #expect(coordinator.tryBeginHandoff(headerIsExpanded: true, childIsAtTop: false, index: 0) == nil)
    #expect(coordinator.tryBeginHandoff(headerIsExpanded: true, childIsAtTop: true, index: 0) == .childScrollView(index: 0))
}

@Test func refreshHandoffOnlyBeginsOncePerGesture() {
    var coordinator = RefreshHandoffCoordinator(mode: .container)

    let first = coordinator.tryBeginHandoff(headerIsExpanded: true, childIsAtTop: true, index: 1)
    coordinator.mode = .child
    let second = coordinator.tryBeginHandoff(headerIsExpanded: true, childIsAtTop: true, index: 1)

    #expect(first == .containerHost(index: 1))
    #expect(second == nil)
}

@Test func refreshHandoffNoneModeNeverBegins() {
    var coordinator = RefreshHandoffCoordinator(mode: .none)

    #expect(coordinator.tryBeginHandoff(headerIsExpanded: true, childIsAtTop: true, index: 0) == nil)
}

@Test func refreshHandoffResetAllowsNextGesture() {
    var coordinator = RefreshHandoffCoordinator(mode: .container)

    let first = coordinator.tryBeginHandoff(headerIsExpanded: true, childIsAtTop: true, index: 0)
    coordinator.resetGesture()
    let second = coordinator.tryBeginHandoff(headerIsExpanded: true, childIsAtTop: true, index: 0)

    #expect(first == .containerHost(index: 0))
    #expect(second == .containerHost(index: 0))
}

@Test func refreshHandoffReportsActiveScope() {
    var coordinator = RefreshHandoffCoordinator(mode: .child)

    _ = coordinator.tryBeginHandoff(headerIsExpanded: true, childIsAtTop: true, index: 2)

    #expect(coordinator.activeHandoff == .childScrollView(index: 2))
}
