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
- Header 顶部行为由 `CollapsiblePagerHeaderTopBehavior` 决定。默认 `.insideSafeArea`；`.extendsUnderTopSafeArea` 只扩展 Header 视觉 frame，TabBar 和 child 内容仍保留在安全区域内。
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

## 当前开发审计（2026-07-04）

本节记录当前工作区相对本计划的实际落地状态。下方 task checkbox 已按本次审计回填；若 checkbox 与本节冲突，以本节为准。

### 已验证完成

- Task 1 到 Task 8 的核心库分层文件均已创建，公开 API、纯值布局、`PagePosition`、indicator focus rect、Header containment、ChildStore、PageContainer、TabBar、`PinAnchor` 和纵向滚动协调都有实现与单元测试。
- Task 9 的 `RefreshHandoffCoordinator` 和 `GestureArbiter` 纯值模型、规则测试已完成。
- Task 10 容器集成已落地：`reloadData()`、Tab/API/gesture 统一 page request pipeline、相邻/非相邻页面切换、bounded child window、child appearance lifecycle、短/空页吸顶、横向切页期间 scroll indicator 抑制都有核心测试覆盖。
- Task 11 示例 App 已改为纯代码入口，并通过 public API 接入核心包；根层级为 `UITabBarController -> UINavigationController -> CollapsiblePagerViewController`。
- Task 12 的旧术语扫描、格式检查和核心测试已完成。
- Task 13 已接入 `reloadHeaderLayout(offsetPolicy:)`：Header 高度变化、reset expanded/collapsed、`PinAnchor`、当前 loaded child offset 与 preserved offset snapshot 修正均进入容器链路，并通过核心测试验证。
- Task 14 已接入 Header host 运行时迁移：展开稳定态使用当前 child `HeaderMountView`，吸顶和横向切页请求期间使用 fixed overlay，切页完成后按目标 child 和 `PinAnchor` 恢复宿主；2026-07-04 已修正下拉展开时 `HeaderHostView` 覆盖 TabBar spacer 的问题。
- Task 15 已接入 `GestureArbiter` 到 PageContainer 横向 pan 开始判定：Header 区域禁止分页、内容区允许分页、第一页 leading-edge 系统返回优先和 layout reload active 禁止分页均有测试覆盖。
- Task 16 已接入刷新 handoff 到真实 child `contentOffset` 路径：Header 展开前不移交，完全展开并越过 managed top boundary 后记录外部 handoff，active handoff 期间横向分页被禁止。
- Task 17 已补齐 Example UI 可观测信号和定向 UI 验收：Header progress/selection、列表 row/empty state 都有稳定 accessibility identifier；“下拉前 Header 先展开”用例在串行定向 UI test 中通过。

### 待补齐或需复核

- 完整 `Examples` UI suite 仍需后续稳定化：2026-07-04 一次全量运行在 422.326s 后被人工中断，日志显示 XCTest runner/app launch 处于 `Waiting for -runningDidFinish` 和 worker materialize 阶段。当前 V1 行为信号以 Examples build、核心测试和串行定向 UI test 为准；全量 UI suite 后续建议拆分 launch performance 或默认关闭并行 simulator clone。

### 已运行验证

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerDerivedData test
```

结果：`TEST SUCCEEDED`，Swift Testing 报告 66 个测试全部通过。

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTask13Fix2DerivedData test
```

结果：`TEST SUCCEEDED`，Swift Testing 报告 68 个测试全部通过。

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTask14FixDerivedData test
```

结果：`TEST SUCCEEDED`，Swift Testing 报告 70 个测试全部通过。

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTask15Fix2DerivedData test
```

结果：`TEST SUCCEEDED`，Swift Testing 报告 73 个测试全部通过。

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTask16FixDerivedData test
```

结果：`TEST SUCCEEDED`，Swift Testing 报告 77 个测试全部通过。

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTask18CoreDerivedData test
```

结果：`TEST SUCCEEDED`，Swift Testing 报告 77 个测试全部通过。

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerExamplesDerivedData build
```

结果：`BUILD SUCCEEDED`。

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerTask17ExamplesBuildDerivedData build
```

结果：`BUILD SUCCEEDED`。

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerTask18ExamplesBuildDerivedData build
```

结果：`BUILD SUCCEEDED`。

```sh
git diff --check
rg "RefreshableChild|DidTriggerRefresh|UIRefreshControl.*必须|deferredUntilIdle|selectedIndex: Int\\?" docs Sources Tests -g '!docs/superpowers/plans/2026-07-03-collapsible-pager-v1.md'
```

结果：均无输出。

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerExamplesTestDerivedData test
```

结果：`ExamplesTests` 中 2 个单元测试通过；`ExamplesUITests-Runner` 初始化 UI testing 时超时，报错为 `Timed out waiting for AX loaded notification`。

```sh
xcrun simctl boot "iPhone 17"
xcrun simctl bootstatus "iPhone 17" -b
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTask17ExamplesTestDerivedData test
```

结果：bootstatus 约 53s 后完成；全量 Examples test 进入 UI testing 后在 422.326s 被中断，最终为 `TEST INTERRUPTED`。日志显示 `ExamplesTests` 已执行通过，后续阻塞在 UI runner/app launch cleanup 与 worker materialize 阶段。

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTask17TargetedUITestDerivedData -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -only-testing:ExamplesUITests/ExamplesUITests/testPullDownRevealsHeaderBeforeRowsOverscroll test
```

结果：`TEST SUCCEEDED`；定向执行 1 个 UI test，0 failures，用时 29.698s。

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

- [x] **Step 1: 写公开 API 失败测试**

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
    #expect(configuration.refreshHandoffMode == .container)
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

- [x] **Step 2: 创建公开类型**

实现配置、data source、delegate 和 scroll provider。`CollapsiblePagerConfiguration` 使用 `@MainActor`，纯值子配置按需要 `Sendable`。

- [x] **Step 3: 实现容器最小 selection 空态**

`reloadData()` 只做 page count clamp 和 effective selection 更新。`selectPage(at:animated:)` 在 Task 5 前先保持 no-op 或立即更新 effective selection 的测试辅助路径，Task 5 会替换为 request pipeline。

- [x] **Step 4: 运行测试**

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

- [x] **Step 1: 写布局失败测试**

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

- [x] **Step 2: 实现 layout model 和 engine**

使用 `CollapsiblePagerEdgeInsets` 避免 layout core 依赖 UIKit。`CGRect` 和 `CGFloat` 可来自 CoreGraphics。

- [x] **Step 3: 增加 Header 高度变化测试**

覆盖 `.preserveVisualPosition`、`.preserveCollapseProgress`、`.resetToExpanded`、`.resetToCollapsed`。

- [x] **Step 4: 运行测试**

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

- [x] **Step 1: 写 PagePosition 测试**

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

- [x] **Step 2: 写 focus rect 测试**

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

- [x] **Step 3: 实现 PagePosition 和 focus rect**

方向计算使用 raw position 的 lower/upper index。progress clamp 到 `0...1`。越界 raw position clamp 到有效范围。

- [x] **Step 4: 运行测试**

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

- [x] **Step 1: 写 containment 测试**

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

- [x] **Step 2: 实现 host view 和 containers**

`FixedHeaderContainer` 使用 hit-test 穿透策略：容器本身不吃事件，但子视图可以交互。

- [x] **Step 3: 实现 coordinator**

`setContent` 负责旧内容移除、新内容 containment 和 host 添加。`moveHost` 只改 host superview 和 frame。

- [x] **Step 4: 运行测试**

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

- [x] **Step 1: 写 child store 测试**

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

- [x] **Step 2: 实现 ChildRecord**

记录 `index`、`viewController`、`scrollView`、`mountView`、`baseContentInset`、`baseScrollIndicatorInsets`、`lastKnownContentOffsetY`。

- [x] **Step 3: 实现 ChildStore**

`makeRecord` 做 provider 校验、top/bottom inset 应用和初始 offset 校准。`attach`/`detach` 使用 `addChild`、`didMove`、`willMove`、`removeFromParent`。`updateManagedInset` 要在 `contentSize` 或 layout 变化后重算短内容 bottom inset。

- [x] **Step 4: 运行测试**

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

- [x] **Step 1: 写 pipeline 测试**

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

- [x] **Step 2: 实现 state 和 pipeline**

`CollapsiblePagerState.initial(pageCount:)` 在 pageCount 为 0 时设置 `effectiveSelectedIndex = nil`。

- [x] **Step 3: 实现 PageContainer skeleton**

先完成 scroll view 初始化、paging 配置、delegate forwarding、raw position 计算、`pageView(at:)`、`removePageView(at:)`、`removeAllPageViews()` 和 `loadedPageIndexes`。child 布局和集成在 Task 10。

- [x] **Step 4: 运行测试**

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

- [x] **Step 1: 写 TabBar 测试**

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

- [x] **Step 2: 实现 item view**

`selectionProgress` clamp 到 `0...1`，更新 title color/font 和 `accessibilityTraits`。

- [x] **Step 3: 实现 TabBar view**

使用 scroll-ready content hierarchy 手动布局等宽 item。V1 不公开横向滚动能力，`contentScrollView.isScrollEnabled = false`，但 indicator 和 item 都放在同一个 content 坐标系中。

- [x] **Step 4: 运行测试**

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

- [x] **Step 1: 写 PinAnchor 测试**

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

- [x] **Step 2: 写顶部回弹测试**

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

- [x] **Step 3: 实现 pin anchor 和 scroll model**

先实现纯值 `VerticalScrollModel`，再由 UIKit coordinator 调用它。这样复杂规则可单测。

- [x] **Step 4: 实现 UIKit coordinator**

观察 current child scroll view，检查 phase，调用 model，应用 guarded offset。

- [x] **Step 5: 实现 scroll observation**

用 KVO 观察 `contentOffset` 和 `contentSize`。`contentOffset` 进入纵向 coordinator；`contentSize` 回调给容器，由容器调用 ChildStore 重新计算短内容 bottom inset。

- [x] **Step 6: 运行测试**

Expected: PinAnchorTests 和 VerticalScrollCoordinatorTests 通过。

## Task 9: RefreshHandoff 和 GestureArbiter

**Files:**

- Create: `Sources/CollapsiblePager/Refresh/CollapsiblePagerRefreshHandoffCoordinator.swift`
- Create: `Sources/CollapsiblePager/Gesture/CollapsiblePagerGestureArbiter.swift`
- Test: `Tests/CollapsiblePagerTests/RefreshHandoffTests.swift`
- Test: `Tests/CollapsiblePagerTests/GestureArbiterTests.swift`

**Acceptance:**

- Header 未展开时不 handoff。
- `.container` 和 `.child` 同手势互斥。
- `.child` 不降级 `.container`。
- 不暴露 refresh delegate。
- 系统返回手势优先。

- [x] **Step 1: 写 RefreshHandoff 测试**

```swift
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
    let second = coordinator.tryBeginHandoff(headerIsExpanded: true, childIsAtTop: true, index: 1)

    #expect(first == .containerHost(index: 1))
    #expect(second == nil)
}
```

- [x] **Step 2: 实现 handoff coordinator**

`resetGesture()` 在新下拉手势开始或结束后调用。Coordinator 不持有 UIKit 刷新控件。

- [x] **Step 3: 实现 gesture arbiter 纯判断**

提供 `gesturePriority(for:)` 纯值方法，UIKit delegate 只桥接输入。

- [x] **Step 4: 运行测试**

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

- [x] **Step 1: 写容器集成测试**

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

- [x] **Step 2: 实现 test fixtures**

`DemoDataSource` 返回 `UIView()` Header 和遵守 `CollapsiblePagerScrollProviding` 的 child。`LifecycleDataSource` 返回记录 `viewWillAppear`、`viewDidAppear`、`viewWillDisappear`、`viewDidDisappear` 的 child，用于验证容器手动 lifecycle 转发。

- [x] **Step 3: 集成 reloadData**

顺序：读取 count、更新 state、刷新 Header、刷新 TabBar、加载有效 child、应用 layout，然后按当前 effective selection 加载当前页和相邻页窗口。

- [x] **Step 4: 集成 selectPage**

调用 PageRequestPipeline。TabBar item 点击使用 `.tabTap`，相邻页以 animated page scroll 过渡并在 PageContainer 完成后提交，child controller appearance lifecycle 同步以 `animated: true` 转发；非相邻页直接 source/target 定位并立即完成 request，child controller appearance lifecycle 以 `animated: false` 转发。公开 API 的相邻 animated selection 交给 PageContainer scroll 动画完成后提交；非相邻 programmatic selection 直接 set 到目标页并完成 request，避免滚过未加载的中间页。完成后统一通知 delegate、同步 TabBar、转发 child lifecycle，并按当前页裁剪 child window。新的 current child 需要按当前 `PinAnchor` 和 managed top inset 通过 guarded offset update 补齐不足，确保 Long 已吸顶后点击 Empty/Short 仍保持吸顶；已经滚得更深的 child 必须保留自己的列表位置，避免返回 Long 时跳回初始顶部位置。child window 卸载远离当前页的 controller 前保存 contentOffset snapshot；重新加载时如果内容尺寸暂时不足以恢复，保留 pending offset，并在 `contentSize` KVO 后重算 inset 再恢复。横向 PagePosition 处于交互或过渡 progress 时临时隐藏 loaded child 的 scroll indicators，稳定后恢复业务 child 原始配置。

- [x] **Step 5: 运行测试**

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
- `.container` 刷新由 demo 业务侧挂到 container-owned host，`.child` 刷新由 demo child 自己安装。
- UI test 覆盖基础展开、切页和空态。

- [x] **Step 1: 更新 SceneDelegate 纯代码入口**

`SceneDelegate` 创建 `UIWindow`，使用 `DemoPagerFactory` 生成根 `UITabBarController`，其第一个 tab 为 `UINavigationController(rootViewController: CollapsiblePagerViewController)`，并设置为 window root。不要恢复 `ViewController.swift`、Main storyboard 或 xib 主入口。

- [x] **Step 2: 创建 demo factory**

Factory 提供三种场景：长内容、短内容、空内容。每个 child 都遵守 `CollapsiblePagerScrollProviding`。

- [x] **Step 3: 创建 demo header**

Header 只展示示例占位文本和高度变化按钮，用于触发 `reloadHeaderLayout`。

- [x] **Step 4: 创建 demo refresh controller**

示例 child 保留系统 `UIRefreshControl`，并且该控件只存在于 Examples target。核心 target 不引用刷新控件类型，不包装 `UIRefreshControl`，也不介入具体刷新实现。

- [x] **Step 5: 写 UI test**

覆盖 launch、点击 Tab、空态不崩溃、下拉前 Header 先展开，以及导航栏按钮 push 后的系统边缘返回手势。

当前状态：UI test 已覆盖 launch、Tab 切换、空态、push、边缘返回，以及“下拉前 Header 先展开”的定向验收。完整 UI suite 仍有模拟器/XCTest runner 启动慢或卡住风险；V1 交互验收以串行 `-only-testing` 命令为准。

- [x] **Step 6: 运行示例构建**

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

- [x] **Step 1: 扫描旧术语**

Run:

```sh
rg "RefreshableChild|DidTriggerRefresh|UIRefreshControl.*必须|deferredUntilIdle|selectedIndex: Int\\?" docs Sources Tests -g '!docs/superpowers/plans/2026-07-03-collapsible-pager-v1.md'
```

Expected: 没有匹配结果。示例 App 可以出现 `UIRefreshControl`，核心 target 和架构文档不能要求它。

- [x] **Step 2: 运行格式检查**

Run:

```sh
git diff --check
```

Expected: 无 trailing whitespace 或 patch 格式错误。

- [x] **Step 3: 运行核心测试**

Run:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 所有核心测试通过，无新增 Swift 6 并发警告。

- [x] **Step 4: 审查 diff**

Run:

```sh
git status --short
git diff -- docs Sources Tests
```

Expected: 只包含本计划相关文件。

## V1 Completion 后续开发计划

以下任务承接 2026-07-04 审计中列出的待补齐项。执行顺序按依赖关系排列：先补 Header 布局位置修正，再补 Header 视觉宿主迁移，然后接入手势仲裁和刷新 handoff，最后补 Example UI 验收。

## Task 13: 接入 `reloadHeaderLayout(offsetPolicy:)`

**Files:**

- Modify: `Sources/CollapsiblePager/Public/CollapsiblePagerViewController.swift`
- Test: `Tests/CollapsiblePagerTests/ContainerIntegrationTests.swift`
- Check: `docs/requirements-and-architecture.md`
- Check: `docs/ui-design-and-animation-dsl.md`

**Acceptance:**

- `reloadHeaderLayout(offsetPolicy:)` 不再只是 `applyLayout()`。
- Header height 从旧值变为新值时，使用 `CollapsiblePagerLayoutEngine.headerOffsetTransition(...)` 计算新的 `PinAnchor` 和 offset correction。
- `contentOffsetCorrectionY` 表示应用到 `UIScrollView.contentOffset.y` 的真实差值；Header 最大高度变化时必须同时抵消 managed top inset 变化，保持 `contentOffset.y + managedTopInset == PinAnchor`。
- `.preserveVisualPosition` 保持 Header/TabBar/child 内容的相对视觉关系。
- `.preserveCollapseProgress` 保持折叠进度。
- `.resetToExpanded` 展开 Header，`.resetToCollapsed` 吸顶 Header。
- loaded child 和已卸载 child 的 preserved offset snapshot 都按 correction 修正。
- `configuration` 变化中涉及 Header height 的路径不能提前覆盖旧 Header heights，必须保留给 `reloadHeaderLayout` 使用。

- [x] **Step 1: 写 Header layout reload 集成测试**

Add to `Tests/CollapsiblePagerTests/ContainerIntegrationTests.swift`:

```swift
@MainActor
@Test func reloadHeaderLayoutPreservesVisualPositionWhenHeaderHeightChanges() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.header.heightMode = .fixed(max: 260, min: 0)
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.setContentOffset(CGPoint(x: 0, y: -178), animated: false)
    pager.view.layoutIfNeeded()

    #expect(abs(pager.collapseProgressForTesting - 0.5) < 0.001)

    pager.configuration.header.heightMode = .fixed(max: 360, min: 0)
    pager.view.layoutIfNeeded()

    #expect(abs(pager.collapseProgressForTesting - (130.0 / 360.0)) < 0.001)
    #expect(scrollView.contentInset.top == 408)
    #expect(scrollView.contentOffset.y == -278)
    #expect(pager.headerFrameForTesting.height == 230)
    #expect(scrollView.contentOffset.y + scrollView.contentInset.top == 130)
}

