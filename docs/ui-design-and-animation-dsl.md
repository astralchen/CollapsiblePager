# CollapsiblePager UI 设计与动画交互 DSL

本文档定义 `CollapsiblePager` V1 的默认 UI、交互状态和验收 DSL。它不描述任何业务页面，只描述通用容器能力。

## 1. 设计目标

- 默认 UI 足够完整，可以直接展示 Header、TabBar、indicator 和多 child 页面。
- Header 和 child 内容全部由调用方提供。
- TabBar 和 indicator 是核心包默认能力，但不拥有页面选择状态。
- 下拉刷新视觉由外部提供，核心只定义 Header 展开优先和 handoff 边界。
- 交互 DSL 能直接转成状态测试、布局测试和示例 App QA 场景。

## 2. 默认视觉

### 2.1 容器层级

```text
CollapsiblePagerViewController
└─ CollapsiblePagerRootView
   ├─ ContainerRefreshHostScrollView
   │  ├─ PageContainerView
   │  │  └─ ChildViewController[index].view
   │  │     └─ pagerScrollView
   │  │        └─ HeaderMountView[index]
   │  │           └─ HeaderHostView (expanded stable)
   │  └─ PinnedSurfaceView
   │     ├─ FixedHeaderContainer
   │     │  └─ HeaderHostView (pinned / paging / refresh / reload)
   │     │     └─ ProvidedHeaderView
   │     └─ TabBarSurface
   │        ├─ TabContentScrollView
   │        │  └─ TabItemLayoutView
   │        │     ├─ TabItem[0...n]
   │        │     └─ IndicatorContainer
   │        │        └─ IndicatorLayer
   │        └─ Separator
   └─ GestureOverlay / PinAnchor bridge
```

`PageContainerView` 的顶部与 TabBar pin 位置对齐，避免 child 内容滚入状态栏或导航栏区域。`HeaderMountView` 保留 child scroll view 内的滚动占位；它的高度包含 Header max height 和 TabBar height，但其中的 `HeaderHostView` 只占 Header max height，底部 TabBar spacer 不承载 Header 内容。Header 展开且稳定在当前 child 时，`HeaderHostView` 由当前 child 的 `HeaderMountView` 承载；吸顶、横向切页、顶部回弹、刷新 reveal/end 和布局刷新冲突期间，`HeaderHostView` 由 `FixedHeaderContainer` 承载。顶部回弹指当前 child 的 `UIScrollView.bounces` 让 `contentOffset.y` 小于 `-managedTopInset` 的阶段，此时 Header 固定在 overlay，TabBar 不跟随 child scroll content 下移；`.container` refresh handoff 是例外，外层 host 拥有 overscroll，Header、TabBar 和 PageContainer 按同一个 reveal 距离整体下移。Header 可通过 `topBehavior = .extendsUnderTopSafeArea` 从容器顶部开始绘制，但 TabBar 和 child 内容仍留在安全区域内。

Child 的 vertical scroll indicator 轨道跟随 Pager 输出的 managed inset：顶部避让 Header/TabBar 占位，底部使用当前安全区/布局 bottom inset。Pager 接管后关闭 UIKit 自动 scroll indicator inset 调整，避免 safe area 或 bar 避让被重复计算。内容滚到底部时，indicator thumb 应停在安全区底部附近，而不是沿用 child 接管前的旧自动调整值。

长列表滚动过程中，child `contentSize` 可能因 UITableView 估算高度逐步修正。只要目标 managed inset 没有变化，Pager 不应重新写入 child `contentInset` 或 indicator inset；滚到底部时内容可以自然 rubber-band，但不应因为重复写入相同 inset 在旧最大 offset 与新滚动位置之间循环跳动。

### 2.2 HeaderHostView

- 接受 `UIView` 或 `UIViewController.view`。
- 默认 `clipsToBounds = true`。
- 输出 `collapseProgress`，范围为 `0...1`。
- 不注入业务按钮、图片、标题或加载状态。
- Header controller containment 和 appearance lifecycle 由 pager 管理。pager 出现/消失、可见状态下替换 Header 时会转发 appearance；视觉迁移不改变 controller parent，也不触发 appear/disappear。

