# CollapsiblePager 需求与技术架构

## 1. 背景

`CollapsiblePager` 是一个 UIKit 组件，用来构建“可折叠 Header + TabBar + 多个子页面”的界面。参考截图是个人主页形态：顶部大图和用户资料，下方是作品、推荐、收藏、喜欢等 Tab，每个 Tab 对应独立列表。

这个组件不能和“个人主页”业务绑定。它应该是一个通用容器，允许业务自定义 Header、Tab 样式、指示器、刷新策略和子页面内容。

当前仓库还是 Swift Package 骨架。本文件作为实现前的产品需求和技术架构规格。

## 2. 目标

- 提供一个可复用的 UIKit pager 容器，组合可折叠 Header 和多 Tab 子页面。
- 支持 `UITableView`、`UICollectionView` 和普通 `UIScrollView` 作为子页面滚动视图。
- 协调全局 Header 与当前子页面之间的纵向滚动。
- 支持点击 Tab 切换和横向滑动切换页面。
- 每个 Tab 独立保存自己的滚动位置。
- 支持 TabBar 位置、吸顶方式和指示器的配置。
- 支持 Header 内容或尺寸变化后的布局刷新。
- 支持整体下拉刷新，也支持当前 child view controller 下拉刷新。
- API 边界清晰，业务方不需要继承内部类即可使用。

## 2.1 技术要求

- 最低系统版本：iOS 13.0。
- 最低 Swift tools version：Swift 6.3。
- Swift 语言模式：Swift 6。
- UIKit 相关 API 必须满足 Swift 6 strict concurrency 下的安全并发要求。
- 所有触碰 UIKit 的 view controller、view、data source 回调、delegate 回调、滚动协调、刷新协调和布局失效逻辑都必须隔离到主 actor。
- 纯计算逻辑可以不放在主 actor，但前提是输入和输出都是值类型，并且不持有 UIKit 对象。
- 核心 API 不要求业务方使用 `async`/`await`。刷新和数据加载由业务方负责。后续如果增加异步辅助 API，UI 更新必须回到主 actor。
- 实现中不能从 detached task、后台队列或非主 actor 修改 UIKit 对象。
- 内部异步任务必须可取消，不能意外强持有 child view controller，也不能在 `CollapsiblePagerViewController` 销毁后继续执行。
- 公共配置优先使用值类型。配置中如果包含 UIKit 引用类型或自定义 provider，默认视为主 actor 绑定，除非文档明确说明。
- iOS 13 之后才引入的 API 必须做 availability 判断，或者不放入核心路径。

## 2.2 代码注释风格

- 公共 API 的文档注释参照 Apple iOS SDK 风格，使用 Swift documentation comments：`///` 或 `/** ... */`。
- 公共类型、协议、枚举、属性和方法应提供简洁注释，第一句说明“这个符号是什么”，后续再说明使用场景和约束。
- 代码注释正文使用中文，包括公共 API 文档注释和内部实现注释。
- 结构化标签保留 Swift / iOS SDK 常用英文格式，例如 `- Parameters:`、`- Returns:`、`- Note:` 和 `- Important:`。
- 参数、返回值和重要约束使用标准结构：`- Parameters:`、`- Parameter name:`、`- Returns:`、`- Throws:`、`- Note:`、`- Important:`。
- 注释描述 API 语义、调用时机、线程/actor 要求、边界行为和副作用，不描述显而易见的实现步骤。
- 内部实现注释只用于解释复杂状态机、滚动协调、刷新仲裁、offset 修正和非直观边界，不为简单赋值或 UIKit 常规调用写注释。
- 不在代码注释中记录临时计划、历史原因、调试信息或待办事项；这类内容应进入 issue、设计文档或提交记录。
- 示例风格：

```swift
/// 协调可折叠 Header 和多 Tab 子页面的视图控制器。
///
/// 当多个 child view controller 需要共享一个可展开 Header 和一个吸顶 TabBar 时，
/// 使用 collapsible pager 作为容器。
@MainActor
public final class CollapsiblePagerViewController: UIViewController {
    /// 重新测量 Header，并更新依赖 Header 的 child scroll inset。
    ///
    /// - Parameters:
    ///   - behavior: 应用新 frame 时使用的布局更新行为。
    ///   - offsetPolicy: 保持或重置当前滚动位置的策略。
    public func reloadHeaderLayout(
        behavior: CollapsiblePagerHeaderReloadBehavior = .immediate,
        offsetPolicy: CollapsiblePagerHeaderOffsetPolicy = .preserveVisualPosition
    )
}
```