@MainActor
@Test func reloadHeaderLayoutCanResetToExpandedOrCollapsed() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.header.heightMode = .fixed(max: 260, min: 0)
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.setContentOffset(CGPoint(x: 0, y: -48), animated: false)
    pager.view.layoutIfNeeded()

    pager.reloadHeaderLayout(offsetPolicy: .resetToExpanded)
    pager.view.layoutIfNeeded()
    #expect(pager.collapseProgressForTesting == 0)
    #expect(scrollView.contentOffset.y == -308)

    pager.reloadHeaderLayout(offsetPolicy: .resetToCollapsed)
    pager.view.layoutIfNeeded()
    #expect(pager.collapseProgressForTesting == 1)
    #expect(scrollView.contentOffset.y == -48)
}
```

- [x] **Step 2: 确认测试失败**

Run:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTask13TDDDerivedData test
```

Actual: 新增 Header layout reload 测试按预期失败；同时暴露原 `headerOffsetTransition.contentOffsetCorrectionY` 语义只表达 pin delta，不能保持 child offset 与 managed inset 一致。

- [x] **Step 3: 实现 Header height 状态跟踪**

Update `Sources/CollapsiblePager/Public/CollapsiblePagerViewController.swift`:

```swift
private var appliedHeaderHeights: CollapsiblePagerHeaderHeights?

private func currentAppliedHeaderHeights() -> CollapsiblePagerHeaderHeights {
    appliedHeaderHeights ?? headerHeights().normalized
}
```

In `applyLayout()`, after `currentLayoutOutput = output`, store:

```swift
appliedHeaderHeights = headerHeights().normalized
```

Update `configuration.didSet` so Header height changes call `reloadHeaderLayout(offsetPolicy: .preserveVisualPosition)` instead of immediately losing the previous height:

```swift
let previousHeader = oldValue.header
tabBarView.apply(configuration: configuration.tabBar)
pageContainer.apply(paging: configuration.paging)
if previousHeader != configuration.header {
    reloadHeaderLayout(offsetPolicy: .preserveVisualPosition)
} else {
    applyLayout()
}
```

- [x] **Step 4: 实现 offset policy 应用**

Replace `reloadHeaderLayout(offsetPolicy:)` body with logic equivalent to:

```swift
public func reloadHeaderLayout(offsetPolicy: CollapsiblePagerHeaderOffsetPolicy = .preserveVisualPosition) {
    let previousHeights = currentAppliedHeaderHeights()
    let nextHeights = headerHeights()
    let transition = layoutEngine.headerOffsetTransition(
        from: previousHeights,
        to: nextHeights,
        currentPinAnchorY: state.pinAnchorY,
        policy: offsetPolicy
    )
    let minimumOffsetY = -(nextHeights.normalized.maxHeight + max(0, configuration.tabBar.height))
    let correctedLoadedOffsets = loadedChildRecords.mapValues { record in
        max(record.scrollView.contentOffset.y + transition.contentOffsetCorrectionY, minimumOffsetY)
    }

    state.pinAnchorY = transition.nextPinAnchorY
    verticalScrollCoordinator.setPinAnchorY(transition.nextPinAnchorY)
    syncPreservedContentOffsets(
        by: transition.contentOffsetCorrectionY,
        minimumOffsetY: minimumOffsetY
    )
    verticalScrollCoordinator.performGuardedOffsetUpdate {
        applyLayout()
    }
    verticalScrollCoordinator.setPinAnchorY(state.pinAnchorY)
    for (index, offsetY) in correctedLoadedOffsets {
        guard let record = loadedChildRecords[index] else {
            continue
        }

        verticalScrollCoordinator.setContentOffsetY(offsetY, for: record.scrollView)
        record.lastKnownContentOffsetY = record.scrollView.contentOffset.y
    }
    alignCurrentChildOffsetToPinAnchor()
}
```

Important implementation detail: `applyLayout()` updates child `contentInset`; UIKit may synchronously emit scroll callbacks for that inset mutation. Wrap this layout pass in `verticalScrollCoordinator.performGuardedOffsetUpdate { ... }` so internal inset/offset correction is not mistaken for user scrolling.

- [x] **Step 5: 运行核心测试**

Run:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTask13Fix2DerivedData test
```

Actual: `TEST SUCCEEDED`，Swift Testing 报告 68 个测试全部通过。

- [x] **Step 6: 同步文档**

Check whether `docs/requirements-and-architecture.md` and `docs/ui-design-and-animation-dsl.md` still describe `reloadHeaderLayout` accurately. If the implementation keeps immediate-only public behavior and queues no idle work, update only the current implementation status note.

## Task 14: 接入 Header host mount/fixed overlay 迁移

**Files:**

- Modify: `Sources/CollapsiblePager/Public/CollapsiblePagerViewController.swift`
- Modify: `Sources/CollapsiblePager/Header/CollapsiblePagerHeaderHostCoordinator.swift`
- Test: `Tests/CollapsiblePagerTests/HeaderContainmentTests.swift`
- Test: `Tests/CollapsiblePagerTests/ContainerIntegrationTests.swift`

**Acceptance:**

- Header controller parent 始终是 pager。
- Header host 可以在 current child 的 `HeaderMountView` 和 `CollapsiblePagerFixedHeaderContainer` 之间迁移。
- Header 展开且稳定在 current child 时使用 child mount；吸顶、横向切页、刷新 reveal、layout reload 时使用 fixed overlay。
- 迁移只移动 host view，不重复 add/remove header child controller。
- 切页完成后，Header host 按当前 `PinAnchor` 回到正确宿主。

- [x] **Step 1: 补充 host 当前宿主测试入口**

Add test-only state to `CollapsiblePagerHeaderHostCoordinator`:

```swift
var hostSuperviewForTesting: UIView? {
    hostView.superview
}
```

Expose through pager test helper:

```swift
var headerHostSuperviewForTesting: UIView? {
    headerHostCoordinator.hostSuperviewForTesting
}
```

- [x] **Step 2: 写容器迁移测试**

Add to `Tests/CollapsiblePagerTests/ContainerIntegrationTests.swift`:

```swift
@MainActor
@Test func headerHostUsesCurrentChildMountWhenExpandedAndFixedOverlayWhenPinned() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 2)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let firstMount = try #require(pager.headerMountViewForTesting(at: 0))
    #expect(pager.headerHostSuperviewForTesting === firstMount)

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.setContentOffset(CGPoint(x: 0, y: -48), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.collapseProgressForTesting == 1)
    #expect(pager.headerHostSuperviewForTesting === pager.fixedHeaderContainerForTesting)
}

@MainActor
@Test func headerHostMovesToTargetChildMountAfterCompletedPageSelection() throws {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 2)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()
    pager.tapTabItemForTesting(at: 1)

    #expect(pager.headerHostSuperviewForTesting === pager.fixedHeaderContainerForTesting)

    pager.completePendingPageTransitionForTesting(targetIndex: 1)
    pager.view.layoutIfNeeded()

    let secondMount = try #require(pager.headerMountViewForTesting(at: 1))
    #expect(pager.headerHostSuperviewForTesting === secondMount)
}
```

- [x] **Step 3: 确认测试失败**

Run:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTask14TDDDerivedData test
```

Actual: 新增两个迁移测试按预期失败，失败点均为 Header host 仍停留在 `CollapsiblePagerFixedHeaderContainer`。

- [x] **Step 4: 实现宿主选择函数**

Add to `CollapsiblePagerViewController`:

```swift
private func updateHeaderHostPlacement(reason: CollapsiblePagerHeaderHostMoveReason) {
    guard state.pageCount > 0 else {
        return
    }

    guard let currentIndex = state.effectiveSelectedIndex,
          let record = loadedChildRecords[currentIndex],
          let currentLayoutOutput else {
        headerHostCoordinator.moveHost(to: fixedHeaderContainer, reason: reason)
        return
    }

    let shouldUseFixedOverlay =
        currentLayoutOutput.collapseProgress >= 1 ||
        shouldSuppressChildScrollIndicators(for: state.pagePosition) ||
        state.pendingSelectedIndex != nil ||
        activePageAppearanceTransition != nil ||
        reason == .horizontalPaging ||
        reason == .refresh ||
        reason == .layoutReload

    if shouldUseFixedOverlay {
        headerHostCoordinator.moveHost(to: fixedHeaderContainer, reason: reason)
    } else {
        headerHostCoordinator.moveHost(to: record.mountView, reason: .currentChild)
    }
}
```

Call it after `applyLayout()`, after page position changes, before animated page transitions, after page transition completion, and after current child window changes.

- [x] **Step 5: 保持 Header frame 一致**

When host is in `HeaderMountView`, set host frame to the Header visual area only: `height = managedTopInset - tabBarHeight`. The mount itself still keeps `Header max height + TabBar height` as child scroll spacer. When host is in fixed overlay, set host frame to fixed container bounds. Keep `CollapsiblePagerHeaderHostCoordinator.moveHost(to:frame:reason:)` as the single point that changes superview and frame.

- [x] **Step 6: 运行核心测试**

Run:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTask14FixDerivedData test
```

Actual: `TEST SUCCEEDED`，Swift Testing 报告 70 个测试全部通过。

## Task 15: 接入 `GestureArbiter` 到 UIKit 手势链路

**Files:**

- Modify: `Sources/CollapsiblePager/Paging/CollapsiblePagerPageContainer.swift`
- Modify: `Sources/CollapsiblePager/Public/CollapsiblePagerViewController.swift`
- Modify: `Sources/CollapsiblePager/Gesture/CollapsiblePagerGestureArbiter.swift`
- Test: `Tests/CollapsiblePagerTests/GestureArbiterTests.swift`
- Test: `Tests/CollapsiblePagerTests/ContainerIntegrationTests.swift`

**Acceptance:**

- PageContainer 的 pan gesture 通过 `GestureArbiter` 判断是否允许开始。
- 第一页 leading-edge 右滑优先交给系统返回手势。
- Header 区域横向手势不启动分页。
- 横向分页活跃时纵向 coordinator 忽略 child scroll events。
- 刷新动画或 layout reload active 时横向分页被禁止。

- [x] **Step 1: 扩展手势输入测试**

Add to `Tests/CollapsiblePagerTests/GestureArbiterTests.swift`:

```swift
@Test func layoutReloadBlocksHorizontalPaging() {
    let arbiter = GestureArbiter()
    let input = GestureArbiterInput(
        translation: CGSize(width: 80, height: 1),
        isOnFirstPage: false,
        startsAtLeadingEdge: false,
        isInHeader: false,
        isLayoutReloadActive: true
    )

    #expect(arbiter.gesturePriority(for: input) == .ignored)
}
```

- [x] **Step 2: 给 PageContainer 增加 shouldBegin 回调**

In `CollapsiblePagerPageContainer`, use a private paging `UIScrollView` subclass as the built-in pan delegate owner. UIKit requires `UIScrollView`'s built-in pan gesture recognizer to keep its scroll view as delegate, so PageContainer must not replace `scrollView.panGestureRecognizer.delegate`:

```swift
private final class CollapsiblePagerPagingScrollView: UIScrollView {
    var shouldBeginHorizontalPan: (@MainActor (UIPanGestureRecognizer) -> Bool)?

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let superAllowsBegin = super.gestureRecognizerShouldBegin(gestureRecognizer)
        guard superAllowsBegin,
              gestureRecognizer === panGestureRecognizer,
              let pan = gestureRecognizer as? UIPanGestureRecognizer else {
            return superAllowsBegin
        }

        return shouldBeginHorizontalPan?(pan) ?? true
    }
}
```

Expose the scroll view as `UIScrollView` and bridge the callback:

```swift
private let pagingScrollView: CollapsiblePagerPagingScrollView
var scrollView: UIScrollView {
    pagingScrollView
}

var shouldBeginHorizontalPan: (@MainActor (UIPanGestureRecognizer) -> Bool)? {
    didSet {
        pagingScrollView.shouldBeginHorizontalPan = shouldBeginHorizontalPan
    }
}
```

Actual: `CollapsiblePagerPageContainer` now uses this subclass and no longer mutates `panGestureRecognizer.delegate`.

- [x] **Step 3: 写 pager 手势桥接测试**

Add to `Tests/CollapsiblePagerTests/ContainerIntegrationTests.swift`:

```swift
@MainActor
@Test func pagerBlocksHorizontalPagingFromHeaderArea() {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 2)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    pager.reloadData()
    pager.view.layoutIfNeeded()

    let allowed = pager.shouldBeginHorizontalPagingForTesting(
        translation: CGSize(width: -80, height: 4),
        location: CGPoint(x: 120, y: pager.headerFrameForTesting.midY)
    )

    #expect(allowed == false)
}

@MainActor
@Test func pagerAllowsHorizontalPagingFromPageContentArea() {
    let pager = CollapsiblePagerViewController()
    let dataSource = DemoDataSource(pageCount: 2)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
    pager.reloadData()
    pager.view.layoutIfNeeded()

    let allowed = pager.shouldBeginHorizontalPagingForTesting(
        translation: CGSize(width: -80, height: 4),
        location: CGPoint(x: 120, y: pager.tabBarFrameForTesting.maxY + 80)
    )

    #expect(allowed)
}
```

Actual TDD red:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTask15TDDDerivedData test
```

Actual: failed as expected because `CollapsiblePagerViewController` did not yet expose `shouldBeginHorizontalPagingForTesting(...)`.

- [x] **Step 4: 实现 pager 手势桥接**

Add one arbiter instance and helper:

```swift
private let gestureArbiter = GestureArbiter()

private func shouldBeginHorizontalPaging(translation: CGSize, location: CGPoint) -> Bool {
    guard state.pageCount > 1 else {
        return false
    }
    let isInHeader = currentLayoutOutput?.headerFrame.contains(location) ?? false
    let priority = gestureArbiter.gesturePriority(
        for: GestureArbiterInput(
            translation: translation,
            isOnFirstPage: state.effectiveSelectedIndex == 0,
            startsAtLeadingEdge: location.x <= 24,
            isInHeader: isInHeader,
            isRefreshAnimationActive: false,
            isLayoutReloadActive: isHeaderLayoutReloadActive
        )
    )
    return priority == .horizontalPaging
}
```

Wire `pageContainer.shouldBeginHorizontalPan` in `configureViewHierarchy()`:

```swift
pageContainer.shouldBeginHorizontalPan = { [weak self] pan in
    guard let self else {
        return true
    }
    let translation = pan.translation(in: self.view)
    return self.shouldBeginHorizontalPaging(
        translation: CGSize(width: translation.x, height: translation.y),
        location: pan.location(in: self.view)
    )
}
```

Actual: `isRefreshAnimationActive` remains `false` until Task 16 wires real refresh handoff state into the container.

- [x] **Step 5: 运行核心测试**

Run:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: GestureArbiterTests and ContainerIntegrationTests pass.

Actual:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTask15Fix2DerivedData test
```

Result: `TEST SUCCEEDED`，Swift Testing 报告 73 个测试全部通过。

Implementation note: an intermediate attempt to assign `scrollView.panGestureRecognizer.delegate = self` crashed at runtime with `UIScrollView's built-in pan gesture recognizer must have its scroll view as its delegate`; the final implementation keeps the built-in pan delegate on the scroll view subclass.

- [x] **Task 15 complete**

Verified files:

- `Sources/CollapsiblePager/Paging/CollapsiblePagerPageContainer.swift`
- `Sources/CollapsiblePager/Public/CollapsiblePagerViewController.swift`
- `Tests/CollapsiblePagerTests/GestureArbiterTests.swift`
- `Tests/CollapsiblePagerTests/ContainerIntegrationTests.swift`

- [x] **Task 15 docs synced**

Updated:

- `docs/requirements-and-architecture.md`
- `docs/ui-design-and-animation-dsl.md`

## Task 16: 接入刷新 handoff 到真实纵向下拉状态

**Files:**

- Modify: `Sources/CollapsiblePager/Public/CollapsiblePagerViewController.swift`
- Modify: `Sources/CollapsiblePager/Refresh/CollapsiblePagerRefreshHandoffCoordinator.swift`
- Modify: `Sources/CollapsiblePager/Scroll/CollapsiblePagerVerticalScrollCoordinator.swift`
- Test: `Tests/CollapsiblePagerTests/RefreshHandoffTests.swift`
- Test: `Tests/CollapsiblePagerTests/ContainerIntegrationTests.swift`
- Check: `docs/requirements-and-architecture.md`
- Check: `docs/ui-design-and-animation-dsl.md`

**Acceptance:**

- Header 未完全展开时，下拉只展开 Header，不开始 handoff。
- Header 完全展开且 current child 在顶部后，继续下拉才记录 handoff。
- 同一次下拉手势 `.container` 与 `.child` 只能有一个 handoff。
- `.child` 不降级 `.container`。
- 核心不创建 `UIRefreshControl`，不新增 refresh delegate，不调用 end refreshing。
- 刷新 handoff active 时，横向分页手势被 `GestureArbiter` 禁止。

- [x] **Step 1: 扩展 RefreshHandoffCoordinator 状态**

Add tests to `Tests/CollapsiblePagerTests/RefreshHandoffTests.swift`:

```swift
@Test func refreshHandoffReportsActiveScope() {
    var coordinator = RefreshHandoffCoordinator(mode: .child)

    _ = coordinator.tryBeginHandoff(headerIsExpanded: true, childIsAtTop: true, index: 2)

    #expect(coordinator.activeHandoff == .childScrollView(index: 2))
}
```

- [x] **Step 2: 写容器 handoff 测试**

Add to `Tests/CollapsiblePagerTests/ContainerIntegrationTests.swift`:

```swift
@MainActor
@Test func pullDownDoesNotBeginRefreshHandoffUntilHeaderExpanded() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .child
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.setContentOffset(CGPoint(x: 0, y: -120), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.activeRefreshHandoffForTesting == nil)
}

@MainActor
@Test func pullDownBeginsChildRefreshHandoffWhenExpandedAndAtTop() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .child
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = DemoDataSource(pageCount: 1)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.setContentOffset(CGPoint(x: 0, y: -330), animated: false)
    pager.view.layoutIfNeeded()

    #expect(pager.activeRefreshHandoffForTesting == .childScrollView(index: 0))
}
```

Additional test added for the final acceptance item:

```swift
@MainActor
@Test func activeRefreshHandoffBlocksHorizontalPaging() throws {
    var configuration = CollapsiblePagerConfiguration.default
    configuration.refreshHandoffMode = .child
    let pager = CollapsiblePagerViewController(configuration: configuration)
    let dataSource = DemoDataSource(pageCount: 2)
    pager.dataSource = dataSource
    pager.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    pager.reloadData()
    pager.view.layoutIfNeeded()

    let scrollView = try #require(pager.childScrollViewForTesting(at: 0))
    scrollView.contentSize = CGSize(width: 390, height: 2000)
    scrollView.setContentOffset(CGPoint(x: 0, y: -330), animated: false)
    pager.view.layoutIfNeeded()

    let allowed = pager.shouldBeginHorizontalPagingForTesting(
        translation: CGSize(width: -80, height: 4),
        location: CGPoint(x: 120, y: pager.tabBarFrameForTesting.maxY + 80)
    )

    #expect(allowed == false)
}
```

- [x] **Step 3: 确认测试失败**

Run:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: 新增容器刷新 handoff 测试失败，因为 pager 尚未持有并调用 coordinator。