默认高度：

- `maxHeight = 260pt`
- `minHeight = 0pt`

默认顶部行为：

- `insideSafeArea`：Header 顶部从导航栏底部或 safe area top 开始。
- `extendsUnderTopSafeArea`：Header 顶部从容器顶部开始，底部仍贴着 TabBar 顶部。

### 2.3 TabBarSurface

- 默认高度 `48pt`。
- 默认背景 `UIColor.systemBackground`。
- 默认底部分隔线可见。
- V1 使用等宽文本 Tab。
- 空页时不创建 item、不显示 indicator、不响应点击。

### 2.4 TabItem

TabItem 必须自己表达 selected 状态，不能只靠 indicator。

| 状态 | 字体 | 颜色 | Accessibility |
| --- | --- | --- | --- |
| normal | preferred subheadline regular | secondaryLabel | button |
| selected | preferred subheadline semibold | label | button + selected |
| partial | normal 和 selected 插值 | secondaryLabel 和 label 插值 | button |
| disabled | preferred subheadline regular | tertiaryLabel | button + notEnabled |

### 2.5 IndicatorLayer

默认 indicator：

- 样式：短下划线。
- 颜色：`systemYellow`。
- 高度：`3pt`。
- 圆角：`1.5pt`。
- 默认宽度：`fixed(28pt)`。
- 底部 inset：`0pt`。

Indicator 不读取 selectedIndex 直接布局。它只消费 `IndicatorFocusRect`：

```text
IndicatorFocusRect = itemFrames + titleFrames + PagePosition + widthMode
```

当 `PagePosition == nil` 或 page count 为 `0` 时，indicator frame 为 `nil`。

## 3. 布局 DSL

```text
component CollapsiblePager {
  platform UIKit
  minimumOS iOS(13)

  slot header accepts UIView | UIViewController
  slot pages accepts UIViewController[]
  slot tabBar owns defaultTextTabs

  token header.maxHeight.default = 260pt
  token header.minHeight.default = 0pt
  token tabBar.height.default = 48pt
  token indicator.height.default = 3pt
  token indicator.width.default = fixed(28pt)
  token pinY = max(navigationBar.maxY.inPagerCoordinates, safeArea.top)

  layout default {
    pageContainer.frame = rect(
      x: pager.bounds.minX,
      y: pinY,
      width: pager.bounds.width,
      height: pager.bounds.height - pinY
    )
    childScrollView.topInset = header.maxHeight + tabBar.height
    childScrollView.bottomInset >= viewport.height + pinThreshold - childScrollView.topInset - contentSize.height
    headerMount.y = -childScrollView.topInset
    tabBar.placement = belowHeader
    tabBar.pinning = belowNavigationBar(offset: 0pt)
  }

  emptyState {
    selectedIndex.public = 0
    effectiveSelectedIndex = nil
    pagePosition = nil
    tabItems.count = 0
    indicator.frame = nil
    pageRequests = ignored
  }
}
```

## 4. 状态 DSL

### 4.1 纵向状态

```text
state expanded {
  condition header.visibleHeight == header.maxHeight
  owner headerPlaceholder = currentChild.headerMount
  owner headerHost = fixedOverlay
}

state collapsing {
  condition verticalDelta > 0 && header.visibleHeight > header.minHeight
  update pinAnchorY += verticalDelta
  clamp pinAnchorY to 0...pinThreshold
}

state pinned {
  condition header.visibleHeight == header.minHeight
  owner headerHost = fixedOverlay
  tabBar.y = pinY
}

state expanding {
  condition verticalDelta < 0 && currentChild.isAtTop && header.visibleHeight < header.maxHeight
  update pinAnchorY += verticalDelta
  clamp pinAnchorY to 0...pinThreshold
}

state topBouncing {
  condition currentChild.contentOffsetY < -managedTopInset
  update pinAnchorY = 0
  doNotSyncNonCurrentChildOffsets
}
```

### 4.2 横向状态

