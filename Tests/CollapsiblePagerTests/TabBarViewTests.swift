import Testing
import UIKit
@testable import CollapsiblePager

@MainActor
@Test func tabBarRendersEqualWidthItems() throws {
    let tabBar = CollapsiblePagerTabBarView()
    tabBar.frame = CGRect(x: 0, y: 0, width: 300, height: 48)

    tabBar.reloadTitles(["A", "B", "C"])
    tabBar.layoutIfNeeded()

    #expect(tabBar.itemCount == 3)
    #expect(tabBar.itemView(at: 0)?.frame == CGRect(x: 0, y: 0, width: 100, height: 48))
    #expect(tabBar.itemView(at: 1)?.frame == CGRect(x: 100, y: 0, width: 100, height: 48))
    #expect(tabBar.itemView(at: 2)?.frame == CGRect(x: 200, y: 0, width: 100, height: 48))
}

@MainActor
@Test func tabBarUsesScrollReadyContentAndIndicatorContainers() throws {
    let tabBar = CollapsiblePagerTabBarView()
    tabBar.frame = CGRect(x: 0, y: 0, width: 300, height: 48)

    tabBar.reloadTitles(["A", "B", "C"])
    tabBar.update(position: PagePosition.make(rawPosition: 1, pageCount: 3, isInteractive: false))
    tabBar.layoutIfNeeded()

    #expect(tabBar.contentScrollViewForTesting.superview === tabBar.contentViewForTesting)
    #expect(tabBar.contentScrollViewForTesting.isScrollEnabled == false)
    #expect(tabBar.itemLayoutViewForTesting.superview === tabBar.contentScrollViewForTesting)
    #expect(tabBar.itemView(at: 0)?.superview === tabBar.itemLayoutViewForTesting)
    #expect(tabBar.indicatorContainerViewForTesting.superview === tabBar.itemLayoutViewForTesting)
    #expect(tabBar.indicatorFrame != nil)
}

@MainActor
@Test func tabItemRegistersTouchUpInsideTargetForRealTouches() throws {
    let itemView = CollapsiblePagerTabItemView(title: "Long")

    let actions = try #require(itemView.actions(forTarget: itemView, forControlEvent: .touchUpInside))

    #expect(actions.isEmpty == false)
}

@MainActor
@Test func tabBarTapOnlyEmitsRequest() throws {
    let tabBar = CollapsiblePagerTabBarView()
    tabBar.frame = CGRect(x: 0, y: 0, width: 300, height: 48)
    var requestedIndex: Int?
    tabBar.onRequestSelection = { requestedIndex = $0 }

    tabBar.reloadTitles(["A", "B", "C"])
    tabBar.update(position: PagePosition.make(rawPosition: 0, pageCount: 3, isInteractive: false))
    tabBar.layoutIfNeeded()
    tabBar.itemView(at: 1)?.sendActions(for: .touchUpInside)

    #expect(requestedIndex == 1)
    #expect(tabBar.itemView(at: 0)?.selectionProgress == 1)
    #expect(tabBar.itemView(at: 1)?.selectionProgress == 0)
}

@MainActor
@Test func tabBarSelectedProgressUpdatesItemsAndAccessibility() throws {
    let tabBar = CollapsiblePagerTabBarView()
    tabBar.frame = CGRect(x: 0, y: 0, width: 200, height: 48)

    tabBar.reloadTitles(["A", "B"])
    tabBar.update(position: PagePosition.make(rawPosition: 0.5, pageCount: 2, isInteractive: true))

    #expect(tabBar.itemView(at: 0)?.selectionProgress == 0.5)
    #expect(tabBar.itemView(at: 1)?.selectionProgress == 0.5)
    #expect(tabBar.itemView(at: 0)?.accessibilityTraits.contains(.selected) == false)
    #expect(tabBar.itemView(at: 1)?.accessibilityTraits.contains(.selected) == false)

    tabBar.update(position: PagePosition.make(rawPosition: 1, pageCount: 2, isInteractive: false))

    #expect(tabBar.itemView(at: 0)?.selectionProgress == 0)
    #expect(tabBar.itemView(at: 1)?.selectionProgress == 1)
    #expect(tabBar.itemView(at: 1)?.accessibilityTraits.contains(.selected) == true)
}

@MainActor
@Test func tabItemRelayoutsTitleWhenSelectionFontChanges() throws {
    let itemView = CollapsiblePagerTabItemView(title: "Short")
    itemView.frame = CGRect(x: 0, y: 0, width: 120, height: 48)
    itemView.layoutIfNeeded()
    let regularTitleFrame = itemView.titleFrame(in: itemView)

    itemView.selectionProgress = 1
    itemView.layoutIfNeeded()
    let selectedTitleFrame = itemView.titleFrame(in: itemView)

    #expect(selectedTitleFrame.width > regularTitleFrame.width)
    #expect(selectedTitleFrame.midX == regularTitleFrame.midX)
}

@MainActor
@Test func tabBarIndicatorUsesFocusRect() throws {
    let tabBar = CollapsiblePagerTabBarView()
    tabBar.frame = CGRect(x: 0, y: 0, width: 300, height: 48)

    tabBar.reloadTitles(["A", "B", "C"])
    tabBar.update(position: PagePosition.make(rawPosition: 0.5, pageCount: 3, isInteractive: true))
    tabBar.layoutIfNeeded()

    let indicatorFrame = try #require(tabBar.indicatorFrame)
    #expect(indicatorFrame.width == 28)
    #expect(indicatorFrame.height == 3)
    #expect(indicatorFrame.midX == 100)
    #expect(indicatorFrame.maxY == 48)
}

@MainActor
@Test func tabBarEmptyStateHasNoItemsAndNoIndicator() {
    let tabBar = CollapsiblePagerTabBarView()

    tabBar.reloadTitles([])

    #expect(tabBar.itemCount == 0)
    #expect(tabBar.indicatorFrame == nil)
}
