# CollapsiblePager V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付第一版通用 UIKit `CollapsiblePager`：可折叠 Header、默认 TabBar、横向分页、滚动协调、刷新仲裁和示例 App 验收链路。

**Architecture:** 公开容器 `CollapsiblePagerViewController` 只编排 data source、delegate、child containment 和内部协调器。纵向状态以 `pinAnchorY` 和 layout engine 输出为唯一锚点，Header/TabBar 视觉宿主在 child mount 与 fixed overlay 之间迁移，Tab 点击、API 选择和横向拖拽统一进入 page request pipeline。

**Tech Stack:** Swift 6.2 package、UIKit、Swift Testing、XCTest UI Tests、iOS 13。

---

## Scope Decisions

- 第一版按 `docs/requirements-and-architecture.md` 第 12 节和 `docs/ui-design-and-animation-dsl.md` 第 11 节的保守范围执行：`belowHeader`、导航栏/安全区吸顶、默认等宽文本 TabBar、默认短下划线指示器、`fixed`/`automatic` Header 高度、`.none`/`.overall`/`.child` 刷新、`reloadHeaderLayout(.immediate, .preserveVisualPosition)`。
- `overlayHeaderBottom(offset:)` 在需求第 5.3 节被描述为“第一版可以优先实现”，但在第一版交付范围中被列到第二阶段。本计划将其作为第二阶段任务，先保证默认路径稳定。
- 第一版不实现可横向滚动 TabBar、自定义指示器公开实现、自定义 Header 高度 provider、自定义 TabBar layout provider、Header 下拉拉伸和 Header 布局刷新动画。
- 按仓库 AGENTS 约定，执行计划时只有用户明确要求才 `git add` / `git commit` / `git push`。任务中的提交点只作为拆分建议。

## File Structure

### Core Library

- Create: `Sources/CollapsiblePager/Public/CollapsiblePagerViewController.swift`
  公开容器，承接 `reloadData()`、`selectPage(at:animated:)`、`reloadHeaderLayout(...)`、`endRefreshing()`。
- Create: `Sources/CollapsiblePager/Public/CollapsiblePagerDataSource.swift`
  `CollapsiblePagerHeaderContent`、`CollapsiblePagerDataSource`。
- Create: `Sources/CollapsiblePager/Public/CollapsiblePagerDelegate.swift`
  `CollapsiblePagerDelegate` 和默认空实现。
- Create: `Sources/CollapsiblePager/Public/CollapsiblePagerConfiguration.swift`
  Header、TabBar、Indicator、Paging、Refresh 配置和值类型默认值。
- Create: `Sources/CollapsiblePager/Public/CollapsiblePagerProtocols.swift`
  `CollapsiblePagerScrollProviding`、`CollapsiblePagerRefreshableChild`、保留扩展协议。
- Create: `Sources/CollapsiblePager/Public/CollapsiblePagerLayoutContext.swift`
  公开 layout context，供 delegate 和 provider 使用。
- Create: `Sources/CollapsiblePager/Layout/CollapsiblePagerLayoutEngine.swift`
  纯计算布局引擎。
- Create: `Sources/CollapsiblePager/Layout/CollapsiblePagerLayoutModels.swift`
  布局输入、输出、offset policy、clamp helpers。
- Create: `Sources/CollapsiblePager/Header/CollapsiblePagerHeaderHostView.swift`
  Header view/controller 包装、Auto Layout 测量、collapse progress 分发。
- Create: `Sources/CollapsiblePager/Header/CollapsiblePagerHeaderMountView.swift`
  每个 child scroll view 顶部 inset 区域的挂载点。
- Create: `Sources/CollapsiblePager/Header/CollapsiblePagerFixedHeaderContainer.swift`
  吸顶、横向切页、刷新 reveal、布局刷新期间的 fixed overlay。
- Create: `Sources/CollapsiblePager/TabBar/CollapsiblePagerTabBar.swift`
  默认等宽文本 TabBar、accessibility selected 状态、点击转发。
- Create: `Sources/CollapsiblePager/TabBar/CollapsiblePagerTabIndicator.swift`
  默认下划线指示器和 focus rect 计算。
