# CollapsiblePager V1 Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 从干净占位模块重写 V1 通用 UIKit `CollapsiblePager`，交付可折叠 Header、默认 TabBar、横向分页、纵向嵌套滚动、刷新 handoff 和示例验收链路。

**Architecture:** V1 采用“Nested 纵向内核 + Tabman 横向状态链路 + UIPageViewController 式 source/target programmatic 转场语义”的组合设计。纵向状态以 `PinAnchor` 为真相，横向状态以 `PagePosition` 为真相，TabBar 只渲染和发请求，刷新只做外部 handoff。PageContainer 与 TabBar 工作区域从 safe area top / navigation bar bottom 到屏幕底部；Header 默认在安全区内展示，也可配置延伸到顶部安全区外。

**Tech Stack:** Swift 6.2、UIKit、Swift Testing、XCTest UI Tests、iOS 13、内部 `UIScrollView` paging 容器。

---

## 当前基线

本计划最初基于干净占位模块编写：

- `Sources/CollapsiblePager/CollapsiblePager.swift`
- `Tests/CollapsiblePagerTests/CollapsiblePagerTests.swift`

如果从干净基线执行本计划，应按任务顺序重新创建 V1 源码。若从当前工作区继续开发，已有 `Public/`、`Header/`、`Layout/`、`Paging/`、`TabBar/` 等 V1 文件是计划执行产物，不要删除或回滚；新增调整应在现有实现上小步补齐。

## 架构调整回填清单

以下结论覆盖本计划早期草稿中较旧的描述：

- PageContainer frame 不再铺满 pager bounds，而是采用 NestedPageViewController 式 content viewport：顶部为 TabBar pin 位置，也就是导航栏底部或无导航栏时的 safe area top，底部到 pager bounds 底部。
- Header 顶部行为由 `CollapsiblePagerHeaderTopBehavior` 决定。默认 `.insideSafeArea`；`.extendsUnderTopSafeArea` 只扩展 Header 视觉 frame，TabBar 和 child rows 仍保留在安全区域内。
- Page controller 必须手动转发 child appearance lifecycle。自研 `UIScrollView` paging 不能依赖 UIKit 自动推断 `viewWillAppear` / `viewDidDisappear`。
- 横向 child UI 层级使用 bounded window，V1 默认只保留当前页和相邻页；完成切页后卸载远离当前页的 child controller 和 page view。
- 非相邻 Tab/API 跳转采用 `UIPageViewController.setViewControllers` 式 source/target 语义，不通过连续 `contentOffset` 滚过中间页；相邻页动画仍使用 paging scroll 动画。
- 短内容和空内容 child 需要 bottom inset 补偿，并观察 `contentSize` 变化，确保 Short/Empty 页也能向上滚到吸顶阈值。
- TabBar 内部采用 scroll-ready 层级：`TabBarView -> ContentScrollView -> ItemLayoutView -> Item + IndicatorContainer`。V1 默认等宽且不公开横向滚动能力，但层级要为后续可滚动 TabBar 保持正确。
- Examples 使用纯代码入口，不使用 `ViewController.swift` 作为主控制器，不使用 xib；`SceneDelegate` 挂载 `UITabBarController -> UINavigationController -> CollapsiblePagerViewController` 层级，模拟实际业务 App 中 tab + navigation 的集成环境。

## 验证命令

文档或计划改动：

```sh
git diff --check
```

