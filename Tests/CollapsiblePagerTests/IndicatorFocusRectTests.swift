import CoreGraphics
import Testing
@testable import CollapsiblePager

@Test func focusRectInterpolatesBetweenItems() throws {
    let itemFrames = [
        CGRect(x: 0, y: 0, width: 100, height: 48),
        CGRect(x: 100, y: 0, width: 140, height: 48),
    ]
    let titleFrames = [
        CGRect(x: 30, y: 14, width: 40, height: 20),
        CGRect(x: 145, y: 14, width: 50, height: 20),
    ]
    let position = PagePosition(
        rawPosition: 0.5,
        fromIndex: 0,
        toIndex: 1,
        progress: 0.5,
        direction: .forward,
        isInteractive: true
    )

    let focusRect = try #require(IndicatorFocusRect.make(itemFrames: itemFrames, titleFrames: titleFrames, position: position))
    let indicator = focusRect.indicatorFrame(widthMode: .fixed(28), height: 3, bottomInset: 0)

    #expect(focusRect.itemFrame.midX == 110)
    #expect(indicator.width == 28)
    #expect(indicator.midX == 110)
}

@Test func indicatorFrameSupportsTitleItemAndRatioWidths() throws {
    let focusRect = IndicatorFocusRect(
        itemFrame: CGRect(x: 20, y: 0, width: 120, height: 48),
        titleFrame: CGRect(x: 55, y: 14, width: 50, height: 20)
    )

    #expect(focusRect.indicatorFrame(widthMode: .title, height: 3, bottomInset: 4).width == 50)
    #expect(focusRect.indicatorFrame(widthMode: .item, height: 3, bottomInset: 4).width == 120)
    #expect(focusRect.indicatorFrame(widthMode: .ratio(0.5), height: 3, bottomInset: 4).width == 60)
    #expect(focusRect.indicatorFrame(widthMode: .fixed(28), height: 3, bottomInset: 4).maxY == 44)
}