- Create: `Sources/CollapsiblePager/Paging/CollapsiblePagerPageContainer.swift`
  内部 paging `UIScrollView`、child containment、page request pipeline。
- Create: `Sources/CollapsiblePager/Paging/CollapsiblePagerPagePosition.swift`
  `PagePosition`、direction、raw offset 转换。
- Create: `Sources/CollapsiblePager/Scroll/CollapsiblePagerPinAnchor.swift`
  `pinAnchorY` 状态和值语义更新。
- Create: `Sources/CollapsiblePager/Scroll/CollapsiblePagerScrollCoordinator.swift`
  纵向滚动状态机、guarded offset update、非当前 child offset 修正。
- Create: `Sources/CollapsiblePager/Refresh/CollapsiblePagerRefreshCoordinator.swift`
  刷新资格判断、唯一 owner、结束刷新。
- Create: `Sources/CollapsiblePager/Gesture/CollapsiblePagerGestureArbiter.swift`
  横向分页、纵向滚动和导航返回手势优先级。
- Replace: `Sources/CollapsiblePager/CollapsiblePager.swift`
  改成模块导出占位或移除骨架注释。

### Tests

- Create: `Tests/CollapsiblePagerTests/LayoutEngineTests.swift`
- Create: `Tests/CollapsiblePagerTests/HeaderHeightTests.swift`
- Create: `Tests/CollapsiblePagerTests/TabIndicatorTests.swift`
- Create: `Tests/CollapsiblePagerTests/PagePositionTests.swift`
- Create: `Tests/CollapsiblePagerTests/RefreshCoordinatorTests.swift`
- Create: `Tests/CollapsiblePagerTests/ScrollCoordinatorTests.swift`
- Create: `Tests/CollapsiblePagerTests/ContainerLifecycleTests.swift`
- Replace: `Tests/CollapsiblePagerTests/CollapsiblePagerTests.swift`
  移除模板测试或改为 smoke test。

### Example App And UI Tests

- Modify: `Examples/Examples.xcodeproj/project.pbxproj`
  将 local package product `CollapsiblePager` 连接到 Examples target。
- Modify: `Examples/Examples/ViewController.swift`
  加载 demo pager，支持 launch arguments 切换场景。
- Create: `Examples/Examples/DemoPagerFactory.swift`
- Create: `Examples/Examples/DemoHeaderView.swift`
- Create: `Examples/Examples/DemoListViewController.swift`
- Create: `Examples/Examples/DemoAccessibility.swift`
- Replace: `Examples/ExamplesUITests/ExamplesUITests.swift`
  加入必要 UI 测试。

## Task 1: Public API And Defaults

**Files:**
- Create: `Sources/CollapsiblePager/Public/CollapsiblePagerConfiguration.swift`
- Create: `Sources/CollapsiblePager/Public/CollapsiblePagerDataSource.swift`
- Create: `Sources/CollapsiblePager/Public/CollapsiblePagerDelegate.swift`
- Create: `Sources/CollapsiblePager/Public/CollapsiblePagerProtocols.swift`
- Create: `Sources/CollapsiblePager/Public/CollapsiblePagerLayoutContext.swift`
- Create: `Tests/CollapsiblePagerTests/PublicAPITests.swift`

**Acceptance Criteria:**
- 所有 UIKit 入口、data source、delegate、协议和公开容器 API 标注 `@MainActor`。
- 默认配置匹配文档推荐值：Header `fixed(max: 260, min: 0)`、TabBar `48`、`.belowHeader`、`.pinBelowNavigationBar(offset: 0)`、指示器 fixed `28`、分页动画 `0.28`、刷新 `.none`。
- 第一版公开 API 不包含 `animated` header reload behavior、横向滚动 TabBar、自定义 Header 高度 provider 的实现路径。

- [ ] **Step 1: Write failing default configuration tests**