核心库测试：

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' test
```

如果本机没有 `iPhone 17` 模拟器，先运行：

```sh
xcrun simctl list devices available
```

然后替换为可用模拟器名称。

## 文件结构

### Public

- `Sources/CollapsiblePager/Public/CollapsiblePagerViewController.swift`
  公开容器 façade，不承载复杂滚动算法。
- `Sources/CollapsiblePager/Public/CollapsiblePagerViewControllerDataSource.swift`
  Header、page count、title、child controller data source。
- `Sources/CollapsiblePager/Public/CollapsiblePagerViewControllerDelegate.swift`
  已提交选择、折叠进度和布局 context 回调。
- `Sources/CollapsiblePager/Public/CollapsiblePagerConfiguration.swift`
  Header、TabBar、indicator、paging、refresh 和 gesture 配置。
- `Sources/CollapsiblePager/Public/CollapsiblePagerProtocols.swift`
  `CollapsiblePagerScrollProviding`。
- `Sources/CollapsiblePager/Public/CollapsiblePagerLayoutContext.swift`
  对外可观察的布局上下文。

### Core State

- `Sources/CollapsiblePager/State/CollapsiblePagerState.swift`
  selection、page count、Header、pin、refresh handoff 总状态。
- `Sources/CollapsiblePager/State/CollapsiblePagerPagePosition.swift`
  `PagePosition`、direction、raw offset 转换。
- `Sources/CollapsiblePager/State/CollapsiblePagerPinAnchor.swift`
  纵向 anchor 值语义和 delta 计算。

### Layout

- `Sources/CollapsiblePager/Layout/CollapsiblePagerLayoutModels.swift`
  layout input/output、edge insets、Header heights、offset transition。
- `Sources/CollapsiblePager/Layout/CollapsiblePagerLayoutEngine.swift`
  纯值布局计算。

### Header

- `Sources/CollapsiblePager/Header/CollapsiblePagerHeaderHostView.swift`
  Header view 承载、Auto Layout 测量、collapse progress 分发。
- `Sources/CollapsiblePager/Header/CollapsiblePagerHeaderHostCoordinator.swift`
  Header content lifecycle、controller containment、host 迁移。
- `Sources/CollapsiblePager/Header/CollapsiblePagerHeaderMountView.swift`
  child scroll view 顶部 inset 区域的挂载点。
- `Sources/CollapsiblePager/Header/CollapsiblePagerFixedHeaderContainer.swift`
  吸顶、横向切页、回弹、刷新 reveal/end 和布局刷新使用的 fixed overlay。
- `Sources/CollapsiblePager/Header/CollapsiblePagerPinnedSurfaceView.swift`
  覆盖在 PageContainer 上方的 Header/TabBar 视觉层，负责 fixed overlay 坐标系。

### Children

- `Sources/CollapsiblePager/Children/CollapsiblePagerChildStore.swift`
  child 缓存、containment、scroll provider 校验和 managed inset 应用。
- `Sources/CollapsiblePager/Children/CollapsiblePagerChildRecord.swift`
  单个 child 的 view controller、scroll view、mount view 和观察 token。

### Paging

- `Sources/CollapsiblePager/Paging/CollapsiblePagerPageContainer.swift`
  内部 paging `UIScrollView` 和 child view 横向布局。
- `Sources/CollapsiblePager/Paging/CollapsiblePagerPageRequestPipeline.swift`
  Tab/API/gesture page request 的校验、pending、commit 和 cancel。

### TabBar

- `Sources/CollapsiblePager/TabBar/CollapsiblePagerTabBarView.swift`
  默认等宽文本 TabBar。
- `Sources/CollapsiblePager/TabBar/CollapsiblePagerTabBarContentView.swift`
  scroll-ready Tab 内容层级和等宽 item 布局。
- `Sources/CollapsiblePager/TabBar/CollapsiblePagerTabBarIndicatorContainerView.swift`
  indicator 坐标容器。
- `Sources/CollapsiblePager/TabBar/CollapsiblePagerTabItemView.swift`
  Tab button、selected progress 和 accessibility。
- `Sources/CollapsiblePager/TabBar/CollapsiblePagerIndicatorFocusRect.swift`
  focus rect 与 indicator frame 计算。
- `Sources/CollapsiblePager/TabBar/CollapsiblePagerUnderlineIndicatorView.swift`
  默认短下划线。

### Scroll, Refresh, Gesture

- `Sources/CollapsiblePager/Scroll/CollapsiblePagerVerticalScrollCoordinator.swift`
  纵向嵌套滚动、pin anchor、guarded offset、非当前 child 同步。
- `Sources/CollapsiblePager/Scroll/CollapsiblePagerScrollObservation.swift`
  KVO 观察 child `contentOffset` 和 `contentSize`，触发滚动协调与短内容 inset 重算。
- `Sources/CollapsiblePager/Refresh/CollapsiblePagerRefreshHandoffCoordinator.swift`
  刷新资格、同手势互斥和 handoff 记录。
- `Sources/CollapsiblePager/Gesture/CollapsiblePagerGestureArbiter.swift`
  横向/纵向/系统返回手势优先级。

### Tests

- `Tests/CollapsiblePagerTests/PublicAPIContractTests.swift`
- `Tests/CollapsiblePagerTests/LayoutEngineTests.swift`
- `Tests/CollapsiblePagerTests/PagePositionTests.swift`
- `Tests/CollapsiblePagerTests/PageRequestPipelineTests.swift`
- `Tests/CollapsiblePagerTests/IndicatorFocusRectTests.swift`
- `Tests/CollapsiblePagerTests/RefreshHandoffTests.swift`
- `Tests/CollapsiblePagerTests/PinAnchorTests.swift`
- `Tests/CollapsiblePagerTests/HeaderContainmentTests.swift`
- `Tests/CollapsiblePagerTests/ChildStoreTests.swift`
- `Tests/CollapsiblePagerTests/VerticalScrollCoordinatorTests.swift`
- `Tests/CollapsiblePagerTests/GestureArbiterTests.swift`
- `Tests/CollapsiblePagerTests/TabBarViewTests.swift`
- `Tests/CollapsiblePagerTests/ContainerIntegrationTests.swift`

## Task 1: 公开 API 合约

**Files:**

- Create: `Sources/CollapsiblePager/Public/CollapsiblePagerConfiguration.swift`
- Create: `Sources/CollapsiblePager/Public/CollapsiblePagerViewControllerDataSource.swift`
- Create: `Sources/CollapsiblePager/Public/CollapsiblePagerViewControllerDelegate.swift`
- Create: `Sources/CollapsiblePager/Public/CollapsiblePagerProtocols.swift`
- Create: `Sources/CollapsiblePager/Public/CollapsiblePagerLayoutContext.swift`
- Create: `Sources/CollapsiblePager/Public/CollapsiblePagerViewController.swift`
- Test: `Tests/CollapsiblePagerTests/PublicAPIContractTests.swift`

**Acceptance:**

- 所有 UIKit 入口为 `@MainActor`。
- `selectedIndex` 默认等于 `0`。
- 没有页面时 `effectiveSelectedIndex == nil`。
- 默认 Header 顶部行为为 `.insideSafeArea`。
- 不存在专门的刷新 child 协议。
- 不存在刷新触发 delegate。
- 不要求 `UIRefreshControl`。

- [ ] **Step 1: 写公开 API 失败测试**

```swift
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

    #expect(configuration.tabBar.height == 48)
    #expect(configuration.tabBar.placement == .belowHeader)
    #expect(configuration.tabBar.pinning == .pinBelowNavigationBar(offset: 0))
    #expect(configuration.header.topBehavior == .insideSafeArea)
    #expect(configuration.refreshMode == .none)
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
```

- [ ] **Step 2: 创建公开类型**

实现配置、data source、delegate 和 scroll provider。`CollapsiblePagerConfiguration` 使用 `@MainActor`，纯值子配置按需要 `Sendable`。

- [ ] **Step 3: 实现容器最小 selection 空态**

`reloadData()` 只做 page count clamp 和 effective selection 更新。`selectPage(at:animated:)` 在 Task 5 前先保持 no-op 或立即更新 effective selection 的测试辅助路径，Task 5 会替换为 request pipeline。

- [ ] **Step 4: 运行测试**

Run:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: Public API 测试通过。

## Task 2: 纯值 LayoutEngine

**Files:**

- Create: `Sources/CollapsiblePager/Layout/CollapsiblePagerLayoutModels.swift`
- Create: `Sources/CollapsiblePager/Layout/CollapsiblePagerLayoutEngine.swift`
- Test: `Tests/CollapsiblePagerTests/LayoutEngineTests.swift`

**Acceptance:**

- Layout engine 不持有 UIKit 对象。
- PageContainer frame 顶部等于 TabBar pin 位置，底部到 pager bounds 底部。
- child top inset 等于 Header max height + TabBar height。
- pin threshold 等于 Header collapse range。
- 空 Header range 时 progress 稳定为 `1`。
- Header 默认在安全区内；`.extendsUnderTopSafeArea` 只改变 Header frame 顶部，不改变 PageContainer、TabBar 或 child inset。

- [ ] **Step 1: 写布局失败测试**

```swift
import CoreGraphics
import Testing
@testable import CollapsiblePager

