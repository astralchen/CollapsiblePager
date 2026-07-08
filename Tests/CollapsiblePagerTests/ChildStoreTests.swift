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
    child.scrollView.automaticallyAdjustsScrollIndicatorInsets = true

    let record = try #require(store.makeRecord(for: child, index: 0, managedTopInset: 308))

    #expect(record.viewController === child)
    #expect(record.scrollView.contentInset.top == 308)
    #expect(record.scrollView.verticalScrollIndicatorInsets.top == 308)
    #expect(record.scrollView.automaticallyAdjustsScrollIndicatorInsets == false)
    #expect(record.scrollView.contentInsetAdjustmentBehavior == .never)
    #expect(record.mountView.superview === child.scrollView)
}

@MainActor
@Test func childStoreReplacesStaleBottomScrollIndicatorInset() throws {
    let pager = CollapsiblePagerViewController()
    let store = CollapsiblePagerChildStore(owner: pager)
    let child = ScrollChild()
    child.scrollView.verticalScrollIndicatorInsets.bottom = 160

    let record = try #require(
        store.makeRecord(
            for: child,
            index: 0,
            managedTopInset: 308,
            managedBottomInset: 34
        )
    )

    #expect(child.scrollView.verticalScrollIndicatorInsets.bottom == 34)

    store.updateManagedInset(for: record, managedTopInset: 308, managedBottomInset: 20)
    #expect(child.scrollView.verticalScrollIndicatorInsets.bottom == 20)
}

@MainActor
@Test func childStoreDoesNotRewriteUnchangedContentInsetAfterContentSizeChanges() throws {
    let pager = CollapsiblePagerViewController()
    let store = CollapsiblePagerChildStore(owner: pager)
    let child = InsetTrackingScrollChild()
    child.scrollView.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
    child.scrollView.contentSize = CGSize(width: 390, height: 2_000)

    let record = try #require(
        store.makeRecord(
            for: child,
            index: 0,
            managedTopInset: 308,
            managedBottomInset: 34,
            pinThreshold: 260
        )
    )
    let contentInsetWriteCount = child.scrollView.contentInsetWriteCount

    child.scrollView.contentSize = CGSize(width: 390, height: 2_200)
    store.updateManagedInset(
        for: record,
        managedTopInset: 308,
        managedBottomInset: 34,
        pinThreshold: 260
    )

    #expect(child.scrollView.contentInsetWriteCount == contentInsetWriteCount)
}

@MainActor
@Test func childStorePreservesExternalBottomInsetAddedAfterPagerManagement() throws {
    let pager = CollapsiblePagerViewController()
    let store = CollapsiblePagerChildStore(owner: pager)
    let child = ScrollChild()
    child.scrollView.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
    child.scrollView.contentSize = CGSize(width: 390, height: 2_000)

    let record = try #require(
        store.makeRecord(
            for: child,
            index: 0,
            managedTopInset: 308,
            managedBottomInset: 34,
            pinThreshold: 260
        )
    )
    let externalFooterInset: CGFloat = 44
    child.scrollView.contentInset.bottom += externalFooterInset

    store.updateManagedInset(
        for: record,
        managedTopInset: 308,
        managedBottomInset: 50,
        pinThreshold: 260
    )

    #expect(child.scrollView.contentInset.bottom == 94)
    #expect(child.scrollView.verticalScrollIndicatorInsets.bottom == 50)
}

@MainActor
@Test func childStoreDoesNotAmplifyExternalBottomInsetWhenContentInsetUpdateReenters() throws {
    let pager = CollapsiblePagerViewController()
    let store = CollapsiblePagerChildStore(owner: pager)
    let child = ReentrantInsetScrollChild()
    child.scrollView.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
    child.scrollView.contentSize = CGSize(width: 390, height: 2_000)

    let record = try #require(
        store.makeRecord(
            for: child,
            index: 0,
            managedTopInset: 308,
            managedBottomInset: 34,
            pinThreshold: 260
        )
    )
    child.scrollView.contentInset.bottom += 44

    var didReenter = false
    child.scrollView.onContentInsetSet = {
        guard !didReenter else {
            return
        }
        didReenter = true
        store.updateManagedInset(
            for: record,
            managedTopInset: 308,
            managedBottomInset: 50,
            pinThreshold: 260
        )
    }

    store.updateManagedInset(
        for: record,
        managedTopInset: 308,
        managedBottomInset: 50,
        pinThreshold: 260
    )

    #expect(child.scrollView.contentInset.bottom == 94)
    #expect(record.lastManagedContentInset.bottom == 50)
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

@MainActor
private final class InsetTrackingScrollChild: UIViewController, CollapsiblePagerScrollProviding {
    let scrollView = InsetTrackingScrollView()
    var pagerScrollView: UIScrollView { scrollView }
}

private final class InsetTrackingScrollView: UIScrollView {
    private(set) var contentInsetWriteCount = 0

    override var contentInset: UIEdgeInsets {
        get {
            super.contentInset
        }
        set {
            contentInsetWriteCount += 1
            super.contentInset = newValue
        }
    }
}

@MainActor
private final class ReentrantInsetScrollChild: UIViewController, CollapsiblePagerScrollProviding {
    let scrollView = ReentrantInsetScrollView()
    var pagerScrollView: UIScrollView { scrollView }
}

private final class ReentrantInsetScrollView: UIScrollView {
    var onContentInsetSet: (() -> Void)?

    override var contentInset: UIEdgeInsets {
        get {
            super.contentInset
        }
        set {
            super.contentInset = newValue
            onContentInsetSet?()
        }
    }
}
