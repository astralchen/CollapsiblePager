import Testing
import UIKit
@testable import CollapsiblePager

@MainActor
@Test func pagerStartsWithPublicSelectedIndexZeroAndNoEffectiveSelection() {
    let pager = CollapsiblePagerViewController()

    #expect(pager.selectedIndex == 0)
    #expect(pager.effectiveSelectedIndex == nil)
}

@MainActor
@Test func defaultConfigurationMatchesV1Defaults() {
    let configuration = CollapsiblePagerConfiguration.default

    if case let .fixed(max, min) = configuration.header.heightMode {
        #expect(max == 260)
        #expect(min == 0)
    } else {
        Issue.record("Default Header height mode should be fixed.")
    }
    #expect(configuration.header.topBehavior == .insideSafeArea)

    #expect(configuration.tabBar.height == 48)
    #expect(configuration.tabBar.placement == .belowHeader)
    #expect(configuration.tabBar.pinning == .pinBelowNavigationBar(offset: 0))
    #expect(configuration.refreshHandoffMode == .container)
    #expect(configuration.headerPullDownRefreshBehavior == .allowsChildRefresh)
    #expect(configuration.paging.allowsSwipeToChangePage)
    #expect(configuration.paging.bouncesHorizontally)
}

@MainActor
@Test func childOnlyProvidesScrollViewForCoordination() {
    final class Child: UIViewController, CollapsiblePagerScrollProviding {
        let scrollView = UIScrollView()
        var pagerScrollView: UIScrollView { scrollView }
    }

    let child = Child()
    let provider: any CollapsiblePagerScrollProviding = child

    #expect(provider.pagerScrollView === child.scrollView)
}

@MainActor
@Test func containerRefreshHostIsContainerOwnedVerticalScrollHost() {
    let pager = CollapsiblePagerViewController()

    let host = pager.containerRefreshHostScrollView

    #expect(host.superview === pager.view)
    #expect(host.alwaysBounceVertical)
    #expect(host.alwaysBounceHorizontal == false)
}