@Test func expandedLayoutUsesManagedTopInset() {
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

    #expect(output.pageContainerFrame == CGRect(x: 0, y: 91, width: 390, height: 753))
    #expect(output.headerFrame == CGRect(x: 0, y: 91, width: 390, height: 260))
    #expect(output.headerVisibleHeight == 260)
    #expect(output.collapseProgress == 0)
    #expect(output.childContentInset.top == 308)
    #expect(output.tabBarFrame.minY == 351)
}

@Test func pinnedLayoutKeepsTabBarAtPinY() {
    var input = CollapsiblePagerLayoutInput.defaultTestValue
    input.pinAnchorY = 260

    let output = CollapsiblePagerLayoutEngine().layout(input)

    #expect(output.headerVisibleHeight == 0)
    #expect(output.collapseProgress == 1)
    #expect(output.tabBarFrame.minY == 91)
}

@Test func headerCanExtendUnderTopSafeAreaWithoutMovingTabBarOrRows() {
    var input = CollapsiblePagerLayoutInput.defaultTestValue
    input.headerTopBehavior = .extendsUnderTopSafeArea

    let output = CollapsiblePagerLayoutEngine().layout(input)

    #expect(output.pageContainerFrame == CGRect(x: 0, y: 91, width: 390, height: 753))
    #expect(output.headerFrame == CGRect(x: 0, y: 0, width: 390, height: 351))
    #expect(output.tabBarFrame == CGRect(x: 0, y: 351, width: 390, height: 48))
    #expect(output.childContentInset.top == 308)
}
```

- [ ] **Step 2: 实现 layout model 和 engine**

使用 `CollapsiblePagerEdgeInsets` 避免 layout core 依赖 UIKit。`CGRect` 和 `CGFloat` 可来自 CoreGraphics。

- [ ] **Step 3: 增加 Header 高度变化测试**

覆盖 `.preserveVisualPosition`、`.preserveCollapseProgress`、`.resetToExpanded`、`.resetToCollapsed`。

- [ ] **Step 4: 运行测试**

Expected: LayoutEngineTests 通过。

## Task 3: PagePosition 和 indicator focus rect

**Files:**

- Create: `Sources/CollapsiblePager/State/CollapsiblePagerPagePosition.swift`
- Create: `Sources/CollapsiblePager/TabBar/CollapsiblePagerIndicatorFocusRect.swift`
- Test: `Tests/CollapsiblePagerTests/PagePositionTests.swift`
- Test: `Tests/CollapsiblePagerTests/IndicatorFocusRectTests.swift`

**Acceptance:**

- page count 为 0 时 position 为 nil。
- raw offset 可转换为 from/to/progress/direction。
- focus rect 从 item frame 连续插值。
- indicator frame 支持 fixed、title、item、ratio 宽度模式。

- [ ] **Step 1: 写 PagePosition 测试**

```swift
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
```

- [ ] **Step 2: 写 focus rect 测试**

```swift
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
    let position = PagePosition(rawPosition: 0.5, fromIndex: 0, toIndex: 1, progress: 0.5, direction: .forward, isInteractive: true)

    let focusRect = try #require(IndicatorFocusRect.make(itemFrames: itemFrames, titleFrames: titleFrames, position: position))
    let indicator = focusRect.indicatorFrame(widthMode: .fixed(28), height: 3, bottomInset: 0)

    #expect(focusRect.itemFrame.midX == 120)
    #expect(indicator.width == 28)
    #expect(indicator.midX == 120)
}
```

- [ ] **Step 3: 实现 PagePosition 和 focus rect**

方向计算使用 raw position 的 lower/upper index。progress clamp 到 `0...1`。越界 raw position clamp 到有效范围。

- [ ] **Step 4: 运行测试**

Expected: PagePositionTests 和 IndicatorFocusRectTests 通过。

## Task 4: Header host 和 containment

**Files:**

- Create: `Sources/CollapsiblePager/Header/CollapsiblePagerHeaderHostView.swift`
- Create: `Sources/CollapsiblePager/Header/CollapsiblePagerHeaderHostCoordinator.swift`
- Create: `Sources/CollapsiblePager/Header/CollapsiblePagerHeaderMountView.swift`
- Create: `Sources/CollapsiblePager/Header/CollapsiblePagerFixedHeaderContainer.swift`
- Create: `Sources/CollapsiblePager/Header/CollapsiblePagerPinnedSurfaceView.swift`
- Test: `Tests/CollapsiblePagerTests/HeaderContainmentTests.swift`

**Acceptance:**

- Header 支持 `UIView` 和 `UIViewController`。
- Header controller parent 始终是 pager。
- host 在 mount/fixed overlay 间迁移不重复 add/remove child。
- 替换 Header 时正确移除旧 controller。
- fixed overlay 挂在 pinned surface 中，吸顶、横向切页和刷新 reveal 使用同一坐标系。

- [ ] **Step 1: 写 containment 测试**

```swift
import Testing
import UIKit
@testable import CollapsiblePager