## 2.3 Git 提交规范

- Git 提交信息使用中文，包括提交标题和提交正文。
- 提交标题应简洁说明本次变更的行为或结果，优先使用动宾结构，例如“补充并发安全要求”“实现默认 Tab 指示器”。
- 提交正文用于说明背景、关键取舍和验证结果；没有必要时可以省略。
- Git 命令、分支名、文件路径、类型名、API 名称和错误输出保持原文，不强行翻译。
- 如果使用类似 Conventional Commits 的前缀，前缀可以保留英文，说明文字使用中文，例如 `feat: 实现 Header 布局刷新`。
- 不使用“update”“fix”“misc”这类含义过宽的提交标题。

## 3. 第一版非目标

- 不实现网络请求、图片加载、缓存或用户资料模型。
- 不实现头像上传、背景图编辑等业务流程。
- Pager 级刷新触发时，不默认刷新所有 child 页面。
- 不支持同一个下拉手势同时触发内置整体刷新和 child 刷新。
- 不在第一版暴露完整替换内部 pager 引擎的能力。
- 核心包不依赖第三方 pager 库。

## 4. 核心用户故事

- 作为业务开发者，我可以在多个 child view controller 上方嵌入一个自定义 Header。
- 作为业务开发者，我可以配置 Header 最大高度、最小高度和高度测量方式。
- 作为业务开发者，我可以通过 data source 提供 Tab 标题和 child view controller。
- 作为业务开发者，我可以使用默认 Tab 指示器，也可以提供自定义指示器。
- 作为业务开发者，我可以把 TabBar 放在 Header 下方、覆盖在 Header 底部、放在 Header 内部，或使用自定义位置。
- 作为业务开发者，我可以选择下拉刷新是刷新整个 pager，还是只刷新当前 child 页面。
- 作为业务开发者，我可以在 Header 内容变化后要求组件重新计算布局，并避免视觉跳动。
- 作为用户，我可以向上滚动折叠 Header，并让 TabBar 吸顶。
- 作为用户，我可以向下滚动先展开 Header，然后才触发刷新。
- 作为用户，我可以切换 Tab，并在回到某个 Tab 时保留之前的滚动位置。

## 5. 产品需求

### 5.1 可折叠 Header

组件必须支持位于 Tab 内容上方的 Header。Header 可以固定高度，可以由 Auto Layout 自动测量，也可以由业务方自定义测量。

必备行为：

- Header 有最大展开高度和最小折叠高度。
- 向上滚动时，优先折叠 Header，Header 折叠到最小高度后，当前 child scroll view 才继续滚动。
- 向下滚动时，优先让 child scroll view 回到顶部，再展开 Header。
- 下拉刷新之前，Header 必须先完全展开。
- Header 可以根据折叠进度更新自身视觉状态。
- Header 内容变化后，可以刷新 frame。
- Header 刷新必须重新计算 Tab 位置、吸顶阈值、child scroll inset 和当前 content offset。
- Header 布局更新默认保持当前视觉位置，避免页面突然跳动。

典型内容变化：

- 用户名变化。
- 简介从 1 行变成多行。
- 头像、背景图、操作按钮等异步加载完成。
- Dynamic Type、安全区或横竖屏变化影响测量结果。

### 5.2 TabBar

组件必须提供 Header 和 child 内容之间的 TabBar。TabBar 独立于 child 页面实现。

必备行为：

- 支持固定宽度或等分宽度的 Tab item。
- 支持选中和未选中的文字样式。
- 支持默认指示器。
- 支持自定义指示器。
- 支持点击 Tab 切换。
- 支持和横向页面滑动同步。
- Tab 数量、尺寸或屏幕方向变化后，重新计算 item frame 和 indicator frame。
- 无障碍状态不能只依赖视觉指示器，Tab item 本身也要表达 selected 状态。

### 5.3 TabBar 位置

TabBar 位置必须可配置。位置是布局模型的一部分，不只是视觉样式。

内置位置：

- `belowHeader`：TabBar 放在 Header 下方，并占据布局高度。
- `overlayHeaderBottom(offset:)`：TabBar 覆盖在 Header 底部。
- `insideHeaderBottom(inset:)`：TabBar 作为 Header 内容的一部分。
- `fixedTop(offset:)`：TabBar 固定在顶部附近，不跟随 Header 滚动。