```swift
import Testing
import UIKit
@testable import CollapsiblePager

@MainActor
@Test func defaultConfigurationMatchesV1Defaults() {
    let configuration = CollapsiblePagerConfiguration.default

    if case let .fixed(max, min) = configuration.header.heightMode {
        #expect(max == 260)
        #expect(min == 0)
    } else {
        Issue.record("Default header height mode must be fixed.")
    }

    #expect(configuration.tabBar.height == 48)
    #expect(configuration.tabBar.placement == .belowHeader)
    #expect(configuration.tabBar.pinning == .pinBelowNavigationBar(offset: 0))
    #expect(configuration.refreshMode == .none)
    #expect(configuration.paging.allowsSwipeToChangePage)
    #expect(configuration.paging.bouncesHorizontally == false)
    #expect(configuration.paging.tabTapAnimationDuration == 0.28)
}
```

- [ ] **Step 2: Add public types and DocC comments**

Implement the public symbols from docs section 7 and 8 with concise Chinese DocC comments. Keep configuration as value types, and mark closures that touch UIKit as `@MainActor`.

- [ ] **Step 3: Run package tests**

Run: `swift test`

Expected: default configuration test passes and no Swift 6 concurrency warning is introduced.

## Task 2: Layout Engine

**Files:**
- Create: `Sources/CollapsiblePager/Layout/CollapsiblePagerLayoutModels.swift`
- Create: `Sources/CollapsiblePager/Layout/CollapsiblePagerLayoutEngine.swift`
- Create: `Tests/CollapsiblePagerTests/LayoutEngineTests.swift`

**Acceptance Criteria:**
- Layout engine is pure value calculation and does not store UIKit objects.
- It clamps invalid Header heights so `maxHeight >= minHeight >= 0`.
- It outputs Header frame, visible height, collapse progress, TabBar frame, pin Y, pin threshold, page container frame, child content inset and offset correction.
- Safe area and navigation bar pinning share the same path as rotation and Dynamic Type invalidation.

- [ ] **Step 1: Write failing layout tests**

```swift
import CoreGraphics
import Testing
@testable import CollapsiblePager

@Test func belowHeaderExpandedLayoutMatchesDefaultDSL() {
    let input = CollapsiblePagerLayoutInput(
        containerBounds: CGRect(x: 0, y: 0, width: 390, height: 844),
        safeAreaInsets: .init(top: 47, left: 0, bottom: 34, right: 0),
        navigationBarMaxY: 91,
        headerHeights: .init(maxHeight: 260, minHeight: 0),
        tabBarHeight: 48,
        tabBarPlacement: .belowHeader,
        tabBarPinning: .pinBelowNavigationBar(offset: 0),
        pinAnchorY: 0
    )

    let output = CollapsiblePagerLayoutEngine().layout(input)

    #expect(output.headerVisibleHeight == 260)
    #expect(output.collapseProgress == 0)
    #expect(output.tabBarFrame == CGRect(x: 0, y: 260, width: 390, height: 48))
    #expect(output.pinY == 91)
    #expect(output.childContentInset.top == 308)
}

@Test func pinnedLayoutKeepsTabBarAtPinY() {
    var input = CollapsiblePagerLayoutInput.defaultTestValue
    input.pinAnchorY = input.headerHeights.maxHeight

    let output = CollapsiblePagerLayoutEngine().layout(input)

    #expect(output.headerVisibleHeight == 0)
    #expect(output.collapseProgress == 1)
    #expect(output.tabBarFrame.minY == output.pinY)
}
```

- [ ] **Step 2: Implement layout models and engine**

Use explicit `CollapsiblePagerLayoutInput` and `CollapsiblePagerLayoutOutput` structs. Keep `CGFloat` calculations clamped and deterministic.

- [ ] **Step 3: Add offset policy tests**

Cover `.preserveVisualPosition`, `.preserveCollapseProgress`, `.resetToExpanded`, `.resetToCollapsed` for header height changes in expanded, pinned and partially collapsed states.

- [ ] **Step 4: Run layout-focused tests**

Run: `swift test --filter LayoutEngineTests`

Expected: all layout tests pass.

## Task 3: Header Host, Measurement And Containment

**Files:**
- Create: `Sources/CollapsiblePager/Header/CollapsiblePagerHeaderHostView.swift`
- Create: `Sources/CollapsiblePager/Header/CollapsiblePagerHeaderMountView.swift`
- Create: `Sources/CollapsiblePager/Header/CollapsiblePagerFixedHeaderContainer.swift`
- Create: `Tests/CollapsiblePagerTests/HeaderHeightTests.swift`
- Create: `Tests/CollapsiblePagerTests/ContainerLifecycleTests.swift`