Actual:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTask16TDDDerivedData test
```

Result: failed as expected because `CollapsiblePagerViewController` had no `activeRefreshHandoffForTesting` and did not yet hold the coordinator.

- [x] **Step 4: 在 pager 中持有 coordinator**

Add to `CollapsiblePagerViewController`:

```swift
private var refreshHandoffCoordinator: RefreshHandoffCoordinator
```

Initialize and update mode from configuration whenever configuration changes and during init/reload:

```swift
refreshHandoffCoordinator.mode = configuration.refreshHandoffMode
```

Expose test helper:

```swift
var activeRefreshHandoffForTesting: RefreshHandoff? {
    refreshHandoffCoordinator.activeHandoff
}
```

Actual: `refreshHandoffCoordinator` is initialized from `configuration.refreshHandoffMode`, synchronized in `configuration.didSet`, and reset during `reloadData()` or refresh mode changes.

- [x] **Step 5: 从纵向滚动路径尝试 handoff**

In `handleChildScrollViewDidScroll(_:)`, after vertical coordinator processing:

```swift
tryBeginRefreshHandoffIfNeeded(for: scrollView)
```

Implement:

```swift
private func tryBeginRefreshHandoffIfNeeded(for scrollView: UIScrollView) {
    guard !isHeaderLayoutReloadActive,
          !verticalScrollCoordinator.isHorizontalPagingActive,
          let index = state.effectiveSelectedIndex,
          let record = loadedChildRecords[index],
          scrollView === record.scrollView,
          let output = currentLayoutOutput else {
        return
    }

    let managedTopBoundary = -output.childContentInset.top
    if scrollView.contentOffset.y >= managedTopBoundary {
        let hadActiveHandoff = refreshHandoffCoordinator.activeHandoff != nil
        refreshHandoffCoordinator.resetGesture()
        if hadActiveHandoff {
            updateHeaderHostPlacement(reason: .currentChild)
        }
        return
    }

    let handoff = refreshHandoffCoordinator.tryBeginHandoff(
        headerIsExpanded: output.collapseProgress == 0,
        childIsAtTop: scrollView.contentOffset.y <= managedTopBoundary,
        index: index
    )

    if handoff != nil {
        updateHeaderHostPlacement(reason: .refresh)
    }
}
```

`shouldBeginHorizontalPaging(...)` now passes `refreshHandoffCoordinator.activeHandoff != nil` into `GestureArbiterInput.isRefreshAnimationActive`.

- [x] **Step 6: 运行核心测试**

Run:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: RefreshHandoffTests and ContainerIntegrationTests pass.

Actual:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTask16FixDerivedData test
```

Result: `TEST SUCCEEDED`，Swift Testing 报告 77 个测试全部通过。

- [x] **Step 7: 同步文档**

Remove or update the “当前实现状态” notes in `docs/requirements-and-architecture.md` and `docs/ui-design-and-animation-dsl.md` so they no longer claim the container integration is missing.

Actual: both documents now state that refresh handoff is connected to the real child `contentOffset` path while refresh UI/task/end ownership remains external.

- [x] **Task 16 complete**

## Task 17: 补齐 Example UI 验收并稳定运行方式

**Files:**

- Modify: `Examples/ExamplesUITests/ExamplesUITests.swift`
- Modify: `Examples/Examples/DemoListViewController.swift`
- Modify: `Examples/Examples/DemoHeaderView.swift`
- Check: `Examples/Examples/DemoPagerFactory.swift`
- Check: `docs/superpowers/plans/2026-07-03-collapsible-pager-v1.md`

**Acceptance:**

- UI test 覆盖 launch、Tab 切换、空态、push 和系统边缘返回。
- UI test 增加“下拉前 Header 先展开”的可观测验收。
- UI test 使用 accessibility identifiers，不依赖不稳定的坐标文本查找。
- 如果本机模拟器 AX 初始化慢，文档记录推荐先 warm simulator，再运行 UI test。

- [x] **Step 1: 给 Header 展开状态增加 accessibility signal**

In `Examples/Examples/DemoHeaderView.swift`, set stable identifiers:

```swift
accessibilityIdentifier = "demo-header"
progressLabel.accessibilityIdentifier = "demo-header-progress"
selectionLabel.accessibilityIdentifier = "demo-header-selection"
```

When progress updates, expose a readable value:

```swift
progressLabel.accessibilityValue = String(format: "%.2f", progress)
```

Actual: `DemoHeaderView` 已为 Header 容器、selection label、progress label 设置稳定 identifier，并在 progress 更新时暴露两位小数 accessibility value。

- [x] **Step 2: 给列表首行增加稳定标识**

In `Examples/Examples/DemoListViewController.swift`, ensure long page first visible row can be queried:

```swift
cell.accessibilityIdentifier = "\(accessibilityID)-row-\(indexPath.row)"
```

For empty state:

```swift
emptyLabel.accessibilityIdentifier = "\(accessibilityID)-empty"
```

Actual: `DemoListViewController` 已为每个 table cell 写入 `\(tableAccessibilityID)-row-\(indexPath.row)`，空态 label 写入 `\(tableAccessibilityID)-empty`。

- [x] **Step 3: 写 Header 先展开 UI test**

Add to `Examples/ExamplesUITests/ExamplesUITests.swift`:

```swift
@MainActor
func testPullDownRevealsHeaderBeforeRowsOverscroll() throws {
    let app = XCUIApplication()
    app.launch()

    let table = app.tables["demo-list-long"]
    XCTAssertTrue(table.waitForExistence(timeout: 8))
    XCTAssertTrue(app.staticTexts["demo-header-progress"].waitForExistence(timeout: 8))

    table.swipeUp()
    XCTAssertTrue(table.cells["demo-list-long-row-10"].waitForExistence(timeout: 8))

    let title = app.staticTexts["CollapsiblePager Demo"]
    for _ in 0..<3 where !title.isHittable {
        table.swipeDown()
    }

    XCTAssertTrue(title.isHittable)
    XCTAssertTrue(app.staticTexts["demo-header-selection"].isHittable)
    XCTAssertTrue(app.staticTexts["demo-header-progress"].isHittable)
}
```

Actual: 初版用例查询 `app.otherElements["demo-header"]` 失败，因为 `DemoHeaderView` 作为普通容器 view 不稳定出现在 AX hierarchy。最终用例改为验证 Header 文本和状态标签 `isHittable`，并允许最多 3 次下拉来覆盖 child 列表已滚动一段距离的真实路径。

- [x] **Step 4: 拆分 launch performance**

Move `testLaunchPerformance()` out of the required V1 interaction smoke path. Keep it in the file if useful, but do not use it as the signal for V1 behavior correctness.

Actual: `testLaunchPerformance()` 仍保留在 UI test 文件中，但 V1 行为验收采用 `-only-testing:ExamplesUITests/ExamplesUITests/testPullDownRevealsHeaderBeforeRowsOverscroll` 串行定向命令，不把 launch performance 当作功能正确性信号。

- [x] **Step 5: 运行 Example build**

Run:

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' build
```

Expected: `BUILD SUCCEEDED`.

Actual:

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerTask17ExamplesBuildDerivedData build
```

Result: `BUILD SUCCEEDED`.

- [x] **Step 6: warm simulator 后运行 UI test**

Run:

```sh
xcrun simctl boot "iPhone 17"
xcrun simctl bootstatus "iPhone 17" -b
```

If the simulator is already booted, continue.

Run:

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: ExamplesTests pass and ExamplesUITests initialize. If `Timed out waiting for AX loaded notification` recurs, record it as simulator infrastructure failure and keep the last `Examples` build plus core tests as the reliable verification signal.

Actual:

```sh
xcrun simctl boot "iPhone 17"
xcrun simctl bootstatus "iPhone 17" -b
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTask17ExamplesTestDerivedData test
```

Result: simulator bootstatus completed after roughly 53s. The full `Examples` test command entered UI testing but remained blocked in XCTest runner/app launch state and was interrupted after 422.326s with `TEST INTERRUPTED`.

Reliable V1 interaction signal:

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTask17TargetedUITestDerivedData -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -only-testing:ExamplesUITests/ExamplesUITests/testPullDownRevealsHeaderBeforeRowsOverscroll test
```

Result: `TEST SUCCEEDED`; 1 UI test passed in 29.698s.

- [x] **Task 17 complete**

## Task 18: V1 completion 文档和最终验证

**Files:**

- Modify: `docs/requirements-and-architecture.md`
- Modify: `docs/ui-design-and-animation-dsl.md`
- Modify: `docs/superpowers/plans/2026-07-03-collapsible-pager-v1.md`

**Acceptance:**

- 2026-07-04 审计中的待补齐项全部更新为已完成或保留明确未完成原因。
- `当前实现状态` notes 不再与源码冲突。
- Task 13 到 Task 17 的 checkbox 与实际验证结果一致。
- 核心测试通过。
- 示例 App build 通过。
- 旧术语扫描无匹配。

- [x] **Step 1: 更新审计摘要**

In `docs/superpowers/plans/2026-07-03-collapsible-pager-v1.md`, update `当前开发审计（2026-07-04）` so completed Task 13-17 items move from “待补齐或需复核” to “已验证完成”.

Actual: Task 13 到 Task 17 已全部移入“已验证完成”；完整 UI suite 的 simulator/XCTest runner 风险保留在“待补齐或需复核”，并附上具体命令和结果。

- [x] **Step 2: 扫描旧术语**

Run:

```sh
rg "RefreshableChild|DidTriggerRefresh|UIRefreshControl.*必须|deferredUntilIdle|selectedIndex: Int\\?" docs Sources Tests -g '!docs/superpowers/plans/2026-07-03-collapsible-pager-v1.md'
```

Expected: no matches.

Actual:

```sh
rg -n "RefreshableChild|DidTriggerRefresh|UIRefreshControl.*必须|deferredUntilIdle|selectedIndex: Int\\?" docs Sources Tests -g '!docs/superpowers/plans/2026-07-03-collapsible-pager-v1.md'
```

Result: no matches.

- [x] **Step 3: 运行格式检查**

Run:

```sh
git diff --check
```

Expected: no output.

Actual: no output.

- [x] **Step 4: 运行核心测试**

Run:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `TEST SUCCEEDED`.

Actual:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTask18CoreDerivedData test
```

Result: `TEST SUCCEEDED`; Swift Testing reported 77 tests passed.

- [x] **Step 5: 运行示例构建**

Run:

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' build
```

Expected: `BUILD SUCCEEDED`.

Actual:

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerTask18ExamplesBuildDerivedData build
```

Result: `BUILD SUCCEEDED`.

- [x] **Step 6: 审查 diff**

Run:

```sh
git status --short
git diff -- docs Sources Tests Examples
```

Expected: only V1 completion related files changed.

Actual: `git status --short` and `git diff --stat -- docs Sources Tests Examples` only show V1 completion related source, test, Example and documentation files.

- [x] **Task 18 complete**

## 2026-07-04 下拉 UI 异常修复

用户截图显示 Header 完全展开或下拉展开过程中，`CollapsiblePager Demo` 标题被 TabBar 覆盖。根因是 `HeaderMountView` 作为 child scroll spacer 的高度包含 `Header max height + TabBar height`，但 `HeaderHostView` 在展开稳定态填满了整个 mount，导致 Header 内容进入底部 TabBar 预留区。

修复边界：子页面自己的系统 `UIRefreshControl` 必须保留；本次不通过自定义 refresh view 替换 UIKit 原生刷新控件。核心只修正 Header 视觉宿主的尺寸与层级，刷新控件类型、刷新任务和结束时机继续归外部 child 拥有。

- [x] **Step 1: 先写回归测试**

Add `expandedHeaderHostInsideChildMountDoesNotCoverTabBarSpacer` to `Tests/CollapsiblePagerTests/ContainerIntegrationTests.swift`:

- `HeaderMountView.bounds.height == Header max height + TabBar height`
- `HeaderHostView.frame.height == Header max height`

Red run:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerPullDownOverlapRedFullDerivedData test
```

Actual: 新增测试按预期失败，`HeaderHostView.frame.height` 为 `308`，期望为 `260`。

- [x] **Step 2: 修正 Header host frame**

`CollapsiblePagerHeaderHostCoordinator.moveHost(to:frame:reason:)` 支持显式 frame。`CollapsiblePagerViewController.updateHeaderHostPlacement(reason:)` 在 host 挂回 current child `HeaderMountView` 时传入 Header-only frame：`height = childContentInset.top - tabBarHeight`。fixed overlay 场景继续使用 fixed container bounds。

- [x] **Step 3: 验证**

Green run:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerPullDownOverlapGreenDerivedData test
```

Actual: `TEST SUCCEEDED`，Swift Testing `78 tests` 通过。

2026-07-04 根据“子控制的 `UIRefreshControl` 要保留”的约束校正示例后复验：

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerPullDownUIFixCoreDerivedData test
```

Actual: `TEST SUCCEEDED`，Swift Testing `78 tests` 通过。

- [x] **Step 4: 保留示例 child 的 UIRefreshControl**

`Examples/Examples/DemoRefreshController.swift` 继续创建并安装系统 `UIRefreshControl`。新增 `demoRefreshControlIsPreservedAsChildOwnedUIKitControl`，防止示例层再次用自定义 refresh view 替代 child 拥有的原生控件。

Red/green 备注：Examples 单测 runner 在本机模拟器上仍会卡在 worker materialize 阶段；2026-07-04 23:30 的定向 run 被中断，结果为 `TEST INTERRUPTED`，日志显示 `waiting for workers to materialize` / `Waiting for -runningDidFinish call`。该测试契约通过 Examples build 编译验证，交互行为以核心测试和手动/定向 UI 验收继续覆盖。

Examples build：

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerPullDownUIFixExamplesBuildDerivedData build
```

Actual: `BUILD SUCCEEDED`。

## 2026-07-05 顶部 bounce 时 TabBar 位置修复

用户确认异常发生在“下拉到最顶部还能下拉”的 `UIScrollView.bounces` 阶段。此时 child scroll content 会继续下移，但 `CollapsiblePagerTabBarView` 是 fixed overlay；如果 Header 仍挂在当前 child 的 `HeaderMountView`，Header 会跟随 child content 下移并与固定 TabBar 发生视觉错位。