```text
state pagingInteractive {
  trigger pageContainer.pan.horizontal
  owner pageTransition = PageContainer
  owner headerHost = fixedOverlay(reason: horizontalPaging)
  emit PagePosition(raw, fromIndex, toIndex, progress, interactive: true)
}

state pagingProgrammatic {
  trigger tabTap | selectPage
  owner pageTransition = PageRequestPipeline
  owner headerHost = fixedOverlay(reason: horizontalPaging)
  emit PagePosition(raw, fromIndex, toIndex, progress, interactive: false)
  if abs(toIndex - fromIndex) == 1 and requestAnimated == true then transitionMode = animatedScroll
  if trigger == tabTap and abs(toIndex - fromIndex) == 1 then controllerTransitionAnimated = true
  if trigger == tabTap and abs(toIndex - fromIndex) > 1 then controllerTransitionAnimated = false
  if abs(toIndex - fromIndex) > 1 then transitionMode = directSourceTarget
}

state pagingCompleted {
  commit selectedIndex = targetIndex
  clear pendingSelectedIndex
  restore headerHost by pinAnchor
}

state pagingCancelled {
  keep selectedIndex = sourceIndex
  clear pendingSelectedIndex
  emit PagePosition(sourceIndex)
  restore headerHost by pinAnchor
}

state pagingCompletionIgnored {
  trigger pageContainer.completion
  guard completion.targetIndex != pendingSelectedIndex
  guard completion.targetIndex != sourceIndex
  keep selectedIndex = sourceIndex
  keep pendingSelectedIndex = latestTargetIndex
  keep headerHost = fixedOverlay(reason: horizontalPaging)
}
```

### 4.3 刷新 handoff 状态

```text
state refreshEligible {
  condition header.visibleHeight == header.maxHeight
  condition currentChild.isAtTop == true
  condition refreshHandoffMode != none
  condition activeRefreshHandoff == nil
}

state refreshHandoff {
  if refreshHandoffMode == container {
    activeRefreshHandoff = containerHost(index: currentIndex)
  }

  if refreshHandoffMode == child {
    activeRefreshHandoff = childScrollView(index: currentIndex)
  }

  owner refreshVisual = external
  owner refreshTask = external
  owner refreshEnd = external
}
```

Pager 不创建刷新 view，不调用刷新回调，不结束刷新。Header 未完全展开时，下拉手势只能展开 Header。

默认 `refreshHandoffMode = .container`，因此 Header 完全展开后继续下拉会进入整体刷新 handoff。`.container` 模式下，`containerRefreshHostScrollView` 是包住 `PageContainerView` 与 `PinnedSurfaceView` 的外层纵向 scroll host。它的刷新 reveal 基线对齐 `pinY`，即导航栏底部或无导航栏时的 safe area top；静止状态为 `contentInset.top == pinY` 且 `contentOffset.y == -pinY`。host 内部内容层反向平移 `-pinY`，所以 Header、TabBar 和 PageContainer 的屏幕位置仍按 layout engine 输出显示。PageContainer 仍按 layout engine 输出放在 TabBar pin viewport 内，child 自己继续使用 managed top inset 表达 Header/TabBar 占位；继续下拉时 host 从 `-pinY` 向更小 offset 移动，Header、TabBar 和 page content 因同属于 host 内容层而整体下移，不在 TabBar 与 page content 之间产生空洞。host 只允许 refresh reveal 方向的 overscroll，不应存在从 `-pinY` 到 `0` 的普通纵向滚动区间；active `.containerHost` 期间 offset 被 UIKit 推到 baseline 以上时必须夹回 baseline。刷新控件是否存在、显示在哪里以及何时结束仍由业务安装的刷新机制决定。

`headerPullDownRefreshBehavior = .suppressesChildRefresh` 时，Header host 会安装一个只在 Header 区域向下拖拽时 begin 的内部 gate gesture。当前 child 的 pan gesture 等待该 gate 失败；gate begin 后 child 不进入 top bounce，因此不会从 Header 区域拉出 child 自有刷新控件。gate 的下拉意图由 translation 和 velocity 共同判断；translation 还未累积但 velocity 已明确向下时，仍视为下拉。该策略不改变 child 内容区域下拉，也不改变业务刷新任务生命周期。默认 `.allowsChildRefresh` 保持 Header 区域随 child scroll view 下拉的 UIKit 行为。