**Acceptance Criteria:**
- Header accepts both `UIView` and `UIViewController`.
- Header controller containment is added once under pager and is not re-added during visual host migration.
- Replacing header content removes old controller with `willMove(toParent: nil)` and `removeFromParent()`.
- Automatic height uses Auto Layout measurement and supports estimated first layout.
- Collapse progress is emitted in `0...1`.

- [ ] **Step 1: Write failing containment tests**

```swift
import Testing
import UIKit
@testable import CollapsiblePager

@MainActor
@Test func headerViewControllerContainmentSurvivesHostMigration() {
    let pager = CollapsiblePagerViewController()
    let header = UIViewController()

    pager.mountHeaderForTesting(.viewController(header))
    #expect(header.parent === pager)

    pager.moveHeaderHostToFixedOverlayForTesting(reason: .horizontalPaging)
    #expect(header.parent === pager)

    pager.moveHeaderHostToCurrentChildMountForTesting()
    #expect(header.parent === pager)
}
```

- [ ] **Step 2: Implement host and mount views**

Create host view APIs that can move the hosted visual view between `CollapsiblePagerHeaderMountView` and `CollapsiblePagerFixedHeaderContainer` without changing controller containment.

- [ ] **Step 3: Add automatic height measurement tests**

Use a test header view with a label constrained to all edges. Verify width-sensitive height changes after text changes and `reloadHeaderLayout`.

- [ ] **Step 4: Run header tests**

Run: `swift test --filter HeaderHeightTests`

Expected: measurement and containment tests pass without UIKit lifecycle assertions.

## Task 4: TabBar And Indicator

**Files:**
- Create: `Sources/CollapsiblePager/TabBar/CollapsiblePagerTabBar.swift`
- Create: `Sources/CollapsiblePager/TabBar/CollapsiblePagerTabIndicator.swift`
- Create: `Tests/CollapsiblePagerTests/TabIndicatorTests.swift`

**Acceptance Criteria:**
- Default TabBar renders equal-width text items.
- Tab item selected state is reflected through accessibility traits, not only indicator.
- Indicator frame is derived from focus rect and width mode.
- Tap only emits selection request; TabBar does not mutate child or vertical state.
- Ongoing tap indicator animation can be interrupted by a newer target.

- [ ] **Step 1: Write failing indicator frame tests**

```swift
import CoreGraphics
import Testing
@testable import CollapsiblePager

@Test func fixedUnderlineIndicatorUsesItemCenter() {
    let itemFrames = [
        CGRect(x: 0, y: 0, width: 130, height: 48),
        CGRect(x: 130, y: 0, width: 130, height: 48)
    ]

    let frame = CollapsiblePagerTabIndicatorLayout.frame(
        widthMode: .fixed(28),
        height: 3,
        bottomInset: 0,
        itemFrames: itemFrames,
        titleFrames: itemFrames,
        tabBarBounds: CGRect(x: 0, y: 0, width: 260, height: 48),
        position: .init(rawPosition: 0.5, fromIndex: 0, toIndex: 1, progress: 0.5, direction: .forward, isInteractive: true, isCancelled: false)
    )

    #expect(frame.width == 28)
    #expect(frame.height == 3)
    #expect(frame.midX == 130)
    #expect(frame.maxY == 48)
}
```

- [ ] **Step 2: Implement TabBar rendering**

Use `UIButton` or `UIControl` subclasses with `accessibilityIdentifier` hooks and selected accessibility traits. Store titles and layout frames as values.

- [ ] **Step 3: Implement indicator layout and animation coordination**

Keep selection logic outside indicator. Indicator consumes `PagePosition` and item/title frames.

- [ ] **Step 4: Run tab tests**

Run: `swift test --filter TabIndicatorTests`

Expected: fixed, title, item and ratio width modes pass.

## Task 5: Page Container And Page Request Pipeline

**Files:**
- Create: `Sources/CollapsiblePager/Paging/CollapsiblePagerPagePosition.swift`
- Create: `Sources/CollapsiblePager/Paging/CollapsiblePagerPageContainer.swift`
- Create: `Tests/CollapsiblePagerTests/PagePositionTests.swift`
- Create: `Tests/CollapsiblePagerTests/ContainerLifecycleTests.swift`

