import Testing
@testable import CollapsiblePager

@Test func pinAnchorReportsDeltaOnlyWhenValueChanges() {
    var anchor = PinAnchor(value: 0)

    #expect(anchor.update(to: 20) == 20)
    #expect(anchor.update(to: 20) == 0)
    #expect(anchor.update(to: 5) == -15)
}