第一版可以优先实现 `belowHeader`、`overlayHeaderBottom(offset:)` 和“吸顶到导航栏下方”。自定义布局 provider 作为高级扩展点保留在架构中。

### 5.4 Tab 指示器

默认指示器应匹配参考截图：选中 Tab 下方有一条短下划线。实现也必须支持自定义指示器。

必备行为：

- 默认下划线的颜色、高度、圆角、宽度模式、底部 inset 和动画时长可配置。
- 横向滑动页面时，指示器可以连续跟随滑动进度移动。
- 点击 Tab 切换时，指示器可以动画移动到目标 Tab。
- 快速连续切换时，指示器必须取消或更新正在进行的动画。
- 自定义指示器只负责渲染，不拥有 Tab 选择逻辑。

宽度模式：

- 固定宽度。
- 匹配标题宽度。
- 匹配 item 宽度。
- item 宽度的某个比例。

### 5.5 Child 页面

每个 child 页面都是由 pager 容器管理的 child view controller。参与纵向滚动协调的 child 页面需要暴露自己的主滚动视图。

必备行为：

- 使用标准 UIKit containment 管理 child view controller 生命周期。
- 当前页面的滚动位置和 Header 状态同步。
- 非当前页面独立保存自己的 content offset。
- 空内容或短内容页面仍然可以 bounce，并在配置允许时支持刷新。
- Child 页面可以懒加载，减少不必要的内存占用。

### 5.6 下拉刷新

组件必须支持两种刷新语义：整体刷新和 child 刷新。

整体刷新表示刷新整个页面：Header 数据、Tab 数据，以及业务方选择的当前 Tab 数据。

Child 刷新表示只刷新当前 Tab 的列表数据。

必备行为：

- 只有 Header 完全展开后，才允许触发刷新。
- Header 折叠时向下拉，应该先展开 Header，而不是立刻刷新。
- 内置模式应避免同一个手势同时触发整体刷新和 child 刷新。
- 刷新模式可配置。
- 刷新状态属于 pager 或当前 child，取决于配置模式。
- 短内容页面也必须能 bounce 到足够触发刷新。

### 5.7 横向分页

组件应该支持 child 页面之间的横向滑动。

必备行为：

- 横向滑动时，Tab 选中进度和指示器连续更新。
- 点击 Tab 时，页面横向动画切换。
- 横向滑动取消时，Tab 和指示器回到原状态。
- 快速连续点击 Tab 时，最终停留在最后一次请求的目标页面。
- 正常使用中，纵向滚动手势和横向分页手势不能互相抢夺。

### 5.8 导航栏与安全区

组件必须可以放在 `UINavigationController` 中，并支持全屏 Header 设计。

必备行为：

- 支持状态栏和安全区感知的 Header 布局。
- TabBar 可以吸顶到安全区顶部或导航栏下方。
- 支持个人主页常见的透明导航栏效果。
- 不依赖 `automaticallyAdjustsScrollViewInsets`。
- 组件自己定义 child scroll view 的 content inset 策略。

## 6. 隐性需求与边界场景

- Header 内容变化可能发生在已滚动、拖拽中、刷新中或切换 Tab 中。
- Header 高度在折叠状态变化时，不能强行把用户顶回展开状态。
- TabBar 位置变化会影响 child content inset 和刷新阈值。
- 自定义指示器不能意外改变 TabBar 布局高度。
- Child view controller 的 scroll view 可能嵌套在其他 view 内部。
- 不同 Tab 可以有不同内容高度和不同刷新能力。
- Pager 支持整体刷新时，某个 child 仍然可以不支持 child 刷新。
- 重新加载 Tab 后，当前 selected index 可能已经不存在，需要 clamp。
- 横竖屏和 Dynamic Type 变化应复用同一套 layout invalidation 路径。
- 异步图片加载可能导致多次布局失效，实现需要避免抖动。
- 无障碍必须通过 Tab item selected 状态表达选中，而不能只靠视觉指示器。

## 7. 推荐公共 API

### 7.1 容器