修复边界保持不变：子控制器自己的系统 `UIRefreshControl` 必须保留；核心不读取、不模拟外部刷新控件字段。顶部 bounce 只作为 Header 宿主迁移条件，刷新控件类型、刷新任务和结束时机继续归 child 拥有。

- [x] **Step 1: 写回归测试并确认 red**

Add `topBounceKeepsHeaderHostInFixedOverlayToAvoidTabBarOverlap` to `Tests/CollapsiblePagerTests/ContainerIntegrationTests.swift`:

- `refreshHandoffMode = .none` 时，顶部 bounce 不应开始 refresh handoff。
- `contentOffset.y < -managedTopInset` 时，`HeaderHostView` 应临时进入 `FixedHeaderContainer`。
- 回到 `contentOffset.y == -managedTopInset` 后，`HeaderHostView` 应回到当前 child 的 `HeaderMountView`。

Red run:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTabBarBounceRedFullDerivedData test
```

Actual: 新增测试按预期失败，`headerHostSuperviewForTesting` 仍是 `HeaderMountView`，期望为 `FixedHeaderContainer`。

- [x] **Step 2: 修复 Header host placement**

`CollapsiblePagerViewController.handleChildScrollViewDidScroll(_:)` 在 `PinAnchor` 未变化时也重新评估 Header 宿主位置。`updateHeaderHostPlacement(reason:)` 新增当前 child 顶部 bounce 判定：`scrollView.contentOffset.y < -layoutOutput.childContentInset.top`。进入 bounce 或已有 active refresh handoff 时使用 fixed overlay；回到 managed top boundary 后恢复当前 child mount。

- [x] **Step 3: 验证**

Core test:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerTabBarBounceGreenDerivedData test
```

Actual: `TEST SUCCEEDED`，Swift Testing `79 tests` 通过。

Examples build:

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerTabBarBounceExamplesBuildDerivedData build
```

Actual: `BUILD SUCCEEDED`。

## 2026-07-05 CollapsiblePagerRefreshHandoffMode 示例验证页

用户要求新增页面和 TabItem，用于验证 `CollapsiblePagerRefreshHandoffMode` 的所有情况。由于 `refreshHandoffMode` 是 `CollapsiblePagerViewController` 级配置，不是单个 child page 配置，本次在示例 App 根 `UITabBarController` 新增 `Refresh` tab；该 tab 内部用导航栏 mode menu 在三个独立 pager 间切换，分别配置 `.none`、`.container`、`.child`。

修复边界：示例 App 使用系统 `UIRefreshControl` 只是业务侧演示；`.container` 挂到 `containerRefreshHostScrollView`，`.child` 挂到 child 自己的 table view。`.none` 只验证核心不开始 refresh handoff，不代表框架会移除业务已有刷新机制。

- [x] **Step 1: 写示例回归测试并确认 red**

Add `refreshHandoffModeValidationTabCoversAllModes` to `Examples/ExamplesTests/ExamplesTests.swift`:

- root tab count 为 2。
- 第二个 root tab title 为 `Refresh`。
- `DemoRefreshHandoffModeViewController.availableRefreshHandoffModesForTesting == [.none, .container, .child]`。
- 三个内部 pager 的 `configuration.refreshHandoffMode` 分别匹配对应 mode。

Red run:

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerRefreshHandoffModesRedDerivedData -only-testing:ExamplesTests/ExamplesTests/refreshHandoffModeValidationTabCoversAllModes test
```

Actual: 按预期编译失败，`Cannot find type 'DemoRefreshHandoffModeViewController' in scope`。

- [x] **Step 2: 实现 Refresh 根 Tab**

`DemoPagerFactory.makeApplicationRoot(dataSource:)` 新增第二个 `UINavigationController` root tab，tab title 为 `Refresh`。`DemoRefreshHandoffModeViewController` 使用导航栏 mode menu 切换三个独立 `CollapsiblePagerViewController`，menu title 显示当前 mode；每个 pager 持有自己的 `DemoRefreshHandoffModeDataSource`，并配置对应 `CollapsiblePagerRefreshHandoffMode`。`DemoHeaderView` 新增 `setTitle(_:subtitle:)`，用于在示例 header 中显示当前验证 mode。

- [x] **Step 3: 补 UI 验收入口**

`ExamplesUITests.testRefreshHandoffModeTabSwitchesAllModes` 覆盖 `Refresh` tab、导航栏 mode menu，以及 `None`、`Container`、`Child` 三个页面标题和 table accessibility id。

- [x] **Step 4: 验证**

Examples test run:

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerRefreshHandoffModesGreenDerivedData -only-testing:ExamplesTests/ExamplesTests/refreshHandoffModeValidationTabCoversAllModes test
```

Actual: app/test targets 编译通过后，测试 runner 在本机模拟器上卡在 `waiting for workers to materialize` / `Waiting for -runningDidFinish call`，最终 `TEST INTERRUPTED`。这是既有 Examples runner 卡顿，不是 Swift 编译错误。

Examples build:

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerRefreshHandoffModesExamplesBuildDerivedData build
```

Actual: `BUILD SUCCEEDED`。

Examples build-for-testing:

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerRefreshHandoffModesBuildForTestingDerivedData build-for-testing
```

Actual: `TEST BUILD SUCCEEDED`，确认新增 Examples 单测与 UI 测试目标均可编译、链接和打包。

## 2026-07-05 嵌入式 pager 导航栏坐标修复

用户在 `Refresh` tab 截图中反馈 UI frame 不对：内容区 mode control 下方出现异常大空白，Header/TabBar 被整体下推。根因是 `CollapsiblePagerViewController.navigationBarMaxY()` 直接读取 `navigationBar.frame.maxY`；该 frame 属于 `UINavigationController` 坐标系，而 layout engine 需要的是 `pager.view` 本地坐标。对于 `DemoRefreshHandoffModeViewController` 这种“导航栏 root VC 内再嵌入 pager”的场景，外层导航栏 y 值被错误当成本地 y 值使用，导致 content viewport 重复避让顶部 chrome。

- [x] **Step 1: 增加嵌入式 frame 回归测试**

`Tests/CollapsiblePagerTests/ContainerIntegrationTests.swift` 新增 `embeddedPagerPinsHeaderToOwnBoundsWhenPlacedBelowNavigationChrome`，构造 `UINavigationController -> host UIViewController -> embedded CollapsiblePagerViewController`，验证嵌入在导航栏下方时 `headerFrame.y == 0`、`tabBarFrame.y == header.maxHeight`。

Red 验证尝试：

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerEmbeddedFrameRedAllDerivedData test
```

Actual: Swift Testing 已开始执行并确认新增测试进入队列，但本机 runner 在 `waiting for workers to materialize` / `Waiting for -runningDidFinish call` 阶段卡住，最终手动中断；因此本次没有拿到完整 red failure 输出。

- [x] **Step 2: 修正导航栏坐标转换**

`navigationBarMaxY()` 改为 `navigationBar.convert(navigationBar.bounds, to: view).maxY`，确保 layout input 中的导航栏底部始终是 `CollapsiblePagerViewController.view` 的本地坐标。嵌入式 pager 位于导航栏下方时，转换后的 y 不再重复下推 Header/TabBar。

- [x] **Step 3: 同步文档与验证**

`docs/requirements-and-architecture.md` 和 `docs/ui-design-and-animation-dsl.md` 已补充 pinY / navigation bar maxY 的本地坐标约束。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/CollapsiblePagerEmbeddedFrameGreenBuildDerivedData build-for-testing
```

Actual: `TEST BUILD SUCCEEDED`。

## 2026-07-05 Refresh handoff 命名与 container host 调整

用户指出 `.container` 与 `.child` 都不能假设业务使用哪种刷新控件，也不能假设一定安装刷新控件。参考 NestedPageViewController 的纵向嵌套职责划分后，本项目把刷新配置重新表达为“handoff 能力路由”，而不是“刷新控件模式”。

- `CollapsiblePagerRefreshMode` 重命名为 `CollapsiblePagerRefreshHandoffMode`。
- `configuration.refreshMode` 重命名为 `configuration.refreshHandoffMode`。
- `.overall` 重命名为 `.container`，表示继续下拉路由到容器拥有的外层纵向 `containerRefreshHostScrollView`。
- `.child` 表示继续下拉保留在当前 child 的 `pagerScrollView`。
- 内部 `RefreshHandoff` 从 `externalScrollView(scope:index:)` 拆成 `.containerHost(index:)` 和 `.childScrollView(index:)`，避免把两个目标都模糊成“外部 scroll view”。
- 示例 App 的 `Refresh` tab 改为 `None / Container / Child`，系统 `UIRefreshControl` 只作为业务接入演示；核心包仍不创建、不要求、不结束任何刷新控件或刷新任务。

## 2026-07-05 Container refresh host reveal 基线修复

用户在 `.container` 示例页反馈下拉没有出现刷新。后续对 `.none -> .container` 切换异常继续排查后，确认更准确的 root cause 是：外层刷新 host、`PageContainerView` 和 `PinnedSurfaceView` 曾处在不同纵向坐标系里。把 child 的 managed top inset 复制给 container host，或在不同层级之间手动同步视觉位移，都会让刷新 reveal、TabBar 位置和 mode 切换状态之间产生隐式耦合。

修复策略：

- `containerRefreshHostScrollView` 作为真正的外层纵向刷新 host，包住 `PageContainerView` 和 `PinnedSurfaceView`。
- host 静止基线在无导航栏/无 safe area 顶部避让时为 `contentInset.top == 0`、`contentOffset.y == 0`；有导航栏或顶部 safe area 时需使用 content viewport 顶部作为 reveal 基线，见后续“Container refresh host reveal 基线对齐 pinY 修复”。
- child scroll view 仍独立使用 managed top inset 表达 Header/TabBar spacer；这个 inset 不同步给 container host。
- child overscroll 代理到 container host 时，host 只从 `0` 继续向负值移动，例如 overscroll `22` 时 host offset 为 `-22`。
- `PinnedSurfaceView` 不再单独参与 reveal；Header、TabBar 和 PageContainer 都由同一个 host 的 `contentOffset` 自然整体下移。
- `UIRefreshControl` 仍只在示例 App 业务层安装；核心库只保证 host 的 reveal 坐标系和 handoff 边界，不创建、不触发、不结束刷新任务。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' -derivedDataPath /tmp/CollapsiblePagerOuterHostGreenDerivedData test -quiet
```

Actual: exit code 0。

## 2026-07-05 Container 顶部内容下拉抖动修复

用户反馈在 `Container` child 内容顶部开始下拉时，顶部内容会出现下移抖动。Root cause 是 child scroll view 的 pan 先进入自身 top bounce，随后容器在 `handleChildScrollViewDidScroll(_:)` 中把 child offset 拉回 managed top boundary，并把 overscroll 代理给 container host；同一手势内两套 offset 修正交替生效，造成视觉抖动。

修复策略：

- loaded child 的 `panGestureRecognizer` 通过 `require(toFail:)` 等待 `containerRefreshHostScrollView.panGestureRecognizer` 失败。
- container host pan 仍只在 `.container`、Header 完全展开、current child 到达 managed top boundary 且手势为下拉时 begin。
- 不满足 host begin 条件时 host pan 快速失败，child pan 正常滚动；满足条件时 host 直接接管继续下拉，child 不再先产生 top bounce。
- 新增 `containerRefreshHostPanHasPriorityOverLoadedChildPan` 回归测试，锁住该手势优先级链路。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' -derivedDataPath /tmp/CollapsiblePagerContainerPanPriorityGreenDerivedData test -quiet
```

Actual: exit code 0。

## 2026-07-05 Container handoff 手势与整体视觉联动修复

用户要求 `CollapsiblePagerRefreshHandoffMode` 的手势处理继续参考 NestedPageViewController，并反馈 `.container` 下拉后 TabBar 与 page content 之间仍会出现异常空白。对照 NestedPageViewController 的结论是：顶部 bounce / refresh reveal 期间不能让 Header 固定在一套坐标，而 page content 使用另一套 offset；外层纵向 handoff 必须成为唯一 reveal 来源，并让 Header/TabBar/Page 内容保持整体联动。

Red:

```swift
#expect(pager.headerFrameForTesting.minY == initialHeaderFrame.minY + 22)
#expect(pager.tabBarFrameForTesting.minY == pager.headerFrameForTesting.maxY)
```

该断言先失败，实际 `headerFrameForTesting.minY == 0`，说明 child overscroll 已代理到 container host，但 pinned surface 没有跟随 host overscroll 下移。

修复策略：

- `CollapsiblePagerViewController` 将 `PinnedSurfaceView` 和 `PageContainerView` 一起挂到 `containerRefreshHostScrollView`，使 Header、TabBar 和 PageContainer 共享同一个外层纵向 reveal 坐标系。
- 布局 pass 只设置 `PinnedSurfaceView.frame = view.bounds`；测试锁住 `.container` overscroll 后 Header、TabBar 与 PageContainer 的同层级整体位移。
- child 直接进入 top bounce 的兜底路径保存 `containerRefreshProxyOverscrollOffsetY`，即使 host 在 idle 布局中被 UIKit 临时校正回 baseline，也不会误判 handoff 结束。
- `CollapsiblePagerContainerRefreshHostScrollView` 不再在相同 `contentSize` 的布局 pass 中重复赋值，减少 UIScrollView 对 idle overscroll 的额外校正。
- 文档同步明确：核心只暴露 container-owned refresh host / 外层纵向刷新层能力，不创建、不假设、不结束任何刷新控件；`.child` 同样只保留当前 child scroll view 的能力路由。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' -derivedDataPath /tmp/CollapsiblePagerDerivedData-green test -quiet
```

