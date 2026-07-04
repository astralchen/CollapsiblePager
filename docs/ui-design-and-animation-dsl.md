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
   ├─ PageContainerView
   │  └─ ChildViewController[index].view
   │     └─ pagerScrollView
   │        └─ HeaderMountView[index]
   ├─ PinnedSurfaceView
   │  ├─ FixedHeaderContainer
   │  │  └─ HeaderHostView
   │  │     └─ ProvidedHeaderView
   │  └─ TabBarSurface
   │     ├─ TabContentScrollView
   │     │  └─ TabItemLayoutView
   │     │     ├─ TabItem[0...n]
   │     │     └─ IndicatorContainer
   │     │        └─ IndicatorLayer
   │     └─ Separator
   └─ GestureOverlay / PinAnchor bridge
```

`PageContainerView` 的顶部与 TabBar pin 位置对齐，避免 child 内容滚入状态栏或导航栏区域。`HeaderMountView` 保留 child scroll view 内的滚动占位；吸顶、横向切页、顶部回弹、刷新 reveal/end 和布局刷新冲突期间，`HeaderHostView` 由 `FixedHeaderContainer` 承载。Header 可通过 `topBehavior = .extendsUnderTopSafeArea` 从容器顶部开始绘制，但 TabBar 和 child 内容仍留在安全区域内。

### 2.2 HeaderHostView

- 接受 `UIView` 或 `UIViewController.view`。
- 默认 `clipsToBounds = true`。
- 输出 `collapseProgress`，范围为 `0...1`。
- 不注入业务按钮、图片、标题或加载状态。
- Header controller containment 由 pager 管理，视觉迁移不改变 controller parent。

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

  layout default {
    pageContainer.frame = rect(
      x: pager.bounds.minX,
      y: safeArea.top,
      width: pager.bounds.width,
      height: pager.bounds.height - safeArea.top
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
```

### 4.3 刷新 handoff 状态

```text
state refreshEligible {
  condition header.visibleHeight == header.maxHeight
  condition currentChild.isAtTop == true
  condition refreshMode != none
  condition activeRefreshHandoff == nil
}

state refreshHandoff {
  if refreshMode == overall {
    activeRefreshHandoff = externalScrollView(scope: overall, index: currentIndex)
  }

  if refreshMode == child {
    activeRefreshHandoff = externalScrollView(scope: child, index: currentIndex)
  }

  owner refreshVisual = external
  owner refreshTask = external
  owner refreshEnd = external
}
```

Pager 不创建刷新 view，不调用刷新回调，不结束刷新。Header 未完全展开时，下拉手势只能展开 Header。

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
  compute offsetCorrection

  if pager.isDragging || pager.isDecelerating || pager.isPaging || pager.isRefreshAnimating {
    mark layoutDirty = true
    wait until idle
  }

  apply withoutAnimation
  preserve visualPosition by default
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
| Header 完全展开后继续下拉 | 按 refreshMode handoff |
| 刷新 reveal/end 动画中 | V1 禁止横向切页或延迟 page request |

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
  when refreshMode == child and refreshEligible
  then activeRefreshHandoff == externalScrollView(scope: child, index: currentIndex)
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

- 长内容 child：验证折叠、吸顶和滚动位置保存。
- 短内容 child：验证 bounce 和刷新 handoff。
- 空内容 child：验证 managed inset 和外部刷新 reveal。
- Header 自动高度：验证 `reloadHeaderLayout` 视觉位置保持。
- `.overall` 刷新：多个 child 安装同一个外部刷新 action。
- `.child` 刷新：每个 child 自己安装局部刷新控件。
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
