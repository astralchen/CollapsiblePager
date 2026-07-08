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
- 内部使用不可见 `pin` 作为当前页纵向状态锚点。Header 可见高度和吸顶状态由当前 child 的 `contentOffset.y` 与 `pin` 共同决定；非当前 child 不持续跟随当前页滚动，但在被选为当前页时必须按共享 `pin` 做一次可见位置归一化，避免 Header/TabBar 在切页提交时跳动。
- 每个 child scroll view 有自己的 Header mount。真实 Header 视觉内容只有一份，在 child mount 和 fixed overlay 之间迁移。
- 横向切页期间冻结纵向 KVO/observer 回调，Header 迁移到 fixed overlay。Tab 点击提交时以当前共享 `pin` 为准归一化目标 child；只有当前已经完全吸顶且目标 child 也滚过吸顶阈值时，才保留目标 child 更深的列表 offset。公开 API 仍按当前 `pin` 对齐目标 child；正常横向手势提交时，若完成页就是 pending target，则以目标 child 当前 offset 采纳新的 `pin`，避免目标页内容与 Header/TabBar 使用两套纵向状态。手势过冲后稳定到中间页时仍保持当前 `pin` 并对齐目标 child。
- 顶部回弹、完全吸顶、刷新 reveal/end 动画是 pin anchor 最有价值的场景。pin 不动时，非当前 child 不应收到错误 offset delta。
- 刷新不是核心拥有的业务事件。示例中的整体刷新和局部刷新都由外部 child scroll view 安装刷新控件，核心只保证 Header 展开优先、刷新手势不与 Header/切页冲突。

这些结论落到本项目后，形成 `VerticalScrollCoordinator`、`HeaderHostCoordinator`、`PinAnchor`、`RefreshHandoff` 和 `GestureArbiter`。

### 2.2 Tabman 的优势

Tabman 的优势是横向分页状态链路和 TabBar 渲染分层。

- Bar 只负责展示 item、接收点击、发出 scroll request。
- Page controller 才拥有页面切换过程，输出连续 page position。
- Tab item selected progress、indicator frame、可滚动 bar 的 focus rect 都消费同一个 position。
- 点击 Tab、API 跳转和横向滑动都进入同一条页面请求链路。selected index 在完成或取消后统一提交。Tab 点击不触发 UIViewController 转场动画；公开 API 选择和横向手势按调用参数或手势状态决定动画。
- Indicator focus rect 由 item/title frame 和连续 position 推导，不应散落成 `selectedIndex`、`fromIndex`、`progress` 多套入口。
- Page controller 负责 child appearance lifecycle。自研 `UIScrollView` paging 不能依赖 UIKit 自动推断页面可见性；横向转场开始和结束时必须统一转发 `beginAppearanceTransition` / `endAppearanceTransition`。
- Page controller 使用 bounded child window 控制 UI 层级规模。已经访问过但远离当前页的 child 必须从横向滚动层级和 containment 中卸载，V1 默认只保留当前页和相邻页。
- `UIPageViewController.setViewControllers(_:direction:animated:completion:)` 的可借鉴点是 programmatic 转场只描述 source、target、方向和完成回调。V1 仍使用内部 `UIScrollView` paging，但非相邻跳转必须按 source/target 直接切换，不通过连续 `contentOffset` 滚过中间页面。

这些结论落到本项目后，形成 `PageContainer`、`PageRequestPipeline`、`PagePosition`、`TabBarController` 和 `IndicatorFocusRect`。

### 2.3 组合原则

两个参考库侧重点不同，组合时必须保持所有权清晰：

- Nested 只作为纵向嵌套滚动、Header 迁移、刷新移交和手势冲突的架构参考。
- Tabman 只作为横向切页、Tab selected progress、indicator focus rect 和状态提交链路的架构参考。
- TabBar 不修改 child 或纵向状态。
- Refresh 不修改业务数据，也不要求指定刷新控件。
- Child 不反向拥有 Header、TabBar 或 selected index。
- Child 不自行处理横向页面转场 lifecycle；由容器按 page request pipeline 统一转发。

## 3. V1 目标

