# CollapsiblePager 需求与技术架构

## 1. 定位

`CollapsiblePager` 是一个通用 UIKit 容器，用来构建“可折叠 Header + TabBar + 多 child 页面”的界面。核心包只负责容器布局、UIKit containment、Tab 渲染、横向分页、纵向嵌套滚动、手势仲裁和刷新交互移交。

业务方负责 Header 内容、child 内容、数据请求、刷新控件、刷新任务和结束时机。核心包不能写入个人主页、详情页、创作者页、作品列表等业务模型或固定 UI。

当前设计面向未发布的 V1，可以删除旧代码并重写，不需要兼容临时 API。

## 2. 参考源码结论

本项目参考两个开源库，但不引入运行时依赖，也不直接复制第三方 public API。

- [SPStore/NestedPageViewController](https://github.com/SPStore/NestedPageViewController)，阅读版本 `94cc01a`。
- [uias/Tabman](https://github.com/uias/Tabman)，阅读版本 `b666020`。

### 2.1 NestedPageViewController 的优势

NestedPageViewController 的优势是纵向嵌套滚动与 Header 宿主迁移。

- Child 必须显式提供主滚动视图。核心不猜测第一个 scroll view。
- 内部使用不可见 `pin` 作为纵向状态锚点。Header 可见高度、吸顶状态和非当前 child offset 同步不只依赖当前 child 的 `contentOffset.y`。
- 每个 child scroll view 有自己的 Header mount。真实 Header 视觉内容只有一份，在 child mount 和 fixed overlay 之间迁移。
- 横向切页期间冻结纵向 KVO/observer 回调，Header 迁移到 fixed overlay，切页结束后按目标 child 和 pin 状态恢复。
- 顶部回弹、完全吸顶、刷新 reveal/end 动画是 pin anchor 最有价值的场景。pin 不动时，非当前 child 不应收到错误 offset delta。
- 刷新不是核心拥有的业务事件。示例中的整体刷新和局部刷新都由外部 child scroll view 安装刷新控件，核心只保证 Header 展开优先、刷新手势不与 Header/切页冲突。

这些结论落到本项目后，形成 `VerticalScrollCoordinator`、`HeaderHostCoordinator`、`PinAnchor`、`RefreshHandoff` 和 `GestureArbiter`。

### 2.2 Tabman 的优势

Tabman 的优势是横向分页状态链路和 TabBar 渲染分层。

- Bar 只负责展示 item、接收点击、发出 scroll request。
- Page controller 才拥有页面切换过程，输出连续 page position。
- Tab item selected progress、indicator frame、可滚动 bar 的 focus rect 都消费同一个 position。
- 点击 Tab、API 跳转和横向滑动都进入同一条页面请求链路。selected index 在完成或取消后统一提交。
- Indicator focus rect 由 item/title frame 和连续 position 推导，不应散落成 `selectedIndex`、`fromIndex`、`progress` 多套入口。

这些结论落到本项目后，形成 `PageContainer`、`PageRequestPipeline`、`PagePosition`、`TabBarController` 和 `IndicatorFocusRect`。

### 2.3 组合原则

两个参考库侧重点不同，组合时必须保持所有权清晰：

- Nested 只作为纵向嵌套滚动、Header 迁移、刷新移交和手势冲突的架构参考。
- Tabman 只作为横向切页、Tab selected progress、indicator focus rect 和状态提交链路的架构参考。
- TabBar 不修改 child 或纵向状态。
- Refresh 不修改业务数据，也不要求指定刷新控件。
- Child 不反向拥有 Header、TabBar 或 selected index。

## 3. V1 目标

- 提供公开 `CollapsiblePagerViewController`。
- 支持 Header 内容为 `UIView` 或 `UIViewController`。
- 支持多个 child view controller，并使用标准 UIKit containment。
- 要求参与协调的 child 显式提供主 `UIScrollView`。
- 支持 Header 折叠、展开、吸顶和布局刷新。
- 支持默认等宽文本 TabBar 和默认下划线 indicator。
- 支持点击 Tab、API 选择和横向滑动切页。
- 支持连续 `PagePosition` 驱动 Tab selected progress 和 indicator focus rect。
- 支持 `.none`、`.overall`、`.child` 三种刷新交互语义。
- 支持没有 child 的空态兜底。
- 符合 Swift 6 strict concurrency 和 iOS 13 要求。

## 4. V1 非目标

- 不实现业务数据请求、缓存、媒体加载或业务模型。
- 不实现内置刷新控件，不要求 `UIRefreshControl`。
- 不提供专门的刷新 child 协议。
- 不提供刷新触发 delegate。
- 不默认刷新所有 child。
- 不实现可横向滚动 TabBar 的完整公开能力。
- 不公开自定义 indicator 协议。
- 不公开自定义 Header 高度 provider。
- 不公开自定义 TabBar layout provider。
- 不实现 Header 下拉拉伸。
- 不使用 `UIPageViewController`，不依赖第三方 pager 库。
- 不保留旧骨架 API 的兼容层。

## 5. 并发与 UIKit 边界

- 公开 UIKit 容器、data source、delegate、UIKit 回调、手势协调、滚动协调和状态提交都在 `@MainActor`。
- `UIView`、`UIViewController`、`UIScrollView`、`UIGestureRecognizer` 和刷新控件不得跨 actor 传递。
- 纯值模型可以不标注 `@MainActor`，并按语义满足 `Sendable`。例如 layout input/output、PagePosition、IndicatorFocusRect、PinAnchor snapshot。
- 存储并跨异步边界调用的闭包必须明确 `@MainActor` 或 `@Sendable`。
- 不用 `Task.detached` 绕开 actor 隔离。
- 不用 `@unchecked Sendable`、`nonisolated(unsafe)` 或 `@preconcurrency` 压制设计问题。

原则是“UIKit 在主 actor，纯计算用值类型”，不是把所有实现都机械标成 `@MainActor`。

## 6. 公开 API 边界

### 6.1 容器

```swift
@MainActor
public final class CollapsiblePagerViewController: UIViewController {
    public weak var dataSource: CollapsiblePagerViewControllerDataSource?
    public weak var delegate: CollapsiblePagerViewControllerDelegate?

    public var configuration: CollapsiblePagerConfiguration

    /// 对外默认选择索引。即使没有页面，也保持默认值 `0`。
    public private(set) var selectedIndex: Int { get }

    /// 当前是否存在有效页面选择。没有页面时为 `nil`。
    public var effectiveSelectedIndex: Int? { get }

    public init(configuration: CollapsiblePagerConfiguration = .default)

    public func reloadData()
    public func selectPage(at index: Int, animated: Bool)
    public func reloadHeaderLayout(offsetPolicy: CollapsiblePagerHeaderOffsetPolicy = .preserveVisualPosition)
}
```

`selectedIndex` 是 UIKit 容器常见默认值语义，默认等于 `0`。当 data source 为空或 page count 为 `0` 时，`effectiveSelectedIndex == nil`，TabBar/indicator/PageContainer 都进入空态，任何选择请求都是 no-op。

### 6.2 Data Source

```swift
@MainActor
public enum CollapsiblePagerHeaderContent {
    case view(UIView)
    case viewController(UIViewController)
}

@MainActor
public protocol CollapsiblePagerViewControllerDataSource: AnyObject {
    func numberOfPages(in pagerViewController: CollapsiblePagerViewController) -> Int
    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, titleForPageAt index: Int) -> String
    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, viewControllerForPageAt index: Int) -> UIViewController
    func headerContent(in pagerViewController: CollapsiblePagerViewController) -> CollapsiblePagerHeaderContent
}
```

Data source 只提供内容，不参与滚动状态提交。V1 只公开标题文本；更复杂的 item model 留给后续扩展。

### 6.3 Delegate

```swift
@MainActor
public protocol CollapsiblePagerViewControllerDelegate: AnyObject {
    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, didSelectPageAt index: Int)
    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, didUpdateCollapseProgress progress: CGFloat)
    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, didUpdateLayout context: CollapsiblePagerLayoutContext)
}
```

Delegate 只描述容器状态变化，不承载刷新生命周期。`.overall` 和 `.child` 都不通过 delegate 转发刷新触发事件。

### 6.4 Child Scroll Provider

```swift
@MainActor
public protocol CollapsiblePagerScrollProviding: AnyObject {
    var pagerScrollView: UIScrollView { get }
}
```

V1 要求 child 明确遵守该协议。自动查找 scroll view 属于后续能力。

## 7. 配置模型

```swift
public struct CollapsiblePagerConfiguration {
    public var header: CollapsiblePagerHeaderConfiguration
    public var tabBar: CollapsiblePagerTabBarConfiguration
    public var paging: CollapsiblePagerPagingConfiguration
    public var refreshMode: CollapsiblePagerRefreshMode
}
```

V1 默认值：

- Header：`fixed(max: 260, min: 0)`。
- TabBar：`height = 48`，`placement = .belowHeader`。
- Pinning：`pinBelowNavigationBar(offset: 0)`，没有导航栏时回退到 safe area top。
- Indicator：短下划线，`height = 3`，`cornerRadius = 1.5`，`width = fixed(28)`。
- Paging：允许横向滑动，横向不回弹，Tab 点击动画 `0.28s`。
- Refresh：`.none`。

刷新配置：

```swift
public enum CollapsiblePagerRefreshMode: Sendable {
    case none
    case overall
    case child
}
```

`.overall` 和 `.child` 只决定 Header 完全展开后的继续下拉移交方向，不决定刷新控件类型、刷新任务和结束时机。

## 8. 内部模块

### 8.1 CollapsiblePagerViewController

公开 façade。职责是连接 data source、delegate、root view、layout engine 和各 coordinator。它不直接实现复杂滚动状态机。

### 8.2 CollapsiblePagerRootView

根视图，承载：

- `PageContainerView`
- `FixedHeaderContainer`
- `TabBarHostView`
- 调试不可见的 pin anchor view 或 value bridge

Root view 不含业务 UI。

### 8.3 LayoutEngine

纯值计算模块。输入：

- container bounds
- safe area
- navigation bar maxY
- Header heights
- TabBar height
- pin anchor
- placement/pinning 配置

输出：

- Header frame
- Header visible height
- collapse progress
- TabBar frame
- pin threshold
- PageContainer frame
- child content inset
- layout reload offset correction

PageContainer 的 frame 铺满 pager bounds。Header 与 TabBar 的占位通过 child scroll view 的 managed top inset 表达，避免容器 frame 下移和 inset 双重计算。

### 8.4 HeaderHostCoordinator

负责 Header 的生命周期和视觉宿主迁移。

- Header 支持 `UIView` 和 `UIViewController`。
- Header controller 使用标准 UIKit containment，挂到 pager 下。
- Header 视觉迁移只移动 controller 的 `view`。
- 每个 child 有自己的 `HeaderMountView`，位于 managed top inset 对应区域。
- fixed overlay 用于吸顶、横向切页、顶部回弹、刷新 reveal/end、layout reload。

### 8.5 ChildStore

负责 child view controller 的缓存、加载、释放和主 scroll view 获取。

- 通过 data source 创建 child。
- 使用标准 containment。
- 校验 child 是否遵守 `CollapsiblePagerScrollProviding`。
- 设置 content inset、scroll indicator inset、contentInsetAdjustmentBehavior。
- 为每个 loaded child 创建 HeaderMountView。

### 8.6 VerticalScrollCoordinator

纵向滚动状态机。职责：

- 只处理当前 child 的 `pagerScrollView` 回调。
- 横向切页期间忽略纵向回调。
- 使用 guarded update 主动修正 offset，避免递归。
- 通过 pin anchor 计算 Header visible height 和 collapse progress。
- 非当前 child 的 offset 同步只使用 pin anchor delta。
- 顶部回弹、完全吸顶和刷新 reveal 阶段，pin 不动则不传播 offset。
- Header 展开优先于刷新。

### 8.7 PageContainer

横向分页容器，V1 使用内部 `UIScrollView` paging。

- 管理横向内容宽度和 child view frame。
- 发出连续 `PagePosition`。
- 支持 interactive drag 和 programmatic scroll。
- 切页开始时通知 HeaderHostCoordinator 固定 Header。
- 切页完成或取消后通知 PageRequestPipeline 提交或回滚。

### 8.8 PageRequestPipeline

统一处理 Tab 点击、公开 API 和横向手势。

```swift
enum PageRequestSource: Sendable {
    case tabTap
    case api
    case gesture
}

struct PageRequest: Sendable {
    var source: PageRequestSource
    var fromIndex: Int
    var targetIndex: Int
    var animated: Bool
}
```

流程：

1. 校验 page count 和 index。
2. 空页或越界 no-op。
3. 建立 pending selection。
4. 驱动 PageContainer。
5. 输出 PagePosition 给 TabBar/indicator。
6. 完成时提交 `selectedIndex`。
7. 取消时回滚 pending selection 和 indicator。

### 8.9 TabBarController

TabBar 只渲染和发请求。

- 从 data source title 构建 item。
- item 点击发出 `PageRequestSource.tabTap`。
- 根据 `PagePosition` 更新 selected progress。
- 更新 accessibility selected traits。
- 不直接改 selectedIndex、child、contentOffset 或 Header 状态。

### 8.10 IndicatorFocusRect

Indicator frame 的唯一输入是 item/title frame、width mode 和 `PagePosition`。

第一版等宽 TabBar 不横向滚动，但仍使用 focus rect 模型。后续可滚动 TabBar 可复用 focus rect 中心点计算 horizontal content offset，并夹取到内容边界。

### 8.11 RefreshHandoffCoordinator

刷新协调器只做资格判断和移交记录。

```swift
enum RefreshHandoff: Sendable, Equatable {
    case externalScrollView(scope: CollapsiblePagerRefreshMode, index: Int)
}
```

规则：

- Header 未完全展开时，下拉只展开 Header。
- Header 完全展开且当前 child 在顶部后，继续下拉才允许外部刷新 reveal。
- 同一次下拉手势最多移交一次。
- `.overall` 交给当前 child scroll view 上的外部整体刷新机制。
- `.child` 交给当前 child scroll view 上的外部局部刷新机制。
- `.child` 没有刷新控件时，不降级触发 `.overall`。
- 核心不提供 `endRefreshing()`。

### 8.12 GestureArbiter

集中处理手势优先级：

- 系统返回手势优先，尤其第一页右滑返回。
- Header 区域默认不启动横向分页。
- 横向意图成立后冻结纵向 coordinator。
- 纵向意图成立后不抢横向 PageContainer。
- 刷新 reveal 或 end 动画期间，V1 可以禁止横向切页。

## 9. 状态模型

```swift
struct CollapsiblePagerState: Sendable {
    var selectedIndex: Int
    var effectiveSelectedIndex: Int?
    var pendingSelectedIndex: Int?
    var pageCount: Int
    var pagePosition: PagePosition?
    var pinAnchorY: CGFloat
    var headerHeights: CollapsiblePagerHeaderHeights
    var headerVisibleHeight: CGFloat
    var collapseProgress: CGFloat
    var headerMountOwner: HeaderMountOwner
    var verticalPhase: VerticalPhase
    var activeRefreshHandoff: RefreshHandoff?
}
```

`PagePosition`：

```swift
struct PagePosition: Sendable, Equatable {
    var rawPosition: CGFloat
    var fromIndex: Int
    var toIndex: Int
    var progress: CGFloat
    var direction: PageDirection
    var isInteractive: Bool
}
```

当 `pageCount == 0`：

- `selectedIndex == 0`
- `effectiveSelectedIndex == nil`
- `pendingSelectedIndex == nil`
- `pagePosition == nil`
- 不加载 child
- TabBar 不创建 item
- indicator frame 为 `nil`
- delegate 不收到 selection 回调

## 10. 关键行为

### 10.1 reloadData

1. 请求 page count。
2. 小于 0 时 clamp 到 0，并通过 assertion 暴露接入错误。
3. 重建 Tab item 数据。
4. 如果 page count 为 0，清空 loaded child、pending selection、page position 和 indicator。
5. 如果 page count 大于 0，把已提交 selectedIndex clamp 到有效范围，并更新 effective selection。
6. Header content 只在完整 reload 时重新请求。

### 10.2 selectPage

`selectPage(at:animated:)` 是请求，不是立即提交。

- 空页 no-op。
- 负数或越界 no-op。
- 目标等于当前 effective selection 时，只校准 Tab/indicator，不重复 delegate。
- 有效请求进入 PageRequestPipeline。
- animated 为 false 时也经过同一提交路径，只是 PageContainer 立即定位。

### 10.3 Header 布局刷新

V1 只公开 immediate 行为：

```swift
public func reloadHeaderLayout(offsetPolicy: CollapsiblePagerHeaderOffsetPolicy = .preserveVisualPosition)
```

如果调用发生在拖拽、减速、横向切页或刷新动画中，内部可以设置 dirty flag，等 idle 后合并应用。这个 deferred 行为是内部安全策略，不作为公开 API。

### 10.4 横向切页和纵向状态

横向切页开始：

- Header 迁移到 fixed overlay。
- VerticalScrollCoordinator 暂停处理当前 child offset 回调。
- 如果旧 child 正在非回弹减速，可以终止减速。
- 如果旧 child 正在顶部回弹，fixed overlay 保持回弹视觉位置。

横向切页结束：

- 完成则提交目标 selected index。
- 取消则回滚到来源 selected index。
- 目标 child 加载并成为 current child。
- Header 根据 pin anchor 恢复到目标 child mount 或 fixed overlay。
- 顶部回弹旧 child 做 offset 校准。

### 10.5 下拉刷新

下拉刷新是外部机制，核心只定义移交条件：

- Header 完全展开。
- 当前 child 到顶部。
- 当前手势尚未移交。
- refreshMode 不是 `.none`。
- 当前没有横向切页或 layout reload 冲突。

外部刷新控件可能通过动画修改 `contentOffset`。在 reveal/end 阶段，HeaderHostCoordinator 可以临时固定 Header，避免 child mount 和 fixed overlay 闪跳。

## 11. 测试策略

优先单测纯值和状态机：

- Header height clamp。
- collapse progress。
- pin threshold。
- layout reload offset policy。
- zero page selection fallback。
- PagePosition 计算。
- PageRequestPipeline 完成/取消提交。
- IndicatorFocusRect。
- RefreshHandoff 资格和互斥。
- pin anchor delta 同步非当前 child offset。
- 顶部回弹不传播 offset。

UIKit 集成测试覆盖：

- Header view/controller containment。
- Header view 在 mount 和 fixed overlay 之间迁移。
- child containment。
- 显式 scroll provider。
- 横向切页期间冻结纵向协调。
- 刷新 reveal/end 期间 Header 不闪跳。
- 系统返回手势优先级。

示例 App 手动 QA 覆盖：

- 展开、折叠、吸顶。
- 短内容、空内容、长内容。
- `.overall` 和 `.child` 外部刷新。
- 快速点击 Tab。
- 横向滑动取消。
- 顶部回弹中切页。
- 纵向减速中切页。
- Header 内容变高/变矮。
- 横竖屏和 Dynamic Type。

## 12. V1 交付范围

V1 必须交付：

- 公开容器和 UIKit 风格协议。
- Header `UIView`/`UIViewController` 支持。
- Header controller 稳定 containment。
- fixed 和 automatic Header 高度。
- 等宽文本 TabBar。
- 默认下划线 indicator。
- PagePosition 和 focus rect。
- 内部 paging `UIScrollView`。
- PageRequestPipeline。
- PinAnchor 和纵向滚动协调。
- Header mount/fixed overlay 迁移。
- RefreshHandoff。
- zero page fallback。
- 布局与状态单元测试。
- 示例 App 基础验收场景。

后续阶段：

- 可横向滚动 TabBar。
- 自定义 indicator。
- 自定义 Header 高度 provider。
- 自定义 TabBar layout provider。
- Header 下拉拉伸。
- Header 布局刷新动画。
- 更细的刷新资格 provider。

## 13. 设计原则

- 核心包做容器，不做业务。
- 纵向状态以 pin anchor 为真相。
- 横向状态以 PagePosition 为真相。
- selected index 只在 page request 完成后提交。
- TabBar 是渲染者和请求者，不是状态所有者。
- Refresh 是外部机制，核心只做手势移交。
- UIKit 留在 `@MainActor`，纯计算保持值语义。