Actual: exit code 0。

## 2026-07-05 Container 内容区下拉回跳修复

用户反馈在 `CollapsiblePagerTabBarContentView` 底部下方的 child 内容区域开始下拉时，内容先被拉下又跳回。截图中 `Collapse: 1%` 表明 Header 接近但尚未完全展开；此时 container host pan 不会 begin，手势先由 child scroll view 接管。child 继续下拉使 Header 展开到 `collapseProgress == 0` 后，框架会把 child overscroll 代理给 `containerRefreshHostScrollView`，并把 child 拉回 managed top boundary。

Root cause 是代理路径只保存了 `containerRefreshProxyOverscrollOffsetY`，但当 `containerRefreshHostScrollView` 作为 idle scroll view 被 UIKit 临时校正回 neutral baseline 时，`handleContainerRefreshHostDidScroll(_:)` 只尝试开始 handoff，没有恢复保存的 proxy offset。视觉上就是 Header、TabBar 和 page content 刚整体下移，又被 host baseline 校正拉回去。

修复策略：

- 新增回归测试 `proxiedContainerRefreshOverscrollSurvivesIdleHostBaselineCorrection`，复现 Header 仍有 1% collapse 时从 child 内容区继续下拉，再模拟 idle host 被校正回 baseline 的情况。
- 在 container host `didScroll` 中，如果仍存在 `containerRefreshProxyOverscrollOffsetY < 0` 且 host 还使用 neutral refresh inset，则把 host offset 恢复到保存的 proxy overscroll。
- 恢复逻辑只处理框架代理的 `.container` reveal，不创建、不假设、不结束业务刷新控件；业务刷新机制修改 content inset 后不会被该恢复分支抢回。
- 文档同步明确：同一手势中的 proxy overscroll 是唯一 reveal 源值，idle host baseline 校正不能打断整体下移。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' -derivedDataPath /tmp/CollapsiblePagerContentPullJumpGreenTargetDerivedData -only-testing:CollapsiblePagerTests/proxiedContainerRefreshOverscrollSurvivesIdleHostBaselineCorrection test -quiet
```

Actual: exit code 0。

## 2026-07-05 None 切换 Container 层级修复

用户反馈从 `None` 切换到 `Container` 后出现 UI frame 异常：Header 消失，`CollapsiblePagerTabBarView` 掉到列表中间。该问题与上面的 reveal 坐标系一致：mode 切换会重置 refresh handoff 和 host offset，如果 host、page、pinned surface 分属不同坐标层，旧的 offset 修正会把 TabBar 和列表拆开。

修复策略：

- `.container` host 层级固定为外层 scroll host，始终同时包住 `PageContainerView` 和 `PinnedSurfaceView`，不因 mode 切换临时改层级。
- 从任意 `CollapsiblePagerRefreshHandoffMode` 切到 `.container` 时，只重置 handoff 状态、proxy overscroll 和 host offset，不对 pinned surface 写入额外视觉位移。
- 回归测试覆盖 host neutral baseline、pinned surface superview、container overscroll offset，以及 Header/TabBar 在 host overscroll 下的整体位移。

## 2026-07-05 Header 区域下拉刷新策略

用户反馈手放在 Header 区域下拉时，`.child` 示例会拉出 child 刷新控件，并要求新增策略。设计结论：默认保持 UIKit 兼容行为；新增 `CollapsiblePagerHeaderPullDownRefreshBehavior`，业务可选择在 Header 区域下拉时不触发 child 自有刷新 reveal。

Red:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' -derivedDataPath /tmp/CollapsiblePagerHeaderGateRedDerivedData test -quiet
```

Actual: 编译失败，缺少 `headerPullDownRefreshBehavior`、`headerPullDownGateHasPriorityOverChildPanForTesting` 和 `shouldBeginHeaderPullDownGateForTesting`，证明测试先于实现。

修复策略：

- `CollapsiblePagerConfiguration` 新增 `headerPullDownRefreshBehavior`，默认 `.allowsChildRefresh`，保持现有行为。
- 新增 `.suppressesChildRefresh` 策略：Header host 安装内部向下拖拽 gate，loaded child 的 pan gesture 等待 gate 失败。
- gate 只在策略开启、非 `.container`、Header 完全展开、current child 到 managed top boundary、手势为向下纵向拖拽时 begin。
- gate begin 后 child pan 不进入 top bounce，因此不会从 Header 区域拉出 child 自有刷新控件；child 内容区域下拉不受影响。
- 示例 App 的 Refresh / Child pager 开启该策略，便于模拟器验证 Header 区域下拉不拉出 child refresh，内容区下拉仍保持 child refresh。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' -derivedDataPath /tmp/CollapsiblePagerHeaderGateGreenDerivedData test -quiet
```

Actual: exit code 0。

## 2026-07-05 Scroll indicator bottom inset 修复

用户反馈列表内容已经滚到底部时，右侧 vertical scroll indicator thumb 停在页面中部偏下，没有靠近底部 TabBar / safe area。Root cause 是 child scroll view 在被 Pager 接管前可能已经被 UIKit 自动计算过较大的 `verticalScrollIndicatorInsets.bottom`；Pager 设置 `contentInsetAdjustmentBehavior = .never` 后仍通过 `max(baseScrollIndicatorInsets.bottom, layoutBottomInset)` 保留这个旧值，导致 indicator 轨道底部被错误抬高。

后续复查同一截图后，确认还存在第二层原因：`contentInsetAdjustmentBehavior = .never` 只关闭内容 inset 自动调整，不会关闭 iOS 13+ 的 `automaticallyAdjustsScrollIndicatorInsets`。如果该开关仍为 `true`，UIKit 仍可能继续给 indicator 追加 safe area / bar 避让，和 Pager 手动写入的 indicator inset 叠加。

修复策略：

- child content bottom inset 继续按短内容补偿和 layout bottom inset 计算，保证滚动范围不变。
- vertical scroll indicator bottom inset 改为只跟随 layout bottom inset / safe area bottom，不保留接管前的旧自动调整值。
- Pager 接管 child scroll view 时设置 `automaticallyAdjustsScrollIndicatorInsets = false`，确保 indicator 轨道只由 layout 输出决定。
- `ChildStoreTests` 新增回归用例，覆盖初次接管和后续 `updateManagedInset` 时 stale bottom indicator inset 都会被替换。
- `ChildStoreTests` 同步覆盖系统自动 indicator inset 调整开关，防止 UIKit 自动调整和 Pager 手动 inset 叠加。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' -derivedDataPath /tmp/CollapsiblePagerIndicatorGreenDerivedData test -quiet
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' -derivedDataPath /tmp/CollapsiblePagerIndicatorAutoGreenDerivedData test -quiet
```

Actual: exit code 0。

## 2026-07-05 Push 隐藏 UITabBar 的 indicator 回归测试

用户要求补充 `push` 后隐藏底部 `UITabBar` 的覆盖。该场景会让 `CollapsiblePagerViewController.view.safeAreaInsets.bottom` 从 TabBar 可见时的底部避让切到 TabBar 隐藏后的 safe area bottom；Pager 必须在布局更新后把新的 bottom inset 同步给当前 child 的 content inset 与 vertical scroll indicator inset。

新增测试：

- `pushedPagerWithHiddenBottomBarUpdatesChildScrollIndicatorInset`
- 构造真实 `UITabBarController -> UINavigationController -> root CollapsiblePagerViewController`。
- push 一个 `hidesBottomBarWhenPushed = true` 的 `CollapsiblePagerViewController`。
- 验证 pushed pager 的 `safeAreaInsets.bottom` 小于 root pager 的 TabBar 可见 bottom inset。
- 验证 pushed child 的 `automaticallyAdjustsScrollIndicatorInsets == false`，且 `verticalScrollIndicatorInsets.bottom == pushedPager.view.safeAreaInsets.bottom`。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' -derivedDataPath /tmp/CollapsiblePagerHiddenTabBarIndicatorDerivedData test -quiet
```

Actual: exit code 0。

## 2026-07-05 示例 push 隐藏 UITabBar 接入修复

用户在示例 App 中验证 push 场景时发现 `Pushed Pager` 仍显示底部 `UITabBar`。全面核对后确认：

- 核心层已通过 `pushedPagerWithHiddenBottomBarUpdatesChildScrollIndicatorInset` 覆盖 `hidesBottomBarWhenPushed = true` 后的 safe area 与 indicator inset 更新。
- 示例 App 的 `DemoPagerNavigationController.pushPagerFromButton(_:)` 创建 pushed pager 时漏设 `hidesBottomBarWhenPushed`，导致实际 UI 仍保留底栏。

调整：

- 在 `pushViewController` 之前设置 `pager.hidesBottomBarWhenPushed = true`。
- 在 `ExamplesTests.navigationBarButtonPushesPagerAndKeepsBackGestureEnabled` 中断言 pushed pager 的 `hidesBottomBarWhenPushed`，防止示例入口回退。

Verification notes:

- `-only-testing:ExamplesTests/ExamplesTests/navigationBarButtonPushesPagerAndKeepsBackGestureEnabled` 生成的 xcresult 显示 `totalTestCount: 0`，不能作为有效红灯/绿灯依据。
- `-only-testing:ExamplesTests` 在当前模拟器环境中卡在 `waiting for workers to materialize`，120s 后手动中断；该问题属于示例测试 runner 启动稳定性风险，后续优先用可完成的 build 验证接入改动。
- `xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerHideTabBarBuildDerivedData build -quiet` 通过。
- `xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerHideTabBarBuildForTestingDerivedData build-for-testing -quiet` 通过。

## 2026-07-05 默认整体刷新体验

用户确认希望 `CollapsiblePagerRefreshHandoffMode` 默认采用整体刷新体验。设计结论：

- `CollapsiblePagerConfiguration.default.refreshHandoffMode` 从 `.none` 改为 `.container`。
- 默认行为只改变 handoff 路由：Header 完全展开后继续下拉交给容器拥有的 `containerRefreshHostScrollView`。
- 核心仍不创建刷新控件、不触发刷新回调、不结束刷新任务；业务决定是否在 `containerRefreshHostScrollView` 上安装自己的刷新机制。
- `.none` 保留为显式关闭 handoff 的模式，适合业务完全依赖 child 自身 scroll 行为或自定义手势处理的场景。
- 示例 App 主 Pager 不再强制 `.child`，改用默认 `.container`，并在 `containerRefreshHostScrollView` 上安装演示用 `UIRefreshControl`；`Refresh` 验证页继续保留 `.none / .container / .child` 三种对照。

Red:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' -derivedDataPath /tmp/CollapsiblePagerDefaultContainerRedDerivedData test -quiet
```

Actual: `TEST FAILED`，xcresult 摘要显示 `defaultConfigurationMatchesV1Defaults()` 失败，`configuration.refreshHandoffMode` 实际为 `.none`，期望 `.container`。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' -derivedDataPath /tmp/CollapsiblePagerDefaultContainerGreenDerivedData test -quiet
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerDefaultContainerExamplesBuildDerivedData build -quiet
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerDefaultContainerExamplesBuildForTestingDerivedData build-for-testing -quiet
```

Actual: 核心测试 xcresult 摘要显示 `totalTestCount: 89`、`failedTests: 0`；Examples build 与 build-for-testing 均 exit code 0。

## 2026-07-05 Container refresh host reveal 基线对齐 pinY 修复

用户反馈默认整体刷新后，示例 `UIRefreshControl` 文案显示在状态栏/导航标题附近，位置怪异。全面分析后确认：

- `containerRefreshHostScrollView` 作为外层纵向 host 包住 Header、TabBar 和 PageContainer。
- 上一版 host 静止基线固定为 `contentInset.top == 0`、`contentOffset.y == 0`。
- 有导航栏时，layout engine 的真实 content viewport 顶部是 `pinY = max(navigationBar.maxY, safeArea.top) + offset`，例如测试环境中为 `116pt`。
- 示例 `UIRefreshControl` 按宿主 scroll view 的 top inset / content offset 计算 reveal 位置；host top inset 仍为 `0` 时，刷新控件会从容器最顶部 reveal，落到状态栏或导航栏区域。

修复策略：

- host 的刷新 reveal 基线对齐 `pinY`：静止时 `contentInset.top == pinY`、`contentOffset.y == -pinY`。
- host 内部内容层反向平移 `-pinY`，确保 Header、TabBar、PageContainer 的屏幕 frame 不变。
- 下拉距离继续用 `contentOffset.y - neutralBaselineContentOffsetY` 表达；neutral baseline 从 `0` 泛化为 `-pinY`。
- `usesNeutralRefreshContentInset()` 改为比较业务刷新控件未额外修改前的 configured baseline，避免把正常 pinY inset 误判为刷新控件正在改 inset。
- 主示例刷新控件文案统一为 `Container refresh`，与默认 `.container` handoff 语义保持一致。

Red:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' -derivedDataPath /tmp/CollapsiblePagerRefreshBaselineRedDerivedData test -quiet
```