@MainActor
@Test func headerViewControllerContainmentSurvivesHostMigration() {
    let pager = CollapsiblePagerViewController()
    pager.loadViewIfNeeded()
    let coordinator = CollapsiblePagerHeaderHostCoordinator(owner: pager)
    let header = UIViewController()
    let mount = CollapsiblePagerHeaderMountView()
    let fixed = CollapsiblePagerFixedHeaderContainer()

    coordinator.setContent(.viewController(header), initialContainer: mount)
    #expect(header.parent === pager)

    coordinator.moveHost(to: fixed, reason: .horizontalPaging)
    #expect(header.parent === pager)

    coordinator.moveHost(to: mount, reason: .currentChild)
    #expect(header.parent === pager)
}
```

- [ ] **Step 2: 实现 host view 和 containers**

`FixedHeaderContainer` 使用 hit-test 穿透策略：容器本身不吃事件，但子视图可以交互。

- [ ] **Step 3: 实现 coordinator**

`setContent` 负责旧内容移除、新内容 containment 和 host 添加。`moveHost` 只改 host superview 和 frame。

- [ ] **Step 4: 运行测试**

Expected: HeaderContainmentTests 通过。

## Task 5: ChildStore 和 managed inset

**Files:**

- Create: `Sources/CollapsiblePager/Children/CollapsiblePagerChildRecord.swift`
- Create: `Sources/CollapsiblePager/Children/CollapsiblePagerChildStore.swift`
- Test: `Tests/CollapsiblePagerTests/ChildStoreTests.swift`

**Acceptance:**

- child 用标准 containment 加入 pager。
- child 必须遵守 `CollapsiblePagerScrollProviding`。
- 对 child scroll view 关闭 automatic adjustment。
- 应用 managed top inset 和 scroll indicator inset。
- 每个 child 有独立 HeaderMountView。
- 按 child bounds、contentSize、managed top inset 和 pin threshold 计算 bottom inset 补偿。
- 创建 child record 时按当前 pin anchor 校准初始 `contentOffset`。

- [ ] **Step 1: 写 child store 测试**

```swift
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
@Test func childStoreAddsBottomInsetForShortContentToReachPinThreshold() throws {
    let pager = CollapsiblePagerViewController()
    let store = CollapsiblePagerChildStore(owner: pager)
    let child = ScrollChild()
    child.scrollView.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
    child.scrollView.contentSize = CGSize(width: 390, height: 80)

    let record = try #require(store.makeRecord(
        for: child,
        index: 0,
        managedTopInset: 308,
        managedBottomInset: 34,
        pinThreshold: 260
    ))

    let pinnedOffsetY = -48.0
    let maxScrollableOffsetY = record.scrollView.contentSize.height + record.scrollView.contentInset.bottom - record.scrollView.bounds.height
    #expect(maxScrollableOffsetY >= pinnedOffsetY)
}

@MainActor
private final class ScrollChild: UIViewController, CollapsiblePagerScrollProviding {
    let scrollView = UIScrollView()
    var pagerScrollView: UIScrollView { scrollView }
}
```

- [ ] **Step 2: 实现 ChildRecord**

记录 `index`、`viewController`、`scrollView`、`mountView`、`baseContentInset`、`baseScrollIndicatorInsets`、`lastKnownContentOffsetY`。

- [ ] **Step 3: 实现 ChildStore**

`makeRecord` 做 provider 校验、top/bottom inset 应用和初始 offset 校准。`attach`/`detach` 使用 `addChild`、`didMove`、`willMove`、`removeFromParent`。`updateManagedInset` 要在 `contentSize` 或 layout 变化后重算短内容 bottom inset。

- [ ] **Step 4: 运行测试**

Expected: ChildStoreTests 通过。

## Task 6: PageRequestPipeline 和 PageContainer

**Files:**

- Create: `Sources/CollapsiblePager/Paging/CollapsiblePagerPageRequestPipeline.swift`
- Create: `Sources/CollapsiblePager/Paging/CollapsiblePagerPageContainer.swift`
- Test: `Tests/CollapsiblePagerTests/PageRequestPipelineTests.swift`

**Acceptance:**

- Tab/API/gesture 使用同一请求模型。
- selectedIndex 只在 complete 时提交。
- cancel 回滚到来源 index。
- 空页和越界请求 no-op。
- 快速连续请求合并到最后目标。
- PageContainer 支持按 index 创建、移除 page view，并暴露已加载 page index 供容器裁剪窗口。

- [ ] **Step 1: 写 pipeline 测试**

```swift
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
```

- [ ] **Step 2: 实现 state 和 pipeline**

`CollapsiblePagerState.initial(pageCount:)` 在 pageCount 为 0 时设置 `effectiveSelectedIndex = nil`。

- [ ] **Step 3: 实现 PageContainer skeleton**

先完成 scroll view 初始化、paging 配置、delegate forwarding、raw position 计算、`pageView(at:)`、`removePageView(at:)`、`removeAllPageViews()` 和 `loadedPageIndexes`。child 布局和集成在 Task 10。

- [ ] **Step 4: 运行测试**

Expected: PageRequestPipelineTests 通过。

## Task 7: TabBar 和 indicator view

**Files:**

- Create: `Sources/CollapsiblePager/TabBar/CollapsiblePagerTabBarView.swift`
- Create: `Sources/CollapsiblePager/TabBar/CollapsiblePagerTabBarContentView.swift`
- Create: `Sources/CollapsiblePager/TabBar/CollapsiblePagerTabBarIndicatorContainerView.swift`
- Create: `Sources/CollapsiblePager/TabBar/CollapsiblePagerTabItemView.swift`
- Create: `Sources/CollapsiblePager/TabBar/CollapsiblePagerUnderlineIndicatorView.swift`
- Test: `Tests/CollapsiblePagerTests/TabBarViewTests.swift`

**Acceptance:**

- TabBar 渲染等宽 item。
- TabBar 内部使用 content scroll view、item layout view 和 indicator container；V1 默认禁用横向滚动。
- 点击只发 request callback。
- Tab item 必须注册 `.touchUpInside` target/action，真实触摸和程序化 `sendActions` 都能发出选择请求。
- selected progress 更新 item 样式和 accessibility。
- selected progress 字体变化后 item 需要 relayout，避免标题被截断。
- indicator 使用 focus rect。
- 空页时没有 item 和 indicator。

- [ ] **Step 1: 写 TabBar 测试**

```swift
import Testing
import UIKit
@testable import CollapsiblePager