```swift
@MainActor
public final class CollapsiblePagerViewController: UIViewController {
    public weak var dataSource: CollapsiblePagerDataSource?
    public weak var delegate: CollapsiblePagerDelegate?

    public var configuration: CollapsiblePagerConfiguration
    public var selectedIndex: Int { get }

    public init(configuration: CollapsiblePagerConfiguration = .default)

    public func reloadData()
    public func selectPage(at index: Int, animated: Bool)

    public func reloadHeaderLayout(
        behavior: CollapsiblePagerHeaderReloadBehavior = .immediate,
        offsetPolicy: CollapsiblePagerHeaderOffsetPolicy = .preserveVisualPosition
    )

    public func endRefreshing()
}
```

### 7.2 Data Source

```swift
@MainActor
public protocol CollapsiblePagerDataSource: AnyObject {
    func numberOfPages(in pager: CollapsiblePagerViewController) -> Int
    func pager(_ pager: CollapsiblePagerViewController, titleForPageAt index: Int) -> String
    func pager(_ pager: CollapsiblePagerViewController, viewControllerForPageAt index: Int) -> UIViewController
    func headerView(in pager: CollapsiblePagerViewController) -> UIView
}
```

### 7.3 Delegate

```swift
@MainActor
public protocol CollapsiblePagerDelegate: AnyObject {
    func pager(_ pager: CollapsiblePagerViewController, didSelectPageAt index: Int)
    func pager(_ pager: CollapsiblePagerViewController, didUpdateCollapseProgress progress: CGFloat)
    func pagerDidTriggerRefresh(_ pager: CollapsiblePagerViewController)
    func pager(_ pager: CollapsiblePagerViewController, didUpdateLayout context: CollapsiblePagerLayoutContext)
}
```

可以通过默认协议实现，让 delegate 方法变成可选能力。

### 7.4 Child Scroll Provider

```swift
@MainActor
public protocol CollapsiblePagerScrollProviding: AnyObject {
    var pagerScrollView: UIScrollView { get }
}
```

如果 child view controller 没有遵守该协议，pager 可以尝试查找第一个可见 scroll view，但更稳妥的方式是要求业务明确遵守协议。

### 7.5 Child Refresh Provider

```swift
@MainActor
public protocol CollapsiblePagerRefreshableChild: AnyObject {
    var pagerRefreshControl: UIRefreshControl? { get }
    func pagerDidTriggerRefresh()
}
```

Child 负责自己的数据刷新，pager 只负责手势仲裁和刷新触发时机。

## 8. 配置模型

### 8.1 根配置

```swift
public struct CollapsiblePagerConfiguration {
    public var header: CollapsiblePagerHeaderConfiguration
    public var tabBar: CollapsiblePagerTabBarConfiguration
    public var paging: CollapsiblePagerPagingConfiguration
    public var refreshMode: CollapsiblePagerRefreshMode
}
```

### 8.2 Header 配置

```swift
public struct CollapsiblePagerHeaderConfiguration {
    public var heightMode: CollapsiblePagerHeaderHeightMode
    public var allowsStretchOnPull: Bool
    public var stretchLimit: CGFloat?
}

public enum CollapsiblePagerHeaderHeightMode {
    case fixed(max: CGFloat, min: CGFloat)
    case automatic(min: CGFloat)
    case custom(@MainActor (UIView, CollapsiblePagerLayoutContext) -> CollapsiblePagerHeaderHeights)
}

public struct CollapsiblePagerHeaderHeights {
    public var maxHeight: CGFloat
    public var minHeight: CGFloat
}
```

### 8.3 Header 布局刷新配置

```swift
public enum CollapsiblePagerHeaderReloadBehavior {
    case immediate
    case animated(duration: TimeInterval)
}

public enum CollapsiblePagerHeaderOffsetPolicy {
    case preserveVisualPosition
    case preserveCollapseProgress
    case resetToExpanded
    case resetToCollapsed
}
```

默认建议使用 `.immediate` 和 `.preserveVisualPosition`。

### 8.4 TabBar 配置