Actual: `TEST FAILED`，xcresult 摘要显示 `containerRefreshHostBaselineStartsBelowNavigationChrome()` 失败，`host.contentInset.top` 实际为 `0`，期望为导航栏底部 `116`。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' -derivedDataPath /tmp/CollapsiblePagerRefreshBaselineGreenDerivedData test -quiet
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerRefreshBaselineExamplesBuildDerivedData build -quiet
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerRefreshBaselineExamplesBuildForTestingDerivedData build-for-testing -quiet
```

Actual: 核心测试 xcresult 摘要显示 `totalTestCount: 90`、`failedTests: 0`；Examples build 与 build-for-testing 均 exit code 0。

## 2026-07-05 Refresh Handoff 验证页切换入口改为导航栏 menu

用户要求把 `Refresh Handoff` 页面内容区的 mode 切换控件替换为导航栏 menu，并在导航栏上显示当前 mode。

调整：

- 移除 `DemoRefreshHandoffModeViewController` 内容区的 mode control，`pagerContainerView` 直接贴到 safe area 顶部。
- `navigationItem.rightBarButtonItem` 改为 mode menu，title 显示当前 `None / Container / Child`。
- 选择 menu item 后复用原有 `selectMode(at:)`，只切换当前独立 pager，不改变各 mode pager 的配置语义。
- iOS 14+ 使用 `UIMenu`；iOS 13 fallback 为 `UIAlertController` action sheet，保持最低系统版本兼容。
- 示例单元测试和 UI 测试同步改为验证导航栏 mode menu，并断言旧内容区切换控件不存在。

Red:

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerMenuModeRedDerivedData build-for-testing -quiet
```

Actual: `TEST BUILD FAILED`，缺少 `selectRefreshHandoffModeForTesting(_:)` 和 `demoTitleForTesting`，证明测试先于实现。

Verification:

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerMenuModeGreenBuildForTestingDerivedData build-for-testing -quiet
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerMenuModeExamplesBuildDerivedData build -quiet
```

Actual: Examples build 与 build-for-testing 均 exit code 0。

## 2026-07-05 CollapsiblePagerViewController open 子类化契约

用户要求 `CollapsiblePagerViewController` 修饰符改为 `open`，并按情况调整类内属性和方法修饰符。

设计结论：

- `CollapsiblePagerViewController` 从 `public final` 改为 `open`，允许业务侧继承。
- 支持外部 override 的范围限定在 UIKit 生命周期入口：`viewDidLoad`、`viewWillAppear`、`viewDidAppear`、`viewWillDisappear`、`viewDidDisappear`、`viewDidLayoutSubviews` 和 `shouldAutomaticallyForwardAppearanceMethods`。
- 业务稳定入口仍保持 `public`：`dataSource`、`delegate`、`configuration`、`selectedIndex`、`effectiveSelectedIndex`、`containerRefreshHostScrollView`、`reloadData()`、`selectPage(at:animated:)` 和 `reloadHeaderLayout(offsetPolicy:)`。这些 API 可调用，但不作为外部 override 点，避免子类绕开内部状态机。
- API 注释和架构文档同步说明：业务子类 override 生命周期时必须调用 `super`，否则会破坏内部布局、child containment 和 appearance transition。

Red:

```sh
xcodebuild -scheme CollapsiblePager -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerOpenSubclassRedDerivedData build-for-testing -quiet
```

Actual: `TEST BUILD FAILED`，外部普通 `import CollapsiblePager` 测试无法继承 `final` 类，也无法 override non-open 生命周期方法。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerOpenSubclassGreenBuildForTestingDerivedData build-for-testing -quiet
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' -derivedDataPath /tmp/CollapsiblePagerOpenSubclassGreenTestDerivedData test -quiet
```

Actual: build-for-testing exit code 0；核心测试 exit code 0。

## 2026-07-05 Container proxy handoff 退出时机修复

用户提供下拉日志后，继续按触摸区域和 handoff 状态排查。关键日志形态：

- `containerPan shouldBegin=false reason=headerNotExpanded` 出现时，`activeHandoff` 仍为 `.containerHost`。
- `containerRefreshProxyOverscrollOffsetY` 仍为负值，`hostRestoreProxy` 持续恢复旧 proxy。
- Header 已经不再 fully expanded，但旧 handoff 仍让 Header 固定在 overlay，导致从内容区或 Header 区继续下拉时出现回跳或不移动。

Root cause：`.container` 代理 overscroll 的退出条件对 Header 未展开场景过晚。旧逻辑主要等 child 和 host 都 idle 后才 finish；真实手势中 child 还处于 tracking/dragging，Header 已经重新进入未完全展开，过期 `.containerHost` handoff 仍残留，继续影响 Header host placement 和 host offset 恢复。

调整：

- 新增回归测试 `proxiedContainerRefreshOverscrollCancelsWhenChildLeavesExpandedTop`，用测试专用 `TrackingScrollView` 模拟手指仍按住的 child dragging 状态。
- `routeContainerRefreshOverscrollFromChild` 在 Header 重新进入未完全展开状态时，取消已经建立的 container proxy handoff。
- 取消只在 `containerRefreshHostScrollView` 仍使用 neutral refresh inset 时执行；业务刷新机制已经修改 inset 后，核心不抢回 offset。
- 取消时同步清空 active handoff、proxy overscroll，并把 host offset 还原到 neutral baseline，随后刷新 Header host placement。
- 内部 `route` 设置 proxy 但尚未 begin handoff 的瞬时状态不触发取消，避免破坏既有 `proxiedContainerRefreshOverscrollSurvivesIdleHostBaselineCorrection` 语义。

Red:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' test -quiet
```

Actual: 新增 tracking 场景下测试失败，复现手指未松开时旧 `.containerHost` handoff 未及时退出的问题。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' test -quiet
```

Actual: 核心测试 exit code 0。

## 2026-07-05 Container proxy boundary cancel 条件收窄

用户继续提供内容区下拉日志后，确认上一轮把 `childReturnedToBoundary` 作为取消条件过宽。关键日志形态是同一次手势内反复出现：

- `childProxy cancel reason=childReturnedToBoundary`
- `childProxy route`
- `containerHandoff resetFromHost`

Root cause：Header 已完全展开时，child 被框架 clamp 回 managed top boundary 是 `.container` 代理路径的正常状态；此时 child 不应该拥有自身 top bounce，container host / proxy overscroll 才是唯一 reveal 源值。把 boundary clamp 当作取消条件，会让 active handoff 被清空，下一帧又因为 child 仍在下拉重新 route，形成 cancel / route / reset 循环，表现为内容区域先下移再跳回。

调整：

- `routeContainerRefreshOverscrollFromChild` 先处理 `headerNotExpanded` 取消；只有 Header 重新进入未展开状态时才抢回 neutral container handoff。
- child 回到 managed top boundary 的分支不再取消 handoff，只在 child 与 host 都 idle 且业务刷新机制未接管 content inset 时执行 finish reset。
- 新增回归测试 `proxiedContainerRefreshOverscrollUpdatesProxyWhileTrackedChildOverscrollChanges`，覆盖手指仍 tracking/dragging 时 child overscroll 从 `-330` 收回到 `-309` 的过程，断言 active handoff 仍为 `.containerHost`，host/proxy offset 更新为 `-1`。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' test -quiet
```

Actual: 核心测试 exit code 0。

## 2026-07-05 Container/Header 下拉 shouldBegin 意图判断修复

用户继续提供触摸区域日志后，确认内容区下拉仍有进入 child proxy 路径的情况。关键日志：

- `containerPan shouldBegin=false region=content translation=(0.00,0.00) velocity=(0.00,159.83)`
- 同一行中 `childOffsetY == boundaryY`，`activeHandoff == .containerHost`，说明 host 本应继续拥有整体下拉入口。
- 后续进入 `childProxy route`，造成 child 代理路径与 host offset 同步继续交替。

Root cause：`containerRefreshHostScrollView` 和 Header gate 的 shouldBegin 下拉意图只用 `translation.height > 0` 作为纵向下拉判断。UIKit 在 `gestureRecognizerShouldBegin(_:)` 的早期阶段可能还没有累积 translation，但 velocity 已经明确向下；此时 host pan 被误判为不开始，child pan 因等待失败而接管。

调整：

- 新增 `isVerticalPullDownIntent(translation:velocity:)`，translation 有有效位移时优先使用 translation；translation 尚未累积时使用 velocity 判断。
- container host pan 和 Header pull-down gate 共用该判断。
- DEBUG 日志新增 gesture state、pan view、hit-test view 和 owner role，便于下一次直接区分触摸落在 fixed header、tabBar、pageContainer、child scroll 还是 container host。
- 回归测试覆盖 `.container` host pan 与 Header gate 在 `translation == .zero`、`velocity.y > 0` 时仍应 begin。

Red:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' test
```

Actual: `containerRefreshHostPanRequiresContainerModeExpandedHeaderAndTopChild` 在新增 zero-translation 断言失败。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' test -quiet
```

Actual: 核心测试 exit code 0。

## 2026-07-05 Container host baseline reset 时机修复

用户继续提供触摸对象与区域日志，并要求参考 NestedPageViewController 梳理手势处理。关键日志形态：

- `containerPan gesture ... hitView=UITableViewCellContentView owner=childScroll[0]`
- `containerPan shouldBegin=true region=content ... activeHandoff=nil`
- `hostDidScroll offsetY=-117.67 baselineY=-116.00 ... activeHandoff=.containerHost`
- 紧接着 `containerHandoff resetFromHost offsetY=-116.00 baselineY=-116.00`
- 同一次下拉继续出现 `hostDidScroll offsetY=-123.00 ... activeHandoff=nil`，随后重新 `tryBegin`

Root cause：触摸区域识别本身是正确的，内容区触摸落在 child cell 上，但 `.container` 模式下 container host pan 有优先权并成功 begin。真正的问题是 host 已经成为本次下拉 owner 后，旧逻辑在 `scrollViewDidScroll` 里只要看到 host offset 回到 neutral baseline 就立即 `resetGesture()`。UIKit rubber-band 会在同一次 pan 中短暂经过 baseline，导致 active handoff 被清空，下一帧又因 host 继续 overscroll 重新开始，视觉上就是整体内容先下移又跳回或偶发不移动。

调整：

- 参考 NestedPageViewController 的“滚动 owner 持续到交互结束”思路，`handleContainerRefreshHostDidScroll(_:)` 只负责开始和维持 `.containerHost` reveal，不再在 didScroll baseline 点结束 handoff。
- `CollapsiblePagerContainerRefreshHostScrollView` 新增 scroll interaction end 回调，在 `scrollViewDidEndDragging`、`scrollViewDidEndDecelerating` 和 `scrollViewDidEndScrollingAnimation` 后统一尝试 idle finish。
- 新增 `finishContainerRefreshHostHandoffIfPossible`：只有 host 已回到 neutral baseline、proxy 已清空、业务刷新机制未接管 content inset，且 scroll view 已 idle 时，才 reset active handoff。
- DEBUG 日志补充 host pan state 和 tracking/dragging/decelerating 状态，下一次日志可直接区分 baseline 是手势中路过还是 idle 后结束。
- 新增回归测试 `activeContainerRefreshHostPanDoesNotResetWhenOffsetTouchesBaseline`，覆盖 host 建立 `.containerHost` 后 offset 碰到 baseline 不应立刻 reset，直到 end dragging 后才 finish。

Red:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' test -quiet
```

Actual: 新增测试先因缺少 host interaction end 回调编译失败；补齐回调后锁定 didScroll baseline 不再提前 reset。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' test -quiet
```

Actual: 核心测试 exit code 0。

## 2026-07-05 Container handoff owner 连续性修复

用户继续提供 Header 和内容区下拉日志。前一个 baseline reset 问题已不再出现，但仍可看到新的 owner 断裂形态：

- `activeHandoff=.containerHost`，`proxyY < 0` 或 `hostOffsetY < hostBaselineY`，说明整体下拉 reveal 尚未 idle finish。
- 新一次 `containerPan shouldBegin=false` 的 `translation=(0.00,0.00)` 且 `velocity=(0.00,0.00)`，触摸可发生在 Header 或 child cell 区域。
- host pan 随后进入 `failed`，child 继续 `childProxy route`，造成代理路径与 host offset 恢复交替，表现为下拉整体先动再跳回，或 Header 区域偶发不移动。

Root cause：`.container` handoff 已经成为当前 overscroll owner 后，shouldBegin 仍完全依赖本次 pan 的方向采样重新判断。UIKit 在 `gestureRecognizerShouldBegin(_:)` 早期可能尚未提供 translation 和 velocity；这时把 zero/zero 当作“不是下拉”会错误释放 container owner，让 child 重新接管并进入代理路径。

调整：

- `shouldBeginContainerRefreshHostPan` 增加 owner continuity 分支：当前 page 已有 `.containerHost` active handoff，且 host/proxy 仍处于 overscroll 时，只要 child 仍在 managed top boundary，就允许 container host pan begin。
- 该分支只延续已有 `.containerHost` owner，不扩大首次刷新触发条件；active handoff 和 overscroll 被 idle finish 清空后，下一次仍按方向、Header 展开和 child top 边界重新竞争。
- DEBUG 日志补充 `ownerContinuation`，下次可直接判断 shouldBegin 是方向触发还是已有 owner 续接。
- 新增回归测试 `activeContainerRefreshHostPanContinuesWhenInitialMotionIsZero`，覆盖 `translation == .zero`、`velocity == .zero`、`activeHandoff == .containerHost`、`proxyY < 0` 的场景。

Red:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' test
```