@MainActor
@Test func tabItemRegistersTouchUpInsideTargetForRealTouches() throws {
    let itemView = CollapsiblePagerTabItemView(title: "Long")

    let actions = try #require(itemView.actions(forTarget: itemView, forControlEvent: .touchUpInside))

    #expect(actions.isEmpty == false)
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
    #expect(tabBar.indicatorContainerViewForTesting.superview === tabBar.itemLayoutViewForTesting)
}

@MainActor
@Test func tabBarTapOnlyEmitsRequest() {
    let tabBar = CollapsiblePagerTabBarView()
    var requestedIndex: Int?
    tabBar.onRequestSelection = { requestedIndex = $0 }

    tabBar.reloadTitles(["A", "B", "C"])
    tabBar.layoutIfNeeded()
    tabBar.itemView(at: 1)?.sendActions(for: .touchUpInside)

    #expect(requestedIndex == 1)
}

@MainActor
@Test func tabBarEmptyStateHasNoItemsAndNoIndicator() {
    let tabBar = CollapsiblePagerTabBarView()

    tabBar.reloadTitles([])

    #expect(tabBar.itemCount == 0)
    #expect(tabBar.indicatorFrame == nil)
}
```

- [ ] **Step 2: 实现 item view**

`selectionProgress` clamp 到 `0...1`，更新 title color/font 和 `accessibilityTraits`。

- [ ] **Step 3: 实现 TabBar view**

使用 scroll-ready content hierarchy 手动布局等宽 item。V1 不公开横向滚动能力，`contentScrollView.isScrollEnabled = false`，但 indicator 和 item 都放在同一个 content 坐标系中。

- [ ] **Step 4: 运行测试**

Expected: TabBarViewTests 通过。

## Task 8: PinAnchor 和纵向滚动协调

**Files:**

- Create: `Sources/CollapsiblePager/State/CollapsiblePagerPinAnchor.swift`
- Create: `Sources/CollapsiblePager/Scroll/CollapsiblePagerVerticalScrollCoordinator.swift`
- Create: `Sources/CollapsiblePager/Scroll/CollapsiblePagerScrollObservation.swift`
- Test: `Tests/CollapsiblePagerTests/PinAnchorTests.swift`
- Test: `Tests/CollapsiblePagerTests/VerticalScrollCoordinatorTests.swift`

**Acceptance:**

- 当前 child 以外的 scroll event 被忽略。
- 横向切页期间纵向 event 被忽略。
- 主动 setContentOffset 使用 guarded update。
- 非当前 child 只按 pin delta 同步。
- 顶部回弹和完全吸顶不传播错误 offset。
- 观察 child `contentSize` 变化并通知容器重算 managed inset。

- [ ] **Step 1: 写 PinAnchor 测试**

```swift
import Testing
@testable import CollapsiblePager

@Test func pinAnchorReportsDeltaOnlyWhenValueChanges() {
    var anchor = PinAnchor(value: 0)

    #expect(anchor.update(to: 20) == 20)
    #expect(anchor.update(to: 20) == 0)
    #expect(anchor.update(to: 5) == -15)
}
```

- [ ] **Step 2: 写顶部回弹测试**

```swift
import Testing
@testable import CollapsiblePager

@Test func topBounceDoesNotPropagatePinDelta() {
    var model = VerticalScrollModel(pinAnchorY: 0, pinThreshold: 260, managedTopInset: 308)

    let result = model.handleCurrentOffsetY(-340)

    #expect(result.pinDeltaY == 0)
    #expect(result.shouldSyncNonCurrentChildren == false)
}
```

- [ ] **Step 3: 实现 pin anchor 和 scroll model**

先实现纯值 `VerticalScrollModel`，再由 UIKit coordinator 调用它。这样复杂规则可单测。

- [ ] **Step 4: 实现 UIKit coordinator**

观察 current child scroll view，检查 phase，调用 model，应用 guarded offset。

- [ ] **Step 5: 实现 scroll observation**

用 KVO 观察 `contentOffset` 和 `contentSize`。`contentOffset` 进入纵向 coordinator；`contentSize` 回调给容器，由容器调用 ChildStore 重新计算短内容 bottom inset。

- [ ] **Step 6: 运行测试**

Expected: PinAnchorTests 和 VerticalScrollCoordinatorTests 通过。

## Task 9: RefreshHandoff 和 GestureArbiter

**Files:**

- Create: `Sources/CollapsiblePager/Refresh/CollapsiblePagerRefreshHandoffCoordinator.swift`
- Create: `Sources/CollapsiblePager/Gesture/CollapsiblePagerGestureArbiter.swift`
- Test: `Tests/CollapsiblePagerTests/RefreshHandoffTests.swift`
- Test: `Tests/CollapsiblePagerTests/GestureArbiterTests.swift`

**Acceptance:**

- Header 未展开时不 handoff。
- `.overall` 和 `.child` 同手势互斥。
- `.child` 不降级 `.overall`。
- 不暴露 refresh delegate。
- 系统返回手势优先。

- [ ] **Step 1: 写 RefreshHandoff 测试**

```swift
import Testing
@testable import CollapsiblePager