```swift
public struct CollapsiblePagerTabBarConfiguration {
    public var height: CGFloat
    public var placement: CollapsiblePagerTabBarPlacement
    public var pinning: CollapsiblePagerTabBarPinning
    public var contentInsets: UIEdgeInsets
    public var backgroundColor: UIColor
    public var showsSeparator: Bool
    public var indicatorStyle: CollapsiblePagerTabIndicatorStyle
}

public enum CollapsiblePagerTabBarPlacement {
    case belowHeader
    case overlayHeaderBottom(offset: CGFloat)
    case insideHeaderBottom(inset: CGFloat)
    case fixedTop(offset: CGFloat)
    case custom(any CollapsiblePagerTabBarLayoutProviding)
}

public enum CollapsiblePagerTabBarPinning {
    case none
    case pinToSafeAreaTop(offset: CGFloat)
    case pinBelowNavigationBar(offset: CGFloat)
    case custom(@MainActor (CollapsiblePagerLayoutContext) -> CGFloat)
}
```

默认建议：

```swift
height = 48
placement = .belowHeader
pinning = .pinBelowNavigationBar(offset: 0)
```

### 8.5 指示器配置

```swift
public enum CollapsiblePagerTabIndicatorStyle {
    case none
    case underline(CollapsiblePagerUnderlineIndicatorConfiguration)
    case custom(any CollapsiblePagerTabIndicatorDisplayable)
}

public struct CollapsiblePagerUnderlineIndicatorConfiguration {
    public var color: UIColor
    public var height: CGFloat
    public var cornerRadius: CGFloat
    public var bottomInset: CGFloat
    public var widthMode: WidthMode
    public var animationDuration: TimeInterval

    public enum WidthMode {
        case fixed(CGFloat)
        case title
        case item
        case ratio(CGFloat)
    }
}
```

自定义指示器上下文：

```swift
@MainActor
public protocol CollapsiblePagerTabIndicatorDisplayable: AnyObject {
    var view: UIView { get }
    func update(with context: CollapsiblePagerTabIndicatorContext)
}

public struct CollapsiblePagerTabIndicatorContext {
    public let selectedIndex: Int
    public let fromIndex: Int
    public let toIndex: Int
    public let progress: CGFloat
    public let itemFrames: [CGRect]
    public let titleFrames: [CGRect]
    public let tabBarBounds: CGRect
    public let isInteractive: Bool
}
```

自定义 TabBar 位置 provider：

```swift
@MainActor
public protocol CollapsiblePagerTabBarLayoutProviding: AnyObject {
    func frameForTabBar(in context: CollapsiblePagerLayoutContext) -> CGRect
    func pinY(in context: CollapsiblePagerLayoutContext) -> CGFloat?
}
```

### 8.6 刷新配置

```swift
public enum CollapsiblePagerRefreshMode {
    case none
    case overall
    case child
    case custom(any CollapsiblePagerRefreshCoordinating)
}
```

第一版建议实现 `.none`、`.overall` 和 `.child`。`.custom` 可以作为协议稳定后的保留扩展点。

```swift
@MainActor
public protocol CollapsiblePagerRefreshCoordinating: AnyObject {
    func canBeginRefresh(context: CollapsiblePagerLayoutContext) -> Bool
    func beginRefresh(context: CollapsiblePagerLayoutContext)
    func endRefresh()
}
```

## 9. 内部架构

### 9.1 主要组件

- `CollapsiblePagerViewController`：公开容器，负责 child view controller 管理和 data source 编排。
- `CollapsiblePagerRootView`：根视图，承载 Header、TabBar 和 PageContainer。
- `CollapsiblePagerHeaderHostView`：包裹业务方提供的 Header，并负责高度测量。
- `CollapsiblePagerTabBar`：管理 Tab 按钮、选中态、指示器容器和 item 布局。
- `CollapsiblePagerPageContainer`：管理横向分页区域、child view controller 挂载和切页进度。
- `CollapsiblePagerScrollCoordinator`：管理纵向滚动手势和 offset 状态机。
- `CollapsiblePagerRefreshCoordinator`：管理刷新手势仲裁和刷新状态。
- `CollapsiblePagerLayoutEngine`：纯布局计算，负责 Header、Tab、吸顶和 child content inset。

### 9.2 状态模型

容器应维护明确状态，不要完全依赖任意 scroll offset 反推。

```swift
struct CollapsiblePagerState {
    var selectedIndex: Int
    var headerMaxHeight: CGFloat
    var headerMinHeight: CGFloat
    var headerVisibleHeight: CGFloat
    var collapseProgress: CGFloat
    var tabBarFrame: CGRect
    var pinThreshold: CGFloat
    var isDraggingVertically: Bool
    var isPagingHorizontally: Bool
    var activeRefreshOwner: RefreshOwner?
}
```

折叠进度：