Actual: 新增测试失败在 `shouldBeginContainerRefreshHostPanForTesting(translation: .zero, velocity: .zero)`，日志显示 `ownerContinuation` 尚未实现时 `shouldBegin=false`。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' test -quiet
```

Actual: 核心测试 exit code 0。

## 2026-07-05 Container proxy 到 host owner 移交修复

用户继续反馈“首次下拉可以，然后上滑吸顶，然后下滑，移动不了”，并提供新的触摸对象日志。关键链路：

- 首次 Header 区域下拉正常：`containerPan shouldBegin=true`，`activeHandoff=.containerHost`，host offset 从 baseline 继续变小；业务刷新结束后出现 `finishFromHost`，active handoff 正常清空。
- 随后上滑吸顶，child offset 到 `597.67`，Header collapse 到 `1.00`。
- 再次下滑展开 Header 后，child 在 managed top boundary 附近产生兜底 overscroll，日志出现 `childProxy route ... hostOverscrollY=-27.00 ... proxyY=-27.00`，active handoff 重新变成 `.containerHost`。
- 后续真正的 `containerRefreshHostScrollView` pan 已经开始，日志显示 `ownerContinuation=true`、`panState=changed`，但 `hostRestoreProxy currentOffsetY=-164.67 expectedOffsetY=-143.00 proxyY=-27.00` 反复把 host 拉回旧 proxy 位置。

Root cause：上一轮修复只保证 `.containerHost` owner 连续，但没有在真实 host pan begin 时完成 proxy ownership 移交。`containerRefreshProxyOverscrollOffsetY` 仍保持 `-27`，`restoreContainerRefreshProxyOverscrollIfNeeded(for:)` 会把 host offset 持续恢复到 `baseline + proxy`，导致用户继续下拉时整体内容无法继续跟随手势移动。

调整：

- `CollapsiblePagerContainerRefreshHostScrollView.onRefreshPanWillBegin` 进入真实 host pan 前调用 `beginContainerRefreshHandoffFromHostIfNeeded(adoptingProxyOverscroll: true)`。
- 当当前 active handoff 已是 `.containerHost` 且存在负 proxy overscroll 时，host pan begin 会记录 `containerHandoff adoptProxy` 并清空 `containerRefreshProxyOverscrollOffsetY`。
- 非真实 host pan 的 `hostDidScroll` 维持原有 proxy restore 语义，避免 idle/recovery 阶段丢失整体 reveal 距离。
- 新增回归测试 `containerRefreshHostPanTakesOwnershipFromProxyOverscroll`：先让 child overscroll 代理到 container host，再让 host pan begin，断言 proxy 被清空，随后 host offset 可以继续小于 baseline 而不被 restore 回旧值。

Red:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' test
```

Actual: 新增测试先失败在 `containerRefreshProxyOverscrollOffsetY == -22` 未清空，并且 host offset 从 `baseline - 40` 被 restore 回旧 proxy 位置。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' test -quiet
```

Actual: 核心测试 exit code 0。

## 2026-07-05 Container refresh host baseline 上界修复

用户继续提供截图和日志，反馈 `CollapsiblePagerTabBarView` 看不见，且 child frame 位置不对。关键日志：

- `containerHandoff adoptProxy index=0 hostOffsetY=-143.33 proxyY=-27.33`
- 紧接着出现 `containerHandoff finishFromHost offsetY=0.00 baselineY=-116.00 proxyY=0.00`
- 之后 child 滚动日志持续显示 `hostOffsetY=0.00 hostBaselineY=-116.00`

Root cause：`containerRefreshHostScrollView` 的 neutral baseline 是 `-pinY`，但 host `contentSize == bounds.size` 时，UIKit 会认为它还有从 `-pinY` 到 `0` 的普通纵向滚动区间。active container handoff 结束或回弹校正时，host offset 可能停在 `0`。由于 `PinnedSurfaceView` 和 `PageContainerView` 都在 host 内容层内，`contentOffset.y = 0` 会把 Header、TabBar 和 child 内容整体向上推 `pinY`，表现为 TabBar 消失到导航栏/状态栏区域附近，child frame 起点也随之错误。

调整：

- `CollapsiblePagerContainerRefreshHostScrollView` 的 `contentSize.height` 改为 `bounds.height - configuredRefreshBaselineTop`，让 neutral baseline 成为正常滚动上界；host 只提供 refresh reveal 方向 overscroll。
- active `.containerHost` 期间，如果 UIKit 仍把 host offset 推到 neutral baseline 以上，`handleContainerRefreshHostDidScroll(_:)` 立即夹回 baseline，并保持 active handoff 到交互 idle finish。
- 新增回归测试 `activeContainerRefreshHostClampsAboveNeutralBaseline`，复现 `offsetY=0 baselineY=-116` 时 Header/TabBar frame 被上推的问题。
- 扩展 `containerRefreshHostBaselineStartsBelowNavigationChrome`，断言 host 的正常最大 offset 等于 neutral baseline，防止重新引入 `-pinY...0` 普通滚动区间。

Red:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' test
```

Actual: 新增测试失败，`host.contentOffset.y == 0` 而 baseline 是 `-116`；`headerFrameForTesting.y` 从 `116` 变为 `0`，`tabBarFrameForTesting.y` 从 `376` 变为 `260`。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' test -quiet
```

Actual: 核心测试 exit code 0。

## 2026-07-05 Container proxy pending overlay 空窗修复

用户继续反馈下拉后 `CollapsiblePagerTabBarView` 出现在列表内容中段，Header 内容不可见，截图中列表仍显示 `Long row 14...`，TabBar 却处在 Header 展开态附近。新的日志里出现关键空窗：

- `childProxy finishCheck ... proxyY=-35.33 ... activeHandoff=nil`
- `headerPlacement target=childMount reason=currentChild collapse=0.00 ... proxyY=-35.33 activeHandoff=nil`
- 紧接着才出现 `childProxy route ... proxyY=-35.33` 和 `headerPlacement target=fixed reason=refresh ... activeHandoff=.containerHost`
- 后续新 pan 的 hit view 是 `CollapsiblePagerTabItemView owner=tabBar`，位置已经落在内容区中段。

Root cause：`containerRefreshProxyOverscrollOffsetY < 0` 已经表示 child 顶部 overscroll 正在代理给 container reveal，但 `updateHeaderHostPlacement` 的 `shouldUseFixedOverlay` 条件只看 active handoff，没有把 pending proxy overscroll 纳入 fixed overlay 生命周期。于是 child 被拉回 managed top boundary 的同步回调中，active handoff 尚未提交，Header host 会短暂回迁到 child mount，而 TabBar 仍在 fixed `PinnedSurfaceView` 内，造成 Header 与 TabBar 分层错位。

调整：

- `shouldUseFixedOverlay` 增加 `containerRefreshProxyOverscrollOffsetY < 0` 条件。
- 新增回归测试 `pendingContainerRefreshProxyKeepsHeaderInFixedOverlayBeforeHandoffCommits`，覆盖 proxy 已为负但 active handoff 还没提交的中间态。
- 增加 internal testing 入口 `applyContainerRefreshProxyOverscrollForTesting(_:)`，只用于构造该中间态，避免依赖 UIKit KVO 的重入时序。

Red:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' test -quiet
```

Actual: 新增用例导致核心测试 exit code 65，证明旧逻辑不能在 pending proxy 阶段保持 fixed overlay。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' test -quiet
```

Actual: 核心测试 exit code 0。

## 2026-07-05 Container proxy 停留位置修复

用户继续反馈整体刷新后“停留位置不对”：截图中 `Container refresh` 已显示，但 Header 与 TabBar 停在比预期更低的位置。最新日志显示：

- child 内容区下拉后进入 `childProxy route`，`proxyY` 保持负值。
- host pan 多次处于 `failed/possible`，但 `hostRestoreProxy` 继续把 host offset 恢复到 `baseline + proxy`。
- 业务侧 `UIRefreshControl` 已可能接管 host 的 inset/offset 动画，但核心仍保留内部 proxy，导致业务刷新停留位置叠加了旧的代理 reveal 距离。

Root cause：`.container` 代理路径只有在后续 `contentOffset` 回到 boundary 且 child/host 都 idle 时才尝试 finish。真实手势中 child pan 结束后可能不再产生新的 child offset 回调，旧 `containerRefreshProxyOverscrollOffsetY` 就会停留；如果业务刷新机制随后修改了 host `contentInset`，核心也不应再恢复旧 proxy，否则刷新控件自己的停留动画会被额外下推。

调整：

- 对 loaded child 的 `panGestureRecognizer` 增加 ended/cancelled/failed 监听，只用于代理 `.container` reveal 的 idle finish，不抢 child scroll delegate。
- `finishProxiedContainerRefreshHandoffIfPossible` 支持由 child pan 结束触发；当业务刷新机制未接管 inset 且 child/host 都 idle 时，清空 active handoff、proxy，并把 host 回到 neutral baseline。
- 当业务刷新机制已经修改 `containerRefreshHostScrollView.contentInset` 时，核心只释放内部 proxy，不主动 `setContentOffset` 回 neutral baseline，让停留位置由业务刷新机制自己的 inset/offset 动画决定。
- 新增回归测试 `proxiedContainerRefreshOverscrollFinishesWhenTrackedChildPanEndsIdle` 与 `proxiedContainerRefreshOverscrollReleasesProxyWhenExternalInsetTakesOwnership`。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Actual: `TEST SUCCEEDED`，Swift Testing 报告 101 个测试全部通过。

## 2026-07-05 Header UIViewController lifecycle 补齐

用户要求 `CollapsiblePagerHeaderContent.viewController` 支持完整 `UIViewController` 生命周期，并让示例页面 Header 通过 `UIViewController` 返回来验证。

设计结论：

- Header controller 继续使用标准 UIKit containment，parent 始终是 `CollapsiblePagerViewController`。
- `HeaderHostView` 在当前 child 的 `HeaderMountView` 和 fixed overlay 之间迁移时，只移动 controller 的 `view`，不触发 appear/disappear。
- pager 自身 `viewWillAppear` / `viewDidAppear` / `viewWillDisappear` / `viewDidDisappear` 时，手动转发 Header controller 的 `beginAppearanceTransition` / `endAppearanceTransition`。
- pager 已可见时 `reloadData()` 替换或清空 Header controller，会让旧 Header controller 完成 disappear；新 Header controller 会立即完成 appear。
- 示例 App 的根 pager 与 Refresh Handoff 验证页都改为持有 `DemoHeaderViewController`，data source 通过 `.viewController(...)` 返回 Header。

Red:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' -derivedDataPath /tmp/CollapsiblePagerHeaderLifecycleRedAllDerivedData test -quiet
```

Actual: `TEST FAILED`，新增 `headerViewControllerReceivesPagerAppearanceLifecycle()` 和 `visiblePagerReplacesHeaderViewControllerWithAppearanceLifecycle()` 均失败，Header controller 未收到 appearance 事件。

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerHeaderExampleRedDerivedData build-for-testing -quiet
```

Actual: `TEST BUILD FAILED`，示例测试找不到 `DemoPagerDataSource.headerViewController` 和 `DemoRefreshHandoffModeDataSource.headerViewController`，证明示例尚未改为 Header controller 接入。

Verification:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,id=40789BEC-6977-4FC6-AA42-0ACDF687EF7D' -derivedDataPath /tmp/CollapsiblePagerHeaderLifecycleGreenCore2DerivedData test -quiet
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/CollapsiblePagerHeaderExampleGreenBuildForTesting2DerivedData build-for-testing -quiet
```

Actual: 核心测试 exit code 0；Examples build-for-testing exit code 0。

## 执行策略

推荐使用 Subagent-Driven：

1. 每个 task 一个 fresh subagent。
2. 主线程审查 task diff。
3. 先测试后实现。
4. 每个 task 完成后运行对应测试。

Inline Execution 也可行，但需要每 1 到 2 个 task 做一次人工检查，避免状态机实现偏离本文档。

仓库约定：只有用户明确要求提交、推送或创建 PR 时，才执行 `git add`、`git commit`、`git push` 或 PR 操作。计划中的 task 边界可作为未来提交拆分参考，不代表自动提交。