**Acceptance Criteria:**
- Internal `UIScrollView` uses paging and no third-party pager.
- `PagePosition` includes raw position, from/to index, progress, direction, interactive flag and cancellation flag.
- Tap, API and gesture requests share one pipeline and commit selected index only after completion.
- Cancelled horizontal drag restores selected index and indicator state.
- Consecutive programmatic requests settle on the latest target.

- [ ] **Step 1: Write failing page position tests**

```swift
import Testing
@testable import CollapsiblePager

@Test func pagePositionTracksForwardProgress() {
    let position = CollapsiblePagerPagePosition(rawPosition: 1.25, pageCount: 4, selectedIndex: 1, isInteractive: true)

    #expect(position.fromIndex == 1)
    #expect(position.toIndex == 2)
    #expect(position.progress == 0.25)
    #expect(position.direction == .forward)
}

@Test func pagePositionClampsAtBounds() {
    let position = CollapsiblePagerPagePosition(rawPosition: -0.4, pageCount: 3, selectedIndex: 0, isInteractive: true)

    #expect(position.rawPosition == 0)
    #expect(position.fromIndex == 0)
    #expect(position.toIndex == 0)
    #expect(position.direction == .none)
}
```

- [ ] **Step 2: Implement page position value type**

Make floating point tolerance explicit for completion checks.

- [ ] **Step 3: Implement page container**

Use standard view controller containment for all loaded pages. Keep source enum values `.tap`, `.api`, `.gesture` internal.

- [ ] **Step 4: Add lifecycle tests**

Assert child `parent`, `didMove`, view hierarchy and selected index commit behavior.

- [ ] **Step 5: Run paging tests**

Run: `swift test --filter PagePositionTests`

Expected: position, clamp and commit tests pass.

## Task 6: Scroll Coordinator And Pin Anchor

**Files:**
- Create: `Sources/CollapsiblePager/Scroll/CollapsiblePagerPinAnchor.swift`
- Create: `Sources/CollapsiblePager/Scroll/CollapsiblePagerScrollCoordinator.swift`
- Create: `Tests/CollapsiblePagerTests/ScrollCoordinatorTests.swift`

**Acceptance Criteria:**
- Upward scroll collapses Header before child consumes remaining delta.
- Downward scroll returns child to top before expanding Header.
- Non-current child offset sync is based on `pinAnchorY` delta, not current child rebound offset.
- Guarded content offset updates do not recursively re-enter coordinator.
- Horizontal paging and layout reload phases freeze or ignore vertical observer callbacks.

- [ ] **Step 1: Write failing pin anchor tests**

```swift
import Testing
@testable import CollapsiblePager

@Test func upwardDeltaCollapsesHeaderBeforeChildConsumesScroll() {
    var state = CollapsiblePagerScrollState.expandedTestValue(headerMaxHeight: 260)
    let result = CollapsiblePagerScrollCoordinator.reduce(state: &state, event: .userVerticalDelta(80))

    #expect(state.pinAnchorY == 80)
    #expect(state.headerVisibleHeight == 180)
    #expect(result.childDeltaY == 0)
}

@Test func topBounceDoesNotPropagatePinAnchorDelta() {
    var state = CollapsiblePagerScrollState.pinnedTestValue()
    state.currentChildTopBounceY = -36

    let result = CollapsiblePagerScrollCoordinator.reduce(state: &state, event: .topBounceChanged(-60))

    #expect(result.nonCurrentChildOffsetCorrections.isEmpty)
}
```

- [ ] **Step 2: Implement reducer-style core**

Keep reducer inputs as values for Swift Testing. Apply UIKit `contentOffset` writes only in a thin `@MainActor` adapter with guarded update flags.

- [ ] **Step 3: Add integration hooks**

Wire current child `pagerScrollView` observation and ensure non-current pages only receive layout/inset corrections.

- [ ] **Step 4: Run scroll tests**

Run: `swift test --filter ScrollCoordinatorTests`

Expected: collapse, expand, pin, rebound and guarded update cases pass.

## Task 7: Refresh Coordinator

