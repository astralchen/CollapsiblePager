import Testing
import UIKit
@testable import CollapsiblePager

@MainActor
@Test func childStoreRejectsChildWithoutScrollProvider() {
    let pager = CollapsiblePagerViewController()
    let store = CollapsiblePagerChildStore(owner: pager)
    let child = UIViewController()

    #expect(store.makeRecord(for: child, index: 0, managedTopInset: 308) == nil)
}

@MainActor
@Test func childStoreAppliesManagedInset() throws {
    let pager = CollapsiblePagerViewController()
    let store = CollapsiblePagerChildStore(owner: pager)
    let child = ScrollChild()

    let record = try #require(store.makeRecord(for: child, index: 0, managedTopInset: 308))

    #expect(record.viewController === child)
    #expect(record.scrollView.contentInset.top == 308)
    #expect(record.scrollView.verticalScrollIndicatorInsets.top == 308)
    #expect(record.scrollView.contentInsetAdjustmentBehavior == .never)
    #expect(record.mountView.superview === child.scrollView)
}

@MainActor
@Test func childStoreUsesStandardContainmentWhenAttachingAndDetaching() throws {
    let pager = CollapsiblePagerViewController()
    pager.loadViewIfNeeded()
    let store = CollapsiblePagerChildStore(owner: pager)
    let child = ScrollChild()
    let record = try #require(store.makeRecord(for: child, index: 0, managedTopInset: 308))

    store.attach(record, to: pager.view)
    #expect(child.parent === pager)
    #expect(child.view.superview === pager.view)

    store.detach(record)
    #expect(child.parent == nil)
    #expect(child.view.superview == nil)
}

@MainActor
private final class ScrollChild: UIViewController, CollapsiblePagerScrollProviding {
    let scrollView = UIScrollView()
    var pagerScrollView: UIScrollView { scrollView }
}