@Test func refreshHandoffRequiresExpandedHeaderAndTopChild() {
    var coordinator = RefreshHandoffCoordinator(mode: .child)

    #expect(coordinator.tryBeginHandoff(headerIsExpanded: false, childIsAtTop: true, index: 0) == nil)
    #expect(coordinator.tryBeginHandoff(headerIsExpanded: true, childIsAtTop: false, index: 0) == nil)
    #expect(coordinator.tryBeginHandoff(headerIsExpanded: true, childIsAtTop: true, index: 0) == .externalScrollView(scope: .child, index: 0))
}

@Test func refreshHandoffOnlyBeginsOncePerGesture() {
    var coordinator = RefreshHandoffCoordinator(mode: .overall)

    let first = coordinator.tryBeginHandoff(headerIsExpanded: true, childIsAtTop: true, index: 1)
    let second = coordinator.tryBeginHandoff(headerIsExpanded: true, childIsAtTop: true, index: 1)

    #expect(first == .externalScrollView(scope: .overall, index: 1))
    #expect(second == nil)
}
```

- [ ] **Step 2: 实现 handoff coordinator**

`resetGesture()` 在新下拉手势开始或结束后调用。Coordinator 不持有 UIKit 刷新控件。

- [ ] **Step 3: 实现 gesture arbiter 纯判断**

提供 `gesturePriority(for:)` 纯值方法，UIKit delegate 只桥接输入。

- [ ] **Step 4: 运行测试**

Expected: RefreshHandoffTests 和 GestureArbiterTests 通过。

## Task 10: 容器集成

**Files:**

- Modify: `Sources/CollapsiblePager/Public/CollapsiblePagerViewController.swift`
- Modify: `Sources/CollapsiblePager/Paging/CollapsiblePagerPageContainer.swift`
- Modify: `Sources/CollapsiblePager/Header/CollapsiblePagerHeaderHostCoordinator.swift`
- Modify: `Sources/CollapsiblePager/Children/CollapsiblePagerChildStore.swift`
- Test: `Tests/CollapsiblePagerTests/ContainerIntegrationTests.swift`

**Acceptance:**

- `reloadData()` 完整连接 Header、TabBar、PageContainer 和 ChildStore。
- page count 为 0 时进入空态。
- page count 变小时 clamp effective selection。
- `selectPage` 进入 request pipeline。
- page completion 后 delegate 通知一次。
- 容器手动转发 child appearance lifecycle。
- 横向 child window 默认只保留当前页和相邻页。
- 相邻 animated selection 等 PageContainer 完成后提交。
- 非相邻 animated selection 采用 direct source/target 转场，立即提交并裁剪 child window。
- TabBar item 点击使用 `.tabTap` 请求；相邻页保留横向 scroll 动画且 child controller appearance lifecycle 以 `animated = true` 转发，非相邻页立即 source/target 定位且 child controller appearance lifecycle 以 `animated = false` 转发。

- [ ] **Step 1: 写容器集成测试**

```swift
import Testing
import UIKit
@testable import CollapsiblePager

@MainActor
@Test func reloadDataWithNoPagesKeepsPublicSelectedIndexZeroAndClearsEffectiveSelection() {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 0)
    pager.dataSource = dataSource

    pager.reloadData()

    #expect(pager.selectedIndex == 0)
    #expect(pager.effectiveSelectedIndex == nil)
}

@MainActor
@Test func reloadDataLoadsCurrentAndAdjacentInitialWindow() {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 3)
    pager.dataSource = dataSource

    pager.reloadData()

    #expect(pager.loadedChildIndexesForTesting == [0, 1])
    #expect(pager.pageContainerLoadedPageIndexesForTesting == [0, 1])
    #expect(pager.effectiveSelectedIndex == 0)
}

@MainActor
@Test func adjacentAnimatedSelectionCommitsAfterPageContainerCompletes() {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 3)
    let delegate = SelectionRecorder()
    pager.dataSource = dataSource
    pager.delegate = delegate
    pager.reloadData()

    pager.selectPage(at: 1, animated: true)
    #expect(pager.selectedIndex == 0)

    pager.completePendingPageTransitionForTesting(targetIndex: 1)

    #expect(pager.selectedIndex == 1)
    #expect(delegate.selectedIndexes == [1])
}

@MainActor
@Test func nonAdjacentAnimatedSelectionUsesDirectSourceTargetTransition() {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 20)
    let delegate = SelectionRecorder()
    pager.dataSource = dataSource
    pager.delegate = delegate
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()
    pager.selectPage(at: 19, animated: false)

    #expect(pager.loadedChildIndexesForTesting == [18, 19])

    pager.selectPage(at: 0, animated: true)

    #expect(pager.selectedIndex == 0)
    #expect(pager.effectiveSelectedIndex == 0)
    #expect(pager.loadedChildIndexesForTesting == [0, 1])
    #expect(pager.pageContainerLoadedPageIndexesForTesting == [0, 1])
    #expect(delegate.selectedIndexes == [19, 0])
}