**Files:**
- Create: `Sources/CollapsiblePager/Refresh/CollapsiblePagerRefreshCoordinator.swift`
- Create: `Tests/CollapsiblePagerTests/RefreshCoordinatorTests.swift`

**Acceptance Criteria:**
- Refresh trigger requires Header fully expanded, child at top, no active owner and refresh mode allowed.
- `.overall` calls pager delegate and sets owner `.pager`.
- `.child` only triggers if current child conforms to `CollapsiblePagerRefreshableChild`.
- `.overall` and `.child` never trigger in the same gesture.
- `endRefreshing()` only ends pager-level owner; child owner remains child-managed.
- Short and empty content can bounce enough to reveal refresh when mode allows.

- [ ] **Step 1: Write failing refresh eligibility tests**

```swift
import Testing
@testable import CollapsiblePager

@Test func refreshIsBlockedUntilHeaderFullyExpanded() {
    let context = CollapsiblePagerRefreshContext(
        refreshMode: .overall,
        headerVisibleHeight: 120,
        headerMaxHeight: 260,
        isCurrentChildAtTop: true,
        activeOwner: nil,
        currentChildSupportsRefresh: true
    )

    #expect(CollapsiblePagerRefreshCoordinator.canBeginRefresh(context) == false)
}

@Test func childModeDoesNotFallbackToOverall() {
    let context = CollapsiblePagerRefreshContext(
        refreshMode: .child,
        headerVisibleHeight: 260,
        headerMaxHeight: 260,
        isCurrentChildAtTop: true,
        activeOwner: nil,
        currentChildSupportsRefresh: false
    )

    #expect(CollapsiblePagerRefreshCoordinator.beginOwnerIfPossible(context) == nil)
}
```

- [ ] **Step 2: Implement refresh owner state**

Use an internal `RefreshOwner` enum with `.pager` and `.child(index:)`. Do not create a public custom coordinator path in V1.

- [ ] **Step 3: Wire UIRefreshControl**

Attach visual refresh control to the current child scroll view with inset compensation for `.overall`. For `.child`, call child protocol and leave ending to child.

- [ ] **Step 4: Run refresh tests**

Run: `swift test --filter RefreshCoordinatorTests`

Expected: owner exclusivity and trigger priority cases pass.

## Task 8: CollapsiblePagerViewController Integration

**Files:**
- Create: `Sources/CollapsiblePager/Public/CollapsiblePagerViewController.swift`
- Replace: `Sources/CollapsiblePager/CollapsiblePager.swift`
- Update all internal files from Tasks 2-7.
- Create: `Tests/CollapsiblePagerTests/ContainerIntegrationTests.swift`

**Acceptance Criteria:**
- `reloadData()` requests header, titles and child controllers from data source and clamps selected index after page count changes.
- `selectPage(at:animated:)` validates index, routes through page container and notifies delegate only after commit.
- `reloadHeaderLayout(behavior: .immediate, offsetPolicy: .preserveVisualPosition)` recomputes Header, TabBar, pin threshold, child inset and offset corrections without visible jump.
- Header layout requests during drag, deceleration, horizontal paging or refresh are marked dirty and applied at idle internally.
- `endRefreshing()` affects only pager refresh owner.

- [ ] **Step 1: Write failing integration tests**

```swift
import Testing
import UIKit
@testable import CollapsiblePager

@MainActor
@Test func reloadDataClampsSelectedIndexWhenPageCountShrinks() {
    let dataSource = PagerDataSourceStub(pageCount: 3)
    let pager = CollapsiblePagerViewController()
    pager.dataSource = dataSource
    pager.reloadData()
    pager.selectPage(at: 2, animated: false)

    dataSource.pageCount = 1
    pager.reloadData()

    #expect(pager.selectedIndex == 0)
}
```

- [ ] **Step 2: Implement root container and wiring**

Create root view hierarchy with page container behind fixed header container. Keep all UIKit work on `@MainActor`.

- [ ] **Step 3: Implement public methods**

Make invalid index selection a no-op with assertion in debug builds. Keep delegate notifications deterministic.

- [ ] **Step 4: Run full package tests**

Run: `swift test`

Expected: all core tests pass.

## Task 9: Example App Scenario Harness