当下拉从当前 child 内容区域开始时，child pan gesture 必须等待 container host pan 失败。host pan 的 begin 条件仍由 `refreshEligible`、下拉方向和 `.container` mode 共同决定；下拉方向由 translation 优先判断，translation 尚未累积时回退到 velocity，避免 UIKit 在 shouldBegin 早期返回 `translation == .zero` 时误判失败。不满足条件时 child pan 继续正常滚动。若 container host pan 在 child 已位于顶部时因明确向上滚动而拒绝接管，后续同一 child pan 反向进入顶部 overscroll 时只把 child clamp 回 managed top boundary，不再启动 container proxy handoff；新的下拉手势会重新竞争 owner。满足条件时由 host 直接接管下拉，避免 child top bounce 与 host proxy offset 在同一帧内来回修正。

如果 child 内容区域已经进入顶部兜底 overscroll，且本次 child 手势没有先在顶部被 container host pan 以明确向上意图拒绝接管，pager 会把 child 立即拉回 managed top boundary，并把 overscroll 代理给 `containerRefreshHostScrollView`。在该手势结束前，代理 overscroll 是唯一 reveal 源值；代理值为负的中间帧也必须把 Header host 保持在 fixed overlay，不能让 Header 回到 child mount 而 TabBar 仍留在 fixed layer。即使 idle host 被 UIKit 暂时校正回 neutral baseline，Header、TabBar 和 page content 也必须恢复到同一个整体下移距离，不得出现拉下后回跳。child pan 进入 ended、cancelled 或 failed 后，如果业务刷新机制没有接管 host content inset，代理 reveal 要在 child 与 host 都 idle 时回到 neutral baseline，不能因为没有新的 `contentOffset` 回调而停在旧 proxy 位置。

当下拉已由 `containerRefreshHostScrollView` 直接接管时，`scrollViewDidScroll` 中 offset 碰到 neutral baseline 也不等价于 handoff 结束。baseline 可能只是同一次手势中的 UIKit rubber-band 校正点；视觉 owner 必须保持为 container host，直到拖拽、减速或滚动动画结束后再根据 neutral inset 与 proxy 状态执行 idle finish。

当 active handoff 已经是当前 page 的 `.containerHost`，且 host/proxy 仍处于 overscroll，container host pan 的 shouldBegin 需要延续 container owner。`gestureRecognizerShouldBegin(_:)` 的早期 translation 和 velocity 可能都为零，这种初始采样不足不能让 host pan fail，否则 child 会重新进入代理路径并造成整体 reveal 回跳。代理 overscroll 只用于 child 仍在下拉或 host idle/recovery 时恢复 reveal；host pan 真正 begin 后必须接管 owner 并清空 proxy，后续 reveal 距离由 host `contentOffset` 自己表达，不再被旧 proxy restore 回固定位置。owner 只有在 idle finish 清空 active handoff 和 overscroll 后才重新竞争。

当 Header 重新进入未完全展开状态时，若 container host 仍处于 neutral refresh inset，代理 overscroll 必须立即结束：active handoff 变为 `nil`，host 回到 neutral baseline，Header 重新按当前 child / fixed overlay 的常规规则迁移。child 在 Header 完全展开时被 clamp 到 managed top boundary 是代理路径的一部分，不结束 handoff；proxy overscroll 继续跟随当前 child overscroll 更新。业务刷新机制已经接管 content inset 时，核心不抢回 offset，但必须清空内部 proxy，让停留位置只由业务刷新机制自己的 inset/offset 动画决定。