```swift
progress = (headerMaxHeight - headerVisibleHeight) / (headerMaxHeight - headerMinHeight)
```

`progress` 必须限制在 `0...1`。

### 9.3 Layout Engine

Layout engine 接收配置、安全区、导航栏指标、Header 高度和容器尺寸，输出所有布局结果。

输出内容：

- Header frame。
- Header 可见高度。
- TabBar frame。
- Tab 吸顶 Y 值。
- PageContainer frame。
- Child scroll content inset。
- Child scroll content offset 修正值。

将这些计算隔离出来，可以在不启动模拟器的情况下做单元测试。

### 9.4 滚动协调

Scroll coordinator 负责纵向滚动归属。

规则：

- 向上滚动时，先折叠 Header 到最小高度。
- Header 已折叠后，当前 child scroll view 才消费继续向上的滚动。
- 向下滚动时，先让当前 child scroll view 回到顶部。
- Child 到顶部后，继续向下滚动才展开 Header。
- 只有 Header 完全展开并且当前 child 在顶部时，才允许触发刷新。
- 布局变化时，非当前 child 页面也要同步 top inset 和最小 offset。

Coordinator 必须避免递归 `contentOffset` 更新。内部主动修正 offset 时，需要标记状态，避免观察回调再次进入协调逻辑。

### 9.5 分页协调

Page container 负责横向移动。

规则：

- 只有点击切换完成或滑动提交后，selected index 才改变。
- 交互式滑动过程中，把 progress 发送给 TabBar 指示器。
- 滑动取消时，恢复原 selected index 和 indicator 状态。
- 连续点击 Tab 时，合并到最后一次目标 index。
- Child view controller 必须通过 UIKit containment API 添加和移除。

### 9.6 刷新协调

刷新状态只有一个 owner：

```swift
enum RefreshOwner {
    case pager
    case child(index: Int)
}
```

规则：

- `.overall` 模式下，由 pager 拥有刷新状态，并调用 `pagerDidTriggerRefresh`。
- `.child` 模式下，如果当前 child 遵守 `CollapsiblePagerRefreshableChild`，由当前 child 拥有刷新状态。
- Header 展开优先级高于刷新。
- 已经存在刷新时，忽略新的刷新触发。
- `endRefreshing()` 结束 pager 级刷新；child 刷新由 child 自己的 refresh control 或回调结束。

## 10. 行为矩阵

### 10.1 下拉刷新

| 状态 | 手势 | 结果 |
| --- | --- | --- |
| Header 已折叠 | 向下拉 | 先展开 Header |
| Header 半展开 | 向下拉 | 继续展开 Header |
| Header 完全展开，child 在顶部 | 超过刷新阈值 | 触发配置的刷新 owner |
| Header 完全展开，child 不在顶部 | 向下拉 | Child scroll view 先回到顶部 |
| 正在刷新 | 再次下拉 | 忽略或保持当前刷新状态 |
| child 模式下当前 child 不支持刷新 | 超过刷新阈值 | 不触发刷新 |

### 10.2 Header 布局刷新

| 当前状态 | Header 变化 | 默认结果 |
| --- | --- | --- |
| 展开态 | 高度变大 | Header 向下扩展，内容起点更新 |
| 展开态 | 高度变小 | Header 收缩，同时保持顶部视觉稳定 |
| 折叠态 | 高度变化 | Tab 保持吸顶，不强制展开 |
| 半折叠 | 高度变化 | 保持当前视觉位置 |
| 用户正在拖拽 | 高度变化 | 优先延迟应用或无动画应用 |
| 正在刷新 | 高度变化 | 允许布局更新，但不触发第二次刷新 |
| 正在横向切页 | 高度变化 | 应用全局布局，切换完成后同步目标 child |

### 10.3 Tab 指示器

| 事件 | 指示器结果 |
| --- | --- |
| 点击 Tab | 动画移动到目标 item |
| 交互式滑动页面 | 按滑动进度插值 frame |
| 滑动取消 | 回到来源 item |
| 快速连续点击 | 取消旧动画，移动到最新目标 |
| 重新加载 Tab | 重新计算 frame，并 clamp selected index |
| 自定义指示器 | 接收 context，自行渲染 |

### 10.4 TabBar 位置