**Files:**
- Modify: `Examples/Examples.xcodeproj/project.pbxproj`
- Modify: `Examples/Examples/ViewController.swift`
- Create: `Examples/Examples/DemoPagerFactory.swift`
- Create: `Examples/Examples/DemoHeaderView.swift`
- Create: `Examples/Examples/DemoListViewController.swift`
- Create: `Examples/Examples/DemoAccessibility.swift`
- Update: `Examples/ExamplesTests/ExamplesTests.swift`

**Acceptance Criteria:**
- Example app launches directly into a working pager, not a marketing or placeholder screen.
- Launch arguments select scenarios: default, overall refresh, child refresh, short content, empty content, dynamic header.
- Demo views expose stable accessibility identifiers for UI tests.
- Demo content remains business-like sample UI but core package contains no profile-specific business types.

- [ ] **Step 1: Add accessibility id contract**

```swift
enum DemoAccessibility {
    static let pagerRoot = "pager.root"
    static let header = "pager.header"
    static let tabBar = "pager.tabbar"
    static func tab(_ index: Int) -> String { "pager.tab.\(index)" }
    static let indicator = "pager.indicator"
    static func pageScroll(_ index: Int) -> String { "pager.page.\(index).scroll" }
    static let selectedPageLabel = "demo.selectedPage"
    static let collapseProgressLabel = "demo.collapseProgress"
    static let refreshCountLabel = "demo.refreshCount"
}
```

- [ ] **Step 2: Build demo pager**

Use three pages with deterministic row labels. Set child scroll accessibility ids. Add one short-content page and one empty-content scenario for refresh checks.

- [ ] **Step 3: Add launch argument routing**

Support `-CollapsiblePagerScenario default|overallRefresh|childRefresh|shortContent|emptyContent|dynamicHeader`.

- [ ] **Step 4: Build example app**

Run: `xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' build`

Expected: app builds on iOS Simulator destination.

## Task 10: Necessary UI Tests

**Files:**
- Replace: `Examples/ExamplesUITests/ExamplesUITests.swift`
- Keep: `Examples/ExamplesUITests/ExamplesUITestsLaunchTests.swift`

**Acceptance Criteria:**
- UI tests validate real gesture behavior that unit tests cannot prove: Header pinning, refresh priority, Tab switching, scroll position preservation and latest-target commit.
- UI tests use accessibility identifiers and visible labels instead of pixel-perfect screenshots.
- Flaky gesture cases such as cancelled horizontal pan and top rebound page switch remain manual QA unless a deterministic XCTest gesture can be introduced.

- [ ] **Step 1: Add launch helper**

```swift
@MainActor
private func launchApp(scenario: String = "default") -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments += ["-CollapsiblePagerScenario", scenario]
    app.launch()
    return app
}
```

- [ ] **Step 2: Test initial expanded state**

```swift
@MainActor
func testInitialExpandedStateShowsHeaderTabBarAndFirstPage() {
    let app = launchApp()

    XCTAssertTrue(app.otherElements["pager.header"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.otherElements["pager.tabbar"].exists)
    XCTAssertTrue(app.buttons["pager.tab.0"].isSelected)
    XCTAssertTrue(app.scrollViews["pager.page.0.scroll"].exists)
}
```

- [ ] **Step 3: Test vertical scroll pins TabBar**

Gesture: swipe up on first page until Header collapses.

Expected: `demo.collapseProgress` reaches `1.00`, TabBar remains hittable, first page rows continue scrolling under it, no header overlap with visible row.

- [ ] **Step 4: Test pull-down expands before refresh**

Scenario: `overallRefresh`.

Gesture: first pin Header, then pull down once.

Expected: collapse progress decreases before `demo.refreshCount` changes. A second pull after progress reaches `0.00` increments refresh count to `1`.

- [ ] **Step 5: Test child refresh does not fallback**

Scenario: `childRefresh`.

Gesture: switch to a child without refresh support and pull beyond threshold.

Expected: `demo.refreshCount` remains `0`. Switch to refreshable child and pull beyond threshold; child refresh marker increments.

- [ ] **Step 6: Test tab tap and latest target commit**

Gesture: tap tab 1, then tap tab 2 quickly.