> 当前实现状态（2026-07-05）：刷新 handoff 的资格和互斥规则已在纯值 coordinator 中实现并测试；`.container` 路由到容器拥有的 `containerRefreshHostScrollView`，`.child` 路由到当前 child 的 `pagerScrollView`。Header 展开前不会 handoff，active handoff 期间横向分页会被 `GestureArbiter` 禁止。`.container` 代理 reveal 会在 Header 重新进入未完全展开时取消；fully expanded 状态下 child 回到 managed top boundary 仍属于代理路径，proxy overscroll 为负时 Header host 会保持在 fixed overlay，避免 handoff 提交前 Header 与 TabBar 分层错位。container host 直接接管后也不会在 didScroll 碰到 baseline 时提前 reset，避免 cancel / route / reset 循环造成内容区回跳。container host pan 和 Header gate 的下拉意图已覆盖 translation 为零但 velocity 向下的 shouldBegin 早期状态；已有 `.containerHost` overscroll 未结束时，也会在 translation/velocity 均为零的初始 shouldBegin 采样中保持 container owner；host pan 真正 begin 时会从 proxy reveal 接管 owner 并清空代理值，避免旧 proxy 持续恢复 host offset；child pan 结束也会触发代理路径的 idle finish，防止旧 proxy 在没有后续 offset 回调时停留；业务刷新机制修改 host inset 后，核心释放内部 proxy 但不抢回 offset；host 的 content size 让 neutral baseline 成为普通滚动上界，并在 active handoff 中夹取 baseline 以上的 offset，避免 TabBar 或 child frame 被外层 host 向上推错位。刷新视觉、任务和结束时机仍由外部拥有。

## 5. 动画 DSL

### 5.1 Header 折叠

```text
motion headerCollapse {
  trigger currentChild.verticalScroll(deltaY > 0)
  driver gesture
  duration interactive

  guard pageCount > 0
  guard horizontalPaging == false

  update pinAnchorY = clamp(pinAnchorY + deltaY, 0, pinThreshold)
  update header.visibleHeight = header.maxHeight - pinAnchorY
  update collapseProgress = pinAnchorY / pinThreshold

  route remainingDelta to childScrollView
}
```

### 5.2 Header 展开

```text
motion headerExpand {
  trigger currentChild.verticalScroll(deltaY < 0)
  driver gesture
  duration interactive

  guard currentChild.isAtTop == true
  guard header.visibleHeight < header.maxHeight

  update pinAnchorY = clamp(pinAnchorY + deltaY, 0, pinThreshold)
  block refresh until header.visibleHeight == header.maxHeight
}
```

### 5.3 Page request

```text
interaction pageRequest {
  trigger tabTap(index) | apiSelect(index) | horizontalGesture(targetIndex)

  validate pageCount > 0
  validate index in 0...(pageCount - 1)

  set pendingSelectedIndex = index
  move headerHost to fixedOverlay(reason: horizontalPaging)
  drive pageContainer to index

  onProgress emit PagePosition
  onComplete commit selectedIndex = index
  onComplete prune childWindow to currentIndex ± 1
  onCancel restore selectedIndex = sourceIndex
}
```

### 5.4 Indicator 交互跟随

```text
motion indicatorFollowPagePosition {
  trigger PagePosition.changed
  driver pageContainer
  duration interactive | configuredProgrammaticDuration

  compute focusRect = focusRect(
    itemFrames: tabBar.itemFrames,
    titleFrames: tabBar.titleFrames,
    position: pagePosition
  )

  compute indicatorFrame = indicatorFrame(
    focusRect: focusRect,
    widthMode: indicator.widthMode
  )

  update indicator.frame = indicatorFrame
  update tabItems.selectionProgress = pagePosition
}

motion childAppearanceFollowsPageTransition {
  trigger pageRequest.accepted
  driver pageContainer

  begin sourceChild.appearance = disappearing
  begin targetChild.appearance = appearing

  on pageTransition.completed {
    end sourceChild.appearance
    end targetChild.appearance
  }
}
```

### 5.5 Layout reload