| 位置 | 布局含义 | 说明 |
| --- | --- | --- |
| `belowHeader` | Header 后方占据高度 | 默认且最简单 |
| `overlayHeaderBottom` | 覆盖在 Header 底部 | 可能需要补偿 content inset |
| `insideHeaderBottom` | 作为 Header 内容 | Header 测量包含 Tab 区域 |
| `fixedTop` | 独立顶部位置 | 适合工具型页面 |
| `custom` | 业务方计算布局 | 高级扩展点 |

## 11. 测试策略

### 11.1 单元测试

优先测试纯布局和状态：

- Header 高度 clamp。
- 折叠进度计算。
- 各种 TabBar placement 的 frame。
- 安全区和导航栏吸顶模式下的 pin threshold。
- Child inset 计算。
- Header 高度变化时的 offset 保持策略。
- 刷新触发资格判断。
- Tab reload 后 selected index 的 clamp。

### 11.2 UIKit 集成测试

可行时增加聚焦型集成测试：

- Child view controller containment 生命周期。
- 通过显式协议发现当前 child scroll view。
- 点击 Tab 后更新 page container 和 indicator。
- `reloadHeaderLayout` 更新所有依赖布局值。

### 11.3 手动 QA 场景

后续通过 demo app 或 example target 验证：

- 向上滚动直到 Header 折叠且 Tab 吸顶。
- 向下滚动直到 Header 展开。
- `.overall` 模式下触发下拉刷新。
- `.child` 模式下触发下拉刷新。
- 不同 Tab 保存不同滚动位置。
- 已滚动状态下，将 Header 文本从短文本改成长文本。
- 旋转设备。
- 测试短内容和空内容 child 页面。
- 测试快速点击 Tab 和取消横向滑动。

## 12. 第一版实现范围

建议第一阶段：

- 公开 `CollapsiblePagerViewController`。
- Data source 和 delegate 协议。
- Fixed 和 automatic 两种 Header 高度模式。
- 默认等宽文本 TabBar。
- 默认下划线指示器。
- `belowHeader` 位置。
- 吸顶到导航栏下方或安全区顶部。
- 支持点击切换的横向分页。
- 显式 `CollapsiblePagerScrollProviding` child 协议。
- 刷新模式：`.none`、`.overall`、`.child`。
- `reloadHeaderLayout` 支持 immediate 行为和 preserve visual position 策略。
- 覆盖 layout 计算和刷新资格判断的单元测试。

建议第二阶段：

- `overlayHeaderBottom` 位置。
- 自定义 Tab 指示器。
- Child 懒加载。
- Header 布局刷新动画。
- 自定义 Header 高度 provider。
- 自定义 TabBar layout provider。

后续阶段：

- 更细的手势仲裁调优。
- 下拉时 Header 拉伸。
- 自定义 refresh coordinator。
- 更多 Tab item 样式、badge 和可滚动 Tab 模式。
- 复刻参考个人主页截图的 example app。

## 13. 待定设计决策

- 横向分页使用 `UICollectionView`、`UIScrollView` 还是 `UIPageViewController`。
- 是否提供自动 child scroll view 查找，还是强制显式协议。
- 默认 TabBar 是否在第一版支持可横向滚动 Tab。
- Header 下拉拉伸是否进入第一版，还是等核心折叠模型稳定后再加。
- Pager 级刷新是否通过配置选择性转发给当前 child。

## 14. 推荐默认值

```swift
CollapsiblePagerConfiguration(
    header: .init(
        heightMode: .fixed(max: 260, min: 0),
        allowsStretchOnPull: false,
        stretchLimit: nil
    ),
    tabBar: .init(
        height: 48,
        placement: .belowHeader,
        pinning: .pinBelowNavigationBar(offset: 0),
        contentInsets: .zero,
        backgroundColor: .systemBackground,
        showsSeparator: true,
        indicatorStyle: .underline(.init(
            color: .systemYellow,
            height: 3,
            cornerRadius: 1.5,
            bottomInset: 0,
            widthMode: .fixed(28),
            animationDuration: 0.25
        ))
    ),
    paging: .default,
    refreshMode: .none
)
```

## 15. 设计原则

组件负责布局、容器管理、手势和滚动协调。业务方负责业务数据、网络请求、Header 内容、child 内容和刷新工作。

这个边界能让 `CollapsiblePager` 保持可复用，同时支持个人主页、详情页、创作者主页，以及其他“可折叠 Header + Tab 内容”的界面。