@MainActor
@Test func pageTransitionForwardsChildAppearanceLifecycleWhenVisible() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = LifecycleDataSource(pageCount: 2)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.beginAppearanceTransition(true, animated: false)
    pager.endAppearanceTransition()

    let firstChild = try #require(dataSource.child(at: 0))
    #expect(firstChild.events == ["willAppear", "didAppear"])

    pager.selectPage(at: 1, animated: false)

    let secondChild = try #require(dataSource.child(at: 1))
    #expect(firstChild.events == ["willAppear", "didAppear", "willDisappear", "didDisappear"])
    #expect(secondChild.events == ["willAppear", "didAppear"])
}

@MainActor
@Test func adjacentTabBarSelectionAnimatesScrollAndControllerTransition() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = LifecycleDataSource(pageCount: 2)
    let delegate = SelectionRecorder()
    pager.dataSource = dataSource
    pager.delegate = delegate
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()
    pager.beginAppearanceTransition(true, animated: false)
    pager.endAppearanceTransition()

    pager.tapTabItemForTesting(at: 1)

    let firstChild = try #require(dataSource.child(at: 0))
    let secondChild = try #require(dataSource.child(at: 1))
    #expect(pager.selectedIndex == 0)
    #expect(pager.effectiveSelectedIndex == 0)
    #expect(delegate.selectedIndexes.isEmpty)
    #expect(firstChild.animatedEvents.suffix(1) == ["willDisappear:true"])
    #expect(secondChild.animatedEvents == ["willAppear:true"])

    pager.completePendingPageTransitionForTesting(targetIndex: 1)

    #expect(pager.selectedIndex == 1)
    #expect(pager.effectiveSelectedIndex == 1)
    #expect(delegate.selectedIndexes == [1])
    #expect(firstChild.animatedEvents.suffix(2) == ["willDisappear:true", "didDisappear:true"])
    #expect(secondChild.animatedEvents == ["willAppear:true", "didAppear:true"])
}

@MainActor
@Test func tabBarSelectionToEmptyPageKeepsPinnedHeaderState() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 3)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let longScrollView = try #require(pager.childScrollViewForTesting(at: 0))
    longScrollView.contentSize = CGSize(width: 390, height: 1200)
    longScrollView.setContentOffset(CGPoint(x: 0, y: -48), animated: false)
    pager.view.layoutIfNeeded()

    pager.tapTabItemForTesting(at: 2)
    pager.view.layoutIfNeeded()

    let emptyScrollView = try #require(pager.childScrollViewForTesting(at: 2))
    #expect(pager.collapseProgressForTesting == 1)
    #expect(pager.tabBarFrameForTesting.minY == 0)
    #expect(emptyScrollView.contentOffset.y == -48)
}

@MainActor
@Test func tabBarSelectionBackToScrolledLongPagePreservesChildOffset() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 3)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let longScrollView = try #require(pager.childScrollViewForTesting(at: 0))
    let preservedOffsetY: CGFloat = 520
    longScrollView.contentSize = CGSize(width: 390, height: 2000)
    longScrollView.setContentOffset(CGPoint(x: 0, y: preservedOffsetY), animated: false)
    pager.view.layoutIfNeeded()

    pager.tapTabItemForTesting(at: 1)
    pager.view.layoutIfNeeded()
    pager.tapTabItemForTesting(at: 0)
    pager.view.layoutIfNeeded()

    let returnedLongScrollView = try #require(pager.childScrollViewForTesting(at: 0))
    #expect(returnedLongScrollView.contentOffset.y == preservedOffsetY)
}

@MainActor
@Test func tabBarSelectionBackFromEmptyRestoresUnloadedLongChildOffset() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 3)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let longScrollView = try #require(pager.childScrollViewForTesting(at: 0))
    let preservedOffsetY: CGFloat = 520
    longScrollView.contentSize = CGSize(width: 390, height: 2000)
    longScrollView.setContentOffset(CGPoint(x: 0, y: preservedOffsetY), animated: false)
    pager.view.layoutIfNeeded()

    pager.tapTabItemForTesting(at: 2)
    pager.view.layoutIfNeeded()
    #expect(pager.loadedChildIndexesForTesting == [1, 2])

    pager.tapTabItemForTesting(at: 0)
    pager.view.layoutIfNeeded()

    let returnedLongScrollView = try #require(pager.childScrollViewForTesting(at: 0))
    returnedLongScrollView.contentSize = CGSize(width: 390, height: 2000)
    pager.view.layoutIfNeeded()
    #expect(returnedLongScrollView.contentOffset.y == preservedOffsetY)
}