```text
interaction reloadHeaderLayout {
  trigger api.reloadHeaderLayout(offsetPolicy)

  measure headerHeights
  compute layoutOutput
  compute offsetCorrection as contentOffset.y delta
  derive nextPinAnchor from offsetPolicy

  if pager.isDragging || pager.isDecelerating || pager.isPaging || pager.isRefreshAnimating {
    mark layoutDirty = true
    wait until idle
  }

  apply withoutAnimation guardedScrollUpdate
  sync loadedChildOffsets and preservedOffsetSnapshots
  preserve contentOffset.y + managedTopInset == PinAnchor
  preserve header/tab/pageContent visual relationship by default
  notify delegate.didUpdateLayout
}
```

## 6. 手势优先级

| 场景 | 策略 |
| --- | --- |
| 系统返回手势 vs 横向分页 | 系统返回优先 |
| Header 区域横向拖拽 | 默认不启动分页 |
| PageContainer 横向拖拽 vs child 纵向滚动 | 按初始位移和速度判定方向 |
| 横向意图成立 | 冻结纵向 coordinator |
| 纵向意图成立 | PageContainer 不抢手势 |
| Header 未完全展开时下拉 | 只展开 Header |
| Header 完全展开后继续下拉 | 按 refreshHandoffMode handoff |
| 刷新 reveal/end 动画中 | V1 禁止横向切页或延迟 page request |

> 当前实现状态（2026-07-04）：PageContainer 横向 pan 已在内部 paging `UIScrollView` 子类的 `gestureRecognizerShouldBegin(_:)` 中接入 `GestureArbiter`；已覆盖 Header 区域禁止分页、内容区允许分页、第一页 leading-edge 系统返回优先、layout reload active 禁止分页，以及真实刷新 handoff active 时禁止横向分页。

## 7. 验收 DSL

```text
assert zeroPages {
  selectedIndex == 0
  effectiveSelectedIndex == nil
  tabItems.count == 0
  indicator.frame == nil
  selectPage(0) doesNotNotifyDelegate
}

assert headerCollapseBeforeChildScroll {
  when child.scrollsUp and header.visibleHeight > header.minHeight
  then pinAnchorY increases
  and child.contentOffsetY is guarded
}

assert headerExpandBeforeRefresh {
  when child.scrollsDown and header.visibleHeight < header.maxHeight
  then refreshHandoff == nil
  and header.visibleHeight increases
}

assert refreshIsExternal {
  when refreshHandoffMode == child and refreshEligible
  then activeRefreshHandoff == childScrollView(index: currentIndex)
  and pagerDoesNotCallRefreshDelegate
  and pagerDoesNotEndRefreshing
}

assert pageRequestCommitsOnCompletion {
  when selectPage(target, animated: true)
  then pendingSelectedIndex == target
  and selectedIndex remains source until completion
  and onComplete selectedIndex == target
}

assert adjacentTabTapAnimatesScrollAndControllerTransition {
  when tabTap(target)
  and abs(target - source) == 1
  then selectedIndex remains source until pageContainerCompletion
  and onComplete selectedIndex == target
  and controllerTransitionAnimated == true
  and childAppearanceAnimated == true
}

assert nonAdjacentTabTapSkipsScrollAnimationAndCommitsImmediately {
  when tabTap(target)
  and abs(target - source) > 1
  then controllerTransitionAnimated == false
  and selectedIndex == target
  and childAppearanceAnimated == false
}

assert tabTapToEmptyPageKeepsPinnedHeader {
  given selectedPage == Long
  and collapseProgress == 1
  when tabTap(Empty)
  then selectedIndex == Empty
  and collapseProgress == 1
  and tabBar.frame.minY == pinY
  and emptyScrollView.contentOffset.y == pinAnchorY - managedTopInset
}

assert tabTapBackToLongPreservesDeepChildOffset {
  given selectedPage == Long
  and longScrollView.contentOffset.y > pinAnchorY - managedTopInset
  when tabTap(Short)
  and tabTap(Long)
  then selectedIndex == Long
  and collapseProgress == 1
  and longScrollView.contentOffset.y == previousLongContentOffsetY
}

assert tabTapBackFromEmptyRestoresUnloadedLongOffset {
  given selectedPage == Long
  and longScrollView.contentOffset.y > pinAnchorY - managedTopInset
  when tabTap(Empty)
  and childWindow.unloads(Long)
  and tabTap(Long)
  and longScrollView.contentSize becomesScrollable
  then selectedIndex == Long
  and collapseProgress == 1
  and longScrollView.contentOffset.y == previousLongContentOffsetY
}

assert nonAdjacentProgrammaticPageRequestSkipsIntermediatePages {
  when selectPage(target, animated: true)
  and abs(target - source) > 1
  then selectedIndex == target
  and loadedChildIndexes == target.neighborhood(radius: 1)
  and pagePosition doesNotSweepIntermediateIndexes
}

assert childScrollIndicatorsHiddenDuringHorizontalPaging {
  given childScrollView.showsVerticalScrollIndicator == true
  when PagePosition.isInteractive == true
  then childScrollView.showsVerticalScrollIndicator == false
  and childScrollView.showsHorizontalScrollIndicator == false
  when PagePosition.progress == 0
  then childScrollView.showsVerticalScrollIndicator == originalValue
}

assert pageRequestRollsBackOnCancel {
  when horizontalPanCancelled
  then selectedIndex == source
  and indicator.frame == frameFor(source)
}

assert supersededPageCompletionDoesNotCommitIntermediatePage {
  given selectedPage == Short
  when tabTap(Long)
  and tabTap(Empty)
  and pageContainerCompletion(Long)
  then selectedIndex == Short
  and pendingSelectedIndex == Empty
  when pageContainerCompletion(Empty)
  then selectedIndex == Empty
}

assert indicatorUsesFocusRect {
  when pagePosition.progress == 0.5
  then indicator.frame == interpolate(fromItemFrame, toItemFrame, 0.5).mappedByWidthMode
}

assert headerHostMigrationKeepsContainment {
  when header is UIViewController
  and headerHost moves between mount and fixedOverlay
  then headerViewController.parent == pager
}
```