Expected: selected page label becomes `2`, tab 2 has selected accessibility trait, and page 2 scroll view exists.

- [ ] **Step 7: Test scroll position preservation**

Gesture: scroll page 0 to a visible marker row, switch to page 1 and scroll differently, switch back to page 0.

Expected: marker row from page 0 remains near its prior visual position and Header state remains consistent with `pinAnchorY`.

- [ ] **Step 8: Test short-content refresh**

Scenario: `shortContent`.

Gesture: pull down on short content page.

Expected: scroll view bounces and refresh marker increments when refresh mode allows.

- [ ] **Step 9: Run UI tests**

Run:

```sh
xcrun simctl list devices available
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'platform=iOS Simulator,name=<Simulator Name>' test
```

Expected: the UI tests above pass on one available simulator.

## Task 11: Documentation And Final Verification

**Files:**
- Modify only if behavior changed: `docs/requirements-and-architecture.md`
- Modify only if UI/DSL changed: `docs/ui-design-and-animation-dsl.md`

**Acceptance Criteria:**
- Public API, first version scope and docs remain aligned.
- No old API names or deferred public behaviors are documented as implemented.
- No trailing whitespace or malformed markdown diff.

- [ ] **Step 1: Run package validation**

Run: `swift test`

Expected: all Swift Testing tests pass.

- [ ] **Step 2: Run example build**

Run: `xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' build`

Expected: build succeeds with no new Swift 6 concurrency warnings.

- [ ] **Step 3: Run UI tests on an available simulator**

Run: `xcrun simctl list devices available`, choose a simulator, then run the `xcodebuild ... test` command from Task 10.

Expected: required UI tests pass.

- [ ] **Step 4: Run documentation hygiene checks**

Run:

```sh
git diff --check
rg -n "deferredUntilIdle|animated\\(|横向滚动 TabBar|自动查找第一个" Sources Tests Examples docs
```

Expected: no whitespace errors; search results only appear in docs as non-goals or second-stage descriptions.

## Global Acceptance Checklist

- Header 向上滚动先折叠，折叠完成后 child 才继续滚动。
- Header 向下滚动时 child 先回到顶部，再展开 Header。
- Header 未完全展开时不能触发刷新。
- `.overall` 与 `.child` 刷新 owner 在一次下拉手势中互斥。
- TabBar 默认吸顶到导航栏下方或安全区顶部。
- Tab item selected 状态可被无障碍读取。
- 点击 Tab、API 选择和横向滑动都进入同一 page request pipeline。
- 横向滑动取消时 Tab 和 indicator 回到来源状态。
- 不同 child 保留自己的滚动位置。
- `reloadHeaderLayout` immediate 路径更新 Header、TabBar、child inset、pin threshold 和 offset correction，并保持视觉位置。
- Header controller 的 UIKit containment 在视觉宿主迁移中保持稳定。
- 所有 UIKit 公开入口和回调保持 `@MainActor`。
- 核心包不出现个人主页、头像、作品列表等业务专属类型。

## Manual QA Matrix

These cases are necessary before declaring V1 shippable, even if not all are automated:

| Scenario | Expected Result |
| --- | --- |
| 纵向减速未结束时点击 Tab | Header 宿主固定，最终目标页稳定提交 |
| 顶部回弹过程中横向切页 | Header 不与列表顶部脱钩，切页后按目标 child 校准 |
| 局部刷新 reveal 期间尝试横向切页 | 第一版禁止或延迟切页，不能双 owner 刷新 |
| 横竖屏切换 | 复用 layout invalidation，selected index 与 scroll position 合法 |
| Dynamic Type 调大 | Tab frame、indicator frame、automatic Header height 更新 |
| 导航第一页右滑返回 | 系统返回手势优先于横向分页 |
| Header 文本短变长再变短 | `reloadHeaderLayout` 不产生明显跳动 |

## Execution Order

1. Task 1 and Task 2 establish public types and pure layout tests.
2. Task 3, Task 4 and Task 5 build independent UI primitives.
3. Task 6 and Task 7 add state coordination.
4. Task 8 wires the public container.
5. Task 9 and Task 10 create the demo and UI tests.
6. Task 11 verifies package, example build, UI tests and docs.