@MainActor
@Test func horizontalPagingSuppressesChildScrollIndicatorsUntilStable() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 3)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let longScrollView = try #require(pager.childScrollViewForTesting(at: 0))
    let shortScrollView = try #require(pager.childScrollViewForTesting(at: 1))
    let interactivePosition = try #require(PagePosition.make(rawPosition: 0.5, pageCount: 3, isInteractive: true))
    pager.updatePagePositionForTesting(interactivePosition)

    #expect(longScrollView.showsVerticalScrollIndicator == false)
    #expect(shortScrollView.showsVerticalScrollIndicator == false)

    let stablePosition = try #require(PagePosition.make(rawPosition: 0, pageCount: 3, isInteractive: false))
    pager.updatePagePositionForTesting(stablePosition)
    #expect(longScrollView.showsVerticalScrollIndicator)
    #expect(shortScrollView.showsVerticalScrollIndicator)
}
```

- [ ] **Step 2: 实现 test fixtures**

`DemoDataSource` 返回 `UIView()` Header 和遵守 `CollapsiblePagerScrollProviding` 的 child。`LifecycleDataSource` 返回记录 `viewWillAppear`、`viewDidAppear`、`viewWillDisappear`、`viewDidDisappear` 的 child，用于验证容器手动 lifecycle 转发。

- [ ] **Step 3: 集成 reloadData**

顺序：读取 count、更新 state、刷新 Header、刷新 TabBar、加载有效 child、应用 layout，然后按当前 effective selection 加载当前页和相邻页窗口。

- [ ] **Step 4: 集成 selectPage**

调用 PageRequestPipeline。TabBar item 点击使用 `.tabTap`，相邻页以 animated page scroll 过渡并在 PageContainer 完成后提交，child controller appearance lifecycle 同步以 `animated: true` 转发；非相邻页直接 source/target 定位并立即完成 request，child controller appearance lifecycle 以 `animated: false` 转发。公开 API 的相邻 animated selection 交给 PageContainer scroll 动画完成后提交；非相邻 programmatic selection 直接 set 到目标页并完成 request，避免滚过未加载的中间页。完成后统一通知 delegate、同步 TabBar、转发 child lifecycle，并按当前页裁剪 child window。新的 current child 需要按当前 `PinAnchor` 和 managed top inset 通过 guarded offset update 补齐不足，确保 Long 已吸顶后点击 Empty/Short 仍保持吸顶；已经滚得更深的 child 必须保留自己的列表位置，避免返回 Long 时跳回 row 1。child window 卸载远离当前页的 controller 前保存 contentOffset snapshot；重新加载时如果内容尺寸暂时不足以恢复，保留 pending offset，并在 `contentSize` KVO 后重算 inset 再恢复。横向 PagePosition 处于交互或过渡 progress 时临时隐藏 loaded child 的 scroll indicators，稳定后恢复业务 child 原始配置。

- [ ] **Step 5: 运行测试**

Expected: ContainerIntegrationTests 通过。

## Task 11: 示例 App

**Files:**

- Modify: `Examples/Examples.xcodeproj/project.pbxproj`
- Modify: `Examples/Examples/SceneDelegate.swift`
- Create: `Examples/Examples/DemoPagerFactory.swift`
- Create: `Examples/Examples/DemoHeaderView.swift`
- Create: `Examples/Examples/DemoListViewController.swift`
- Create: `Examples/Examples/DemoRefreshController.swift`
- Modify: `Examples/ExamplesUITests/ExamplesUITests.swift`

**Acceptance:**

- 示例 App 使用核心包 public API 接入。
- 示例 App 使用纯代码装配主界面，不使用 `ViewController.swift` 或 xib。
- 示例 App 根层级为 `UITabBarController -> UINavigationController -> CollapsiblePagerViewController`，导航栏使用小标题。
- 导航栏图标按钮可 push 新 pager，系统边缘返回手势可回到根 pager。
- Header 内容是业务外部 demo，不写入核心包。
- `.overall` 和 `.child` 刷新都由 demo child 自己安装。
- UI test 覆盖基础展开、切页和空态。

- [ ] **Step 1: 更新 SceneDelegate 纯代码入口**

`SceneDelegate` 创建 `UIWindow`，使用 `DemoPagerFactory` 生成根 `UITabBarController`，其第一个 tab 为 `UINavigationController(rootViewController: CollapsiblePagerViewController)`，并设置为 window root。不要恢复 `ViewController.swift`、Main storyboard 或 xib 主入口。

- [ ] **Step 2: 创建 demo factory**

Factory 提供三种场景：长内容、短内容、空内容。每个 child 都遵守 `CollapsiblePagerScrollProviding`。

- [ ] **Step 3: 创建 demo header**

Header 只展示示例占位文本和高度变化按钮，用于触发 `reloadHeaderLayout`。

- [ ] **Step 4: 创建 demo refresh controller**

使用系统 `UIRefreshControl` 或自定义 view 都可以，但只存在于 Examples target。核心 target 不引用刷新控件类型。

- [ ] **Step 5: 写 UI test**

覆盖 launch、点击 Tab、空态不崩溃、下拉前 Header 先展开，以及导航栏按钮 push 后的系统边缘返回手势。

- [ ] **Step 6: 运行示例构建**

Run:

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' build
```

Expected: Examples build 通过。

## Task 12: 文档同步和最终审计

**Files:**

- Modify: `docs/requirements-and-architecture.md`
- Modify: `docs/ui-design-and-animation-dsl.md`
- Modify: `docs/superpowers/plans/2026-07-03-collapsible-pager-v1.md`

**Acceptance:**

- 文档与实现 public API 一致。
- 旧 API 名称没有残留。
- 没有刷新 delegate 或 refreshable child 描述。
- 第一版范围和后续阶段一致。

- [ ] **Step 1: 扫描旧术语**

Run:

```sh
rg "RefreshableChild|DidTriggerRefresh|UIRefreshControl.*必须|deferredUntilIdle|selectedIndex: Int\\?" docs Sources Tests -g '!docs/superpowers/plans/2026-07-03-collapsible-pager-v1.md'
```

Expected: 没有匹配结果。示例 App 可以出现 `UIRefreshControl`，核心 target 和架构文档不能要求它。

- [ ] **Step 2: 运行格式检查**

Run:

```sh
git diff --check
```

Expected: 无 trailing whitespace 或 patch 格式错误。

- [ ] **Step 3: 运行核心测试**

Run:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 所有核心测试通过，无新增 Swift 6 并发警告。

- [ ] **Step 4: 审查 diff**

Run:

```sh
git status --short
git diff -- docs Sources Tests
```

Expected: 只包含本计划相关文件。

## 执行策略

推荐使用 Subagent-Driven：

1. 每个 task 一个 fresh subagent。
2. 主线程审查 task diff。
3. 先测试后实现。
4. 每个 task 完成后运行对应测试。

Inline Execution 也可行，但需要每 1 到 2 个 task 做一次人工检查，避免状态机实现偏离本文档。

仓库约定：只有用户明确要求提交、推送或创建 PR 时，才执行 `git add`、`git commit`、`git push` 或 PR 操作。计划中的 task 边界可作为未来提交拆分参考，不代表自动提交。
