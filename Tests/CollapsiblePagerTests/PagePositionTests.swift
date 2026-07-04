import CoreGraphics
import Testing
@testable import CollapsiblePager

@Test func pagePositionIsNilWhenPageCountIsZero() {
    #expect(PagePosition.make(rawPosition: 0, pageCount: 0, isInteractive: false) == nil)
}

@Test func pagePositionInterpolatesForward() throws {
    let position = try #require(PagePosition.make(rawPosition: 1.25, pageCount: 4, isInteractive: true))

    #expect(position.fromIndex == 1)
    #expect(position.toIndex == 2)
    #expect(position.progress == 0.25)
    #expect(position.direction == .forward)
    #expect(position.isInteractive)
}

@Test func pagePositionClampsRawPositionIntoValidRange() throws {
    let belowRange = try #require(PagePosition.make(rawPosition: -1, pageCount: 3, isInteractive: false))
    let aboveRange = try #require(PagePosition.make(rawPosition: 8, pageCount: 3, isInteractive: false))

    #expect(belowRange.rawPosition == 0)
    #expect(belowRange.fromIndex == 0)
    #expect(belowRange.toIndex == 0)
    #expect(belowRange.direction == .stationary)
    #expect(aboveRange.rawPosition == 2)
    #expect(aboveRange.fromIndex == 2)
    #expect(aboveRange.toIndex == 2)
    #expect(aboveRange.direction == .stationary)
}