- 提供公开 `CollapsiblePagerViewController`。
- 支持 Header 内容为 `UIView` 或 `UIViewController`。
- 支持多个 child view controller，并使用标准 UIKit containment。
- 要求参与协调的 child 显式提供主 `UIScrollView`。
- 支持 Header 折叠、展开、吸顶和布局刷新。
- 支持默认等宽文本 TabBar 和默认下划线 indicator。
- 支持点击 Tab、API 选择和横向滑动切页。
- 支持连续 `PagePosition` 驱动 Tab selected progress 和 indicator focus rect。
- 支持 `.none`、`.container`、`.child` 三种刷新 handoff 能力路由。
- 支持状态栏点击顶滚，并按 Header 是否吸顶在容器 host 与当前 child scroll view 之间切换唯一响应者。
- 支持没有 child 的空态兜底。
- 支持作为业务 `UITabBarController -> UINavigationController -> UIViewController` 层级中的内容页，不假设自己是 window root。
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
open class CollapsiblePagerViewController: UIViewController {
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

`CollapsiblePagerViewController` 允许业务侧继承，用于接入自有导航、埋点或页面生命周期扩展。容器显式开放 UIKit 生命周期 override，包括 `viewDidLoad`、`viewWillAppear`、`viewDidAppear`、`viewWillDisappear`、`viewDidDisappear`、`viewDidLayoutSubviews` 和 `shouldAutomaticallyForwardAppearanceMethods`；业务子类 override 这些入口时应调用 `super`，否则会破坏内部 containment、布局和 appearance forwarding。`reloadData()`、`selectPage(at:animated:)`、`reloadHeaderLayout(offsetPolicy:)`、`configuration`、`dataSource`、`delegate`、`selectedIndex`、`effectiveSelectedIndex` 和 `containerRefreshHostScrollView` 保持 `public` API，不作为外部 override 点。

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

Delegate 只描述容器状态变化，不承载刷新生命周期。`.container` 和 `.child` 都不通过 delegate 转发刷新触发事件。

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
    public var refreshHandoffMode: CollapsiblePagerRefreshHandoffMode
    public var headerPullDownRefreshBehavior: CollapsiblePagerHeaderPullDownRefreshBehavior
}
```

V1 默认值：

- Header：`fixed(max: 260, min: 0)`，`topBehavior = .insideSafeArea`。
- TabBar：`height = 48`，`placement = .belowHeader`。
- Pinning：`pinBelowNavigationBar(offset: 0)`，没有导航栏时回退到 safe area top。
- Indicator：短下划线，`height = 3`，`cornerRadius = 1.5`，`width = fixed(28)`。
- Paging：允许横向滑动，横向默认回弹；业务方可通过 `configuration.paging.bouncesHorizontally = false` 关闭。Tab 点击无 UIViewController 转场动画。
- Refresh：`.container`，默认提供整体刷新 handoff 体验。

Header 顶部行为：

```swift
public enum CollapsiblePagerHeaderTopBehavior: Sendable, Equatable {
    case insideSafeArea
    case extendsUnderTopSafeArea
}
```

`.insideSafeArea` 是默认行为，Header 顶部从导航栏底部或 safe area top 开始。`.extendsUnderTopSafeArea` 只扩展 Header 视觉 frame 到容器顶部；TabBar pin 位置、PageContainer frame 和 child 内容仍保持在安全区域内。

刷新 handoff 配置：

```swift
public enum CollapsiblePagerRefreshHandoffMode: Sendable {
    case none
    case container
    case child
}
```

`CollapsiblePagerRefreshHandoffMode` 只决定 Header 完全展开后的继续下拉能力路由，不决定刷新控件类型、刷新任务和结束时机。默认 `.container` 路由到容器拥有的 `containerRefreshHostScrollView`，提供整体下拉刷新体验；`.child` 路由到当前 child 提供的 `pagerScrollView`，容器只记录 handoff 以协调 Header、手势和横向分页；`.none` 不记录 handoff，但不会移除或禁止业务已经安装在 child 上的刷新机制。

Header 区域下拉刷新策略：

```swift
public enum CollapsiblePagerHeaderPullDownRefreshBehavior: Sendable {
    case allowsChildRefresh
    case suppressesChildRefresh
}
```

默认 `.allowsChildRefresh` 保持 UIKit 语义：Header 展开并稳定挂在当前 child 时，Header 区域属于 child scroll view 的顶部占位区域，从 Header 开始下拉可以拉出 child 自有刷新机制。`.suppressesChildRefresh` 会给 Header host 安装内部向下拖拽 gate，并让 child pan 等待该 gate 失败；当 Header 已完全展开、当前 child 到顶部且下拉从 Header 区域开始时，gate begin，child 不进入 top bounce，因此不会从 Header 区域拉出 child refresh。gate 的下拉意图判断同时参考 translation 和 velocity；`gestureRecognizerShouldBegin(_:)` 中 translation 可能尚未累积，此时必须允许明确向下的 velocity 触发 gate。该策略不影响 child 内容区域下拉，也不创建、替换或结束业务刷新控件。

`containerRefreshHostScrollView` 是框架拥有的外层纵向 host，包住 `PageContainerView` 与 `PinnedSurfaceView`。它的刷新 reveal 基线对齐 content viewport 顶部，也就是 `pinY = max(navigationBar.maxY, safeArea.top) + offset`；静止时 `contentInset.top == pinY` 且 `contentOffset.y == -pinY`。host 内部内容层会反向平移 `-pinY`，因此 Header、TabBar 和 PageContainer 的屏幕位置仍严格服从 layout engine 输出。child 自己的 managed top inset 仍只属于 child scroll view，用来表达 Header/TabBar 占位。这个 host 只提供外层纵向刷新坐标系和手势入口，不提供从 `-pinY` 到 `0` 的普通内容滚动区间；它的 content size 必须让 neutral baseline 成为正常滚动上界。业务可以在上面安装自己的刷新机制，也可以不安装。业务仍只负责是否安装刷新机制、刷新任务和结束时机。

在 `.container` 模式的顶部下拉路径中，容器会让 current child 的 pan gesture 等待 `containerRefreshHostScrollView.panGestureRecognizer` 失败。host 只有在 Header 完全展开、current child 位于 managed top boundary 且手势为下拉时才会作为刷新 reveal owner begin；其他方向和其他模式会快速失败并交还给 child。host 的下拉意图判断同时参考 translation 和 velocity；当 `gestureRecognizerShouldBegin(_:)` 发生在 translation 仍为零但 velocity 已明确向下的早期阶段时，host 仍应 begin，避免错误失败后让 child pan 接管并进入 proxy bounce。这样从 child 内容顶部起始的下拉不会先触发 child 自身 top bounce，再被容器拉回边界，从源头避免内容下移抖动。

Header/TabBar 区域本身不一定命中 current child scroll view。Header 完全展开且 current child 位于 managed top boundary 时，如果手势从 Header 或 TabBar 区域明确向上开始，`containerRefreshHostScrollView` 可以 begin 一个 upward proxy 会话；该会话不表示刷新 handoff，也不创建 `.containerHost` active handoff。upward proxy 生命周期内，host 每次被拖到 neutral baseline 以上，都把这段向上 delta 转交给 current child 的 `contentOffset`，再把 host 夹回 neutral baseline；如果同一 host pan 抖动到 baseline 以下，也只夹回 baseline，不进入刷新 reveal。这样从 Header/TabBar 开始向上拖也能连续折叠 Header 或推动列表，而不会被外层刷新 host 吞掉或产生上移后的回弹。

状态栏点击顶滚必须保证 window 内只有一个框架管理的响应者。PageContainer 的横向 paging scroll view 永远 `scrollsToTop = false`。当 `collapseProgress < 1` 时，响应者是 `containerRefreshHostScrollView`，所有 loaded child scroll view 都关闭 `scrollsToTop`；host 收到 `scrollViewShouldScrollToTop` 后，如果 Header 仍处于半折叠状态，会把 current child 动画滚回 expanded managed top boundary，因为 V1 的 `PinAnchor` 仍由 current child 的 `contentOffset` 表达。当 `0 < collapseProgress < 1` 时，host 仍保持视觉上的 neutral baseline，但会打开最小的状态栏顶滚激活 inset，让 UIKit 不把 host 判定为已经在顶部而跳过 `scrollViewShouldScrollToTop`；该 inset 属于 neutral refresh inset 的一部分，只服务系统顶滚触发条件，不创建从 `-pinY` 到 `0` 的普通内容滚动区间，并在完全展开、吸顶或没有有效页面时关闭。当 `collapseProgress == 1` 时，host 和非当前 child 都关闭 `scrollsToTop`，只有当前可见 child 的 `pagerScrollView` 响应状态栏点击。没有有效页面选择时，host、PageContainer 和所有 child 都不参与状态栏顶滚。

参考 NestedPageViewController 的顶部 bounce 与 Header fixed container 处理，`.container` handoff 期间外层 host 的 overscroll 是唯一纵向 reveal 来源。由于 `PinnedSurfaceView` 与 `PageContainerView` 同属 host 内容层，host overscroll 会让 Header、TabBar 和 page content 作为一个整体下移；child 直接进入 top bounce 的兜底路径只记录代理 overscroll，并立即把 child 拉回 managed top boundary。代理 overscroll 一旦为负，就已经进入 container reveal 生命周期；即使 active handoff 尚未提交，Header host 也必须保持在 fixed overlay，不能短暂回迁到 child mount。同一手势中，如果外层 host 作为非 tracking scroll view 被 UIKit 临时校正回 neutral baseline，保存的代理 overscroll 仍是 reveal 源值，容器必须恢复该 offset，直到 handoff 结束或业务刷新机制接管 content inset。业务刷新机制接管 content inset 后，容器只释放内部 proxy overscroll，不把 host offset 抢回 neutral baseline。host 自己接管的下拉也不能仅因为 `scrollViewDidScroll` 中 offset 短暂碰到 neutral baseline 就结束 handoff；结束应发生在拖拽、减速或滚动动画结束后的 idle finish 阶段。child 代理路径也必须监听 child pan 的 ended/cancelled/failed，在没有业务刷新 inset 接管且 child、host 都 idle 时执行同一套 finish reset，避免没有后续 `contentOffset` 回调时旧 proxy 停留。除 Header/TabBar upward proxy 会话外，如果 UIKit 在 active `.containerHost` 期间把 host offset 推到 neutral baseline 以上，容器必须立即夹回 baseline，不能让内容层向上滚动。这样不会在 TabBar 与 page content 之间产生空洞，也不会让 Header、TabBar 和 child frame 被 host 的普通滚动区间整体顶到导航栏下方或状态栏区域。

当 `.containerHost(index:)` 已经是当前 page 的 active handoff，且 host 或代理 overscroll 仍未回到 neutral baseline 时，后续 container host pan 的 `shouldBegin` 必须保持 owner 连续性。UIKit 在新一轮 pan 进入 `gestureRecognizerShouldBegin(_:)` 的早期可能同时给出 `translation == .zero` 和 `velocity == .zero`；这只是初始采样不足，不应让 host pan fail 并把手势重新交给 child。代理 overscroll 只在 child 仍持有触摸、或 host 作为 idle/recovery scroll view 被 UIKit 临时校正时作为 reveal 源值；一旦 `containerRefreshHostScrollView.panGestureRecognizer` 真正 begin，owner 必须移交给 host 并清空代理值，后续 offset 由 host pan 自己驱动。否则 restore 分支会持续把 host 拉回旧 proxy 位置，表现为吸顶后再下滑无法继续整体移动。只有 idle finish 清空 active handoff 和 overscroll 后，下一次下拉才重新按方向、Header 展开和 child top 边界判断 owner。

Header 展开优先级高于 `.container` 刷新 handoff。已经代理到 container host 的下拉，如果 Header 重新进入未完全展开状态，且 container host 仍处于业务刷新机制未接管的 neutral inset 状态，容器必须取消当前 container handoff、清空代理 overscroll，并把 host offset 还原到 neutral baseline。child 在 Header 完全展开时被框架拉回 managed top boundary 是正常代理路径，不作为取消条件；该路径继续以 container host / proxy overscroll 作为唯一 reveal 源值，直到手势结束后的 idle finish 或业务刷新机制接管 content inset。业务刷新机制接管后，proxy 必须清空，后续停留位置由业务刷新机制自己的 inset/offset 动画表达。这样旧 handoff 不会继续把 Header 固定在 overlay，也不会影响下一次从 Header 或内容区开始的下拉判定。

示例 App 当前使用系统 `UIRefreshControl` 演示业务侧如何在 container host 或 child scroll view 上挂载顶部刷新机制，并在根 Pager 的 `Long` child 上使用 `Refreshable.loadMoreable` 演示底部加载更多。核心包不创建、不包装、不替换这些控件，也不介入具体刷新实现。业务侧异步刷新或加载更多任务如果跨 page 切换完成，应自行取消或忽略离屏 child 的完成回调，避免在离屏 scroll view 上追加数据、重载列表并触发 `contentSize` / `contentOffset` 竞争。第三方底部加载组件如果支持“滚动接近底部自动触发”，业务侧应按场景关闭或加门禁；Pager 在切页和 layout 恢复时会程序化校准 child `contentOffset`，该 offset 校准不能被误认为用户上拉加载。Tab 点击完成后，如果容器为了保持当前 Header 位置而校准了目标 child offset，后续非用户触发的更深 `contentOffset` 回弹不能立即改写共享 `PinAnchor`；容器会短期锁定本次 Tab 选择建立的 offset，直到用户真实拖动、切到其他 page 或向更展开方向移动。示例 App 因此把 Refreshable 的 `automaticTriggerOffset` 设为 `nil`，保留用户拖拽上拉触发。Refreshable bottom footer 与 Pager 管理的底部遮挡共同作用在 `contentInset.bottom` 上；示例 App 在进入 no-more 状态后会确保 bottom inset 至少包含 Pager 暴露给 scroll indicator 的底部遮挡和 Refreshable footer 保留高度，避免“没有更多数据”落入底部 TabBar 视觉区域。因为 Pager 可以按 child window 卸载并重新请求远端 child，示例 App 的 Long 列表行数、已加载数量、no-more 状态和 no-more footer 是否应保持可见都由 data source 持有的 page state 保存，child controller 只负责渲染该状态；业务方不应把必须跨切页保留的数据或 footer 可见语义只存在可被重建的 child controller 实例中。示例 App 的 `Refresh` 根 Tab 提供 `.none`、`.container`、`.child` 三种独立 pager，用于验证刷新 handoff 配置差异。

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

PageContainer 使用 NestedPageViewController 式 content viewport：顶部从 TabBar pin 位置开始，也就是导航栏底部或无导航栏时的 safe area top，底部到 pager bounds 底部。导航栏底部必须先转换到 `CollapsiblePagerViewController.view` 的本地坐标系；当 pager 作为子控制器嵌入在导航栏下方的自定义区域时，不能直接使用 `navigationBar.frame.maxY` 再次下推 Header/TabBar。这样 `CollapsiblePagerTabBarView` 与横向 paging 区域都处在 safe area top 到屏幕底部的范围内，child scroll view 不会滚入状态栏/导航栏区域。Header 与 TabBar 的滚动占位仍通过 child scroll view 的 managed top inset 表达；child 初始 offset 按 `pinAnchorY - managedTopInset` 校准，确保首次展示时 Header 在 child 内容之前可见。`.container` refresh handoff 启用时，外层 host 不复用 child managed inset，而是作为完整外层 scroll host 包住 PageContainer 与 PinnedSurface。

Header frame 的顶部由 `CollapsiblePagerHeaderTopBehavior` 决定。默认 `.insideSafeArea` 时 Header 顶部与 content viewport 顶部一致；`.extendsUnderTopSafeArea` 时 Header 顶部为 pager bounds 顶部，但 Header 底部仍贴着 TabBar 顶部，TabBar 和 child 布局不随之进入 unsafe 区域。

### 8.4 HeaderHostCoordinator

负责 Header 的生命周期和视觉宿主迁移。

- Header 支持 `UIView` 和 `UIViewController`。
- Header controller 使用标准 UIKit containment，挂到 pager 下。
- Header controller 的 appearance lifecycle 由 pager 手动转发。pager 出现/消失时转发 `beginAppearanceTransition` / `endAppearanceTransition`；pager 已可见时替换或清空 Header controller，会先让旧 controller disappear，再让新 controller appear。
- Header 视觉迁移只移动 controller 的 `view`。
- Header host 在 `HeaderMountView` 和 fixed overlay 之间迁移只是视觉宿主切换，不触发 Header controller appear/disappear。
- 每个 child 有自己的 `HeaderMountView`，位于 managed top inset 对应区域。
- `HeaderMountView` 的滚动占位高度等于 Header max height + TabBar height；挂载其中的 `HeaderHostView` 只占 Header max height，不覆盖底部 TabBar 预留区。
- Header 展开、当前 child 未进入顶部回弹，且未处于横向切页、刷新或布局刷新冲突时，视觉宿主使用当前 child 的 `HeaderMountView`。
- fixed overlay 用于吸顶、横向切页、`UIScrollView.bounces` 顶部回弹、刷新 reveal/end、layout reload。顶部回弹只由 `contentOffset.y < -managedTopInset` 判定，不改变 child 自有刷新机制。

### 8.5 ChildStore

负责 child view controller 的缓存、加载、释放和主 scroll view 获取。

- 通过 data source 创建 child。
- 使用标准 containment。
- 校验 child 是否遵守 `CollapsiblePagerScrollProviding`。
- 设置 content inset、scroll indicator inset、contentInsetAdjustmentBehavior。
- Pager 接管 child scroll view 后，vertical scroll indicator 的 top/bottom inset 由当前 layout 输出管理；bottom 使用安全区与可见底部遮挡的最大值，不保留接管前可能由 UIKit 自动调整产生的旧值，并关闭 `automaticallyAdjustsScrollIndicatorInsets` 避免 UIKit 再追加 safe area 或 bar 避让。
- Child content bottom inset 的 Pager 管理基线使用安全区、可见底部遮挡和短内容补偿。外部刷新/加载更多组件在该基线之上追加的正向 bottom inset 需要在 `contentSize` 触发重算时保留，避免 footer / no-more 提示被后续 managed inset 写回抹掉。
- 短内容或空内容 child 按当前 viewport、contentSize、managed top inset 和 pin threshold 计算 bottom inset 补偿，确保真实内容不足一屏时仍可滚到吸顶阈值。
- Child root view 和 page view 继续铺满 PageContainer viewport，不通过把 child frame 下移来避让 Header/TabBar；Header/TabBar 占位由 child scroll view 的 managed inset 与 guarded contentOffset 表达。业务侧空态、overlay 或 background view 若需要视觉居中，应按 scroll view 当前可见区域、managed top boundary 和底部遮挡计算，而不能直接以 child root view frame 作为内容可见区域。
- `contentSize` 变化触发 managed inset 重算时，只在目标 `contentInset`、scroll indicator inset 或 adjustment 行为实际变化时写回 `UIScrollView`；长列表滚动中由 UITableView 估算高度产生的 contentSize 微调不能反复重写相同 inset，避免底部滚动被 UIKit 夹回旧边界。
- 未访问 child 默认从展开态 top boundary 初始化；如果该 child 是 Tab 点击的目标页，则在请求发起时先继承当前 `pinAnchor` 对应的 offset，避免点击提交后 Header 从半折叠或吸顶状态跳回展开态。
- Tab 点击提交后，新的 current child 不使用自己的旧 offset 反推 pin anchor，而是保持当前共享 `pinAnchor` 并按需校准目标 offset；只有当前已经完全吸顶且目标 child 也超过吸顶阈值时，才保留目标 child 更深的列表位置。公开 API 与横向手势提交后，新的 current child 如果低于当前 pin anchor 所需 offset，仍通过 guarded update 补齐；如果已经滚得更深，保留该 child 自己的列表位置。
- child window 裁剪卸载 controller 前必须保存该 index 的 contentOffset snapshot。重新加载时如果内容尺寸暂时不足以恢复，offset 恢复保持 pending，并在后续 `contentSize` 变化、managed inset 重算后继续尝试。
- 为每个 loaded child 创建 HeaderMountView。

### 8.6 VerticalScrollCoordinator

纵向滚动状态机。职责：

- 只处理当前 child 的 `pagerScrollView` 回调。
- 横向切页期间忽略纵向回调。
- 使用 guarded update 主动修正 offset，避免递归。
- 通过 pin anchor 计算 Header visible height 和 collapse progress。
- 非当前 child 默认不跟随当前页 pin anchor delta；它们保留自己的纵向位置。`VerticalScrollCoordinator` 仍支持受控的 sync eligible 集合，用于需要显式同步的内部场景。
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
3. 建立 pending selection，并记录 pending 请求来源；如果目标等于当前 `effectiveSelectedIndex` 且已有 pending target，视为用户点回当前页，取消 pending selection 并回滚 indicator。
4. 驱动 PageContainer；相邻动画切换使用 paging scroll 动画，非相邻 programmatic 跳转直接设置目标页并完成。
5. 输出 PagePosition 给 TabBar/indicator。
6. 完成事件默认必须匹配当前 `pendingSelectedIndex` 才提交 `selectedIndex`。横向手势可能在同一次拖拽中过冲到更远页后又停在中间页；当 pending 来源是 `.gesture`，且 PageContainer 的稳定 `PagePosition` 已停在 completion target 时，提交实际停靠页。
7. `UIScrollView` 可能在 `scrollToPage(animated:)` 启动期间同步发出 completion；容器必须先暂存该 completion，等 `PagePosition` 稳定到 completion target 后再消费。若 pending target 已经稳定可见但 completion 已被启动期保护延后，用户再次点击同一 Tab 时直接提交该 pending selection，不能重新发起一笔等不到完成回调的动画。
8. 完成后按当前页裁剪 child window，只保留当前页和相邻页。
9. 横向手势回到来源页时取消并回滚 pending selection 和 indicator。
10. 被后续 Tab/API 请求取代的旧动画完成回调是 no-op，不得提交中间页、裁剪 child window、重放旧 offset 或结束到旧目标的 child appearance transition。

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

> 当前实现状态（2026-07-05）：纯值 `RefreshHandoffCoordinator` 与规则测试已落地；容器已接入 `configuration.refreshHandoffMode`。Header 未完全展开或 current child 未到 managed top boundary 时不移交；active handoff 会让 `GestureArbiter` 禁止横向分页。核心仍不创建刷新 view、不新增 refresh delegate 或专用 refreshable child 协议，也不调用结束刷新。

```swift
enum RefreshHandoff: Sendable, Equatable {
    case containerHost(index: Int)
    case childScrollView(index: Int)
}
```

规则：

- Header 未完全展开时，下拉只展开 Header。
- Header 完全展开且当前 child 在顶部后，继续下拉才允许外部刷新 reveal。
- 同一次下拉手势最多移交一次。
- `.container` 交给容器拥有的外层纵向 refresh host。
- `.container` 下，若当前 child 已在顶部且外层 refresh host pan 因明确向上意图拒绝接管，后续同一手势反向进入顶部 overscroll 时不再启动 container proxy handoff，只把 child 保持在 managed top boundary，下一次符合条件的下拉手势重新竞争 owner。
- `.child` 交给当前 child 提供的 `pagerScrollView`。
- `.child` 没有刷新控件时，不降级触发 `.container`。
- 核心不提供 `endRefreshing()`。

### 8.12 GestureArbiter

集中处理手势优先级：

> 当前实现状态（2026-07-04）：纯值 `GestureArbiter` 与优先级测试已落地；PageContainer 通过内部 paging `UIScrollView` 子类的 `gestureRecognizerShouldBegin(_:)` 接入横向 pan 开始判定，覆盖 Header 区域禁止分页、第一页 leading-edge 系统返回优先、内容区横向分页和 layout reload active 禁止分页。刷新 handoff active 期间禁用横向分页随 Task 16 接入真实刷新状态。

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
    var pendingPageRequestSource: PageRequestSource?
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

> 当前实现状态（2026-07-04）：源码中的 `CollapsiblePagerState` 先承载 selection、page count、`PagePosition` 和 `PinAnchor`；Header 视觉状态由 layout output 推导，刷新 handoff 暂由独立纯值 coordinator 表达，后续接入容器时再决定是否并回总状态。

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
- 目标等于当前 effective selection 且没有 pending target 时，只校准 Tab/indicator，不重复 delegate；如果已有 pending target，则取消 pending 切换并回到当前页。
- 有效请求进入 PageRequestPipeline。
- animated 为 false 时也经过同一提交路径，只是 PageContainer 立即定位。
- 横向 scroll 动画只用于相邻页面切换；非相邻切换采用 direct source/target 立即定位，不滚过中间页。
- TabBar item 点击内部使用 `.tabTap` 请求；相邻页允许横向 scroll 动画且 child controller appearance transition 使用 `animated = true`，非相邻页直接定位且 child controller appearance transition 使用 `animated = false`。
- 快速连续 Tab/API 请求以最后一个 pending target 为准；旧请求的完成回调如果不再匹配 pending target，容器必须忽略该回调，不能把 `selectedIndex` 临时切到中间页。
- 如果相邻 Tab 动画的 completion 在启动期被暂存，且后续 `PagePosition` 已稳定到 pending target，再次点击同一目标 Tab 应提交该 pending selection，并清空 pending source，而不是重启动画。

### 10.3 Header 布局刷新

V1 只公开 immediate 行为：

```swift
public func reloadHeaderLayout(offsetPolicy: CollapsiblePagerHeaderOffsetPolicy = .preserveVisualPosition)
```

实现记录上一轮已应用的 Header heights。Header 高度变化时，容器通过 `CollapsiblePagerLayoutEngine.headerOffsetTransition(...)` 得到新的 `PinAnchor` 与 `contentOffsetCorrectionY`；其中 `contentOffsetCorrectionY` 是应用到 child `UIScrollView.contentOffset.y` 的真实差值，已经抵消 Header 最大高度变化造成的 managed top inset 变化。

reload 期间会同步修正 loaded child 和已卸载 child 的 preserved offset snapshot，并保持当前 Header 区间内的 `contentOffset.y + managedTopInset == PinAnchor`。这段 inset/offset 写入必须放在 `VerticalScrollCoordinator` 的 guarded update 内，避免 UIKit 因 `contentInset` 变化发出的同步滚动回调反向污染 `PinAnchor`。

如果调用发生在拖拽、减速、横向切页或刷新动画中，内部可以设置 dirty flag，等 idle 后合并应用。这个 deferred 行为是内部安全策略，不作为公开 API。

### 10.4 横向切页和纵向状态

横向切页开始：

- Header 迁移到 fixed overlay。
- VerticalScrollCoordinator 暂停处理当前 child offset 回调。
- loaded child 的 scroll indicators 临时隐藏，避免页面横向位移时列表滚动条出现在屏幕中间。
- 如果旧 child 正在非回弹减速，可以终止减速。
- 如果旧 child 正在顶部回弹，fixed overlay 保持回弹视觉位置。

横向切页结束：

- 完成则提交目标 selected index。
- 取消则回滚到来源 selected index。
- 过期的完成回调不属于完成或取消；它只记录为 ignored，不触发 page container 回滚、child window 裁剪或 offset 对齐。
- 目标 child 加载并成为 current child。
- 非相邻 programmatic 跳转不滚过中间页，完成后只保留目标页邻域 child window。
- 目标 child 按当前 `PinAnchor` 与 managed top inset 做 guarded contentOffset 补齐；Long 已吸顶后点击 Short/Empty 不应瞬间退出吸顶，回到已深度滚动但曾被 child window 卸载的 Long 时也不应重置到初始顶部位置。
- child scroll indicators 恢复到业务 child 原始配置。
- Header 根据 pin anchor 恢复到目标 child mount 或 fixed overlay。
- 顶部回弹旧 child 做 offset 校准。

### 10.5 下拉刷新

下拉刷新是外部机制，核心只定义移交条件：

- Header 完全展开。
- 当前 child 到顶部。
- 当前手势尚未移交。
- `refreshHandoffMode` 不是 `.none`。
- 当前没有横向切页或 layout reload 冲突。

外部刷新机制可能通过动画修改 `contentOffset`。在 reveal/end 阶段，HeaderHostCoordinator 可以临时固定 Header，避免 child mount 和 fixed overlay 闪跳。即使 `refreshHandoffMode == .none`，UIKit 顶部 bounce 期间也应临时固定 Header，使 Header 与 TabBar 保持同一坐标系。

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

- `UITabBarController -> UINavigationController -> CollapsiblePagerViewController` 集成层级，导航栏使用小标题。
- 展开、折叠、吸顶。
- 短内容、空内容、长内容。
- `.container` 和 `.child` 外部刷新 handoff。
- 快速点击 Tab。
- 导航栏按钮 push 新 pager 后，系统边缘返回手势仍可返回上一页。
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