## 8. 示例 App QA 场景

示例 App 只用于展示接入方式，不把业务 UI 写入核心包。

- App 根层级：验证 `UITabBarController -> UINavigationController -> CollapsiblePagerViewController` 下的小标题导航栏、安全区和底部 TabBar 集成。
- 导航栏按钮：push 第二个 pager 后，通过系统边缘返回手势回到根 pager。
- 长内容 child：验证折叠、吸顶和滚动位置保存。
- 短内容 child：验证 bounce 和刷新 handoff。
- 空内容 child：验证 managed inset 和外部刷新 reveal。
- Header 自动高度：验证 `reloadHeaderLayout` 视觉位置保持。
- `Refresh` 根 Tab：通过导航栏 mode menu 切换 `.none`、`.container`、`.child` 三个独立 pager，menu title 显示当前 mode，验证 handoff mode 是 pager 级配置。
- `.none` 刷新：业务可保留自己的刷新机制，核心不开始 refresh handoff。
- `.container` 刷新：业务可在 `containerRefreshHostScrollView` 上安装整体刷新机制。
- `.child` 刷新：业务可在每个 child 的 `pagerScrollView` 上安装局部刷新机制；示例 App 使用系统 `UIRefreshControl` 只是演示选择，不是核心契约。
- 快速点击 Tab：最终停在最后目标。
- 点击 Tab：相邻切换的 child controller appearance transition 使用 `animated:true`，非相邻切换使用 `animated:false`。
- 非相邻 Tab/API 跳转：不显示中间页空白，不加载中间 child。
- 横向滑动取消：Tab 和 indicator 回源。
- 顶部回弹中切页：Header 不与列表顶部脱钩。
- 刷新结束动画中：Header 不闪跳。

## 9. 后续扩展占位

以下能力不进入 V1，但当前 DSL 已预留输入模型：

- 可横向滚动 TabBar：复用 focus rect 中心点计算 horizontal content offset。
- 自定义 indicator：复用 PagePosition 和 focus rect。
- Header 下拉拉伸：在 topBouncing 阶段增加外部视觉 progress。
- Header 布局动画：在 layout reload 上增加公开 animated behavior。
- 自定义刷新资格 provider：扩展 RefreshHandoff，不改变核心不拥有刷新任务的原则。
