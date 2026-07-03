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
- 最低 Swift tools version：Swift 6.2。
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

## 3.1 参考源码阅读结论

本规格参考并阅读了两个开源项目的核心源码：

- [SPStore/NestedPageViewController](https://github.com/SPStore/NestedPageViewController)，阅读版本 `94cc01a`。重点参考其 `NestedPageScrollCoordinator`、`NestedPageHeaderManager`、`NestedPageContainerScrollView`、局部/整体刷新示例，以及全屏返回手势示例。
- [uias/Tabman](https://github.com/uias/Tabman)，阅读版本 `b666020`。重点参考其 `TabmanViewController`、`TMBar`、`TMBarView`、`TMBarButtonInteractionController`、`TMBarButtonStateController` 和 `TMBarViewUpdateHandler`。

对 `CollapsiblePager` 有直接价值的结论：

- 悬浮吸顶不能只靠当前 child scroll view 的 `contentOffset` 反推。需要一个内部 `pin anchor` 作为纵向状态锚点，用它同步 Header 位置和其他 child 的 offset。
- Header 与 TabBar 应作为一个可迁移的视觉宿主：普通滚动时挂在当前 child scroll view 的顶部 inset 区域；完全吸顶、横向切页、回弹或刷新动画冲突时挂到 pager 的 fixed overlay 容器。
- 下拉刷新必须有明确 owner。整体刷新和 child 刷新不能共用同一触发路径，也不能在同一个下拉手势里同时触发。
- 横向分页应输出连续 `position`，TabBar、Tab item selected progress 和 indicator 只消费这个 position，不反向拥有页面选择逻辑。
- Tab 点击和横向滑动是同一条状态链路的两个入口：点击产生 programmatic page request，横滑产生 interactive position update，最终都在页面完成或取消时提交 selected index。

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

- Header 内容可以由业务方提供 `UIView` 或 `UIViewController`。
- Header 有最大展开高度和最小折叠高度。
- 向上滚动时，优先折叠 Header，Header 折叠到最小高度后，当前 child scroll view 才继续滚动。
- 向下滚动时，优先让 child scroll view 回到顶部，再展开 Header。
- 下拉刷新之前，Header 必须先完全展开。
- Header 可以根据折叠进度更新自身视觉状态。
- Header 内容变化后，可以刷新 frame。
- Header 刷新必须重新计算 Tab 位置、吸顶阈值、child scroll inset 和当前 content offset。
- Header 布局更新默认保持当前视觉位置，避免页面突然跳动。

实现约束：

- 每个参与协调的 child scroll view 必须由 pager 统一设置顶部 inset，顶部 inset 至少覆盖 Header 最大高度与 TabBar 占位高度。
- Header/TabBar 视觉宿主不能固定死在根视图层级中。普通滚动时应表现为 child scroll view 内容的一部分；吸顶、横向切页、回弹和刷新冲突处理时可以迁移到 fixed overlay 容器。
- Header 为 controller 时，controller containment 在 pager 生命周期内保持稳定；Header 视觉宿主迁移时只迁移 `view`，不重复 add/remove child controller。
- 吸顶判断必须基于内部 `pin anchor` 和 layout engine 输出的 pin threshold，而不是只比较当前 `contentOffset.y`。
- 非当前 child 的 offset 同步应基于 `pin anchor` 的 delta，避免当前 scroll view 正在回弹、减速或被刷新控件动画修改时把错误 offset 传播到其他页面。
- Header 半吸顶或悬停状态需要明确策略。第一版默认按视觉位置保持，后续可以暴露“只在触摸 Header 时移动 Header”的高级选项。

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

实现约束：

- TabBar 只负责渲染和发出选择请求，不直接修改 child view controller 或纵向滚动状态。
- Tab 点击后，TabBar 通过 pager 发起 page request。最终 selected index 由 page container 在滚动完成、提交或取消后统一确认。
- Tab item 的 selected 表达要支持连续进度，例如从 `0...1` 的 partial selected 状态，以便横向滑动时做文字颜色、字重或 alpha 插值。
- TabBar 更新输入应是 page container 输出的 `PagePosition`，而不是散落的 `selectedIndex`、`fromIndex`、`progress` 多套入口。

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

指示器计算应参考 Tabman 的 focus rect 思路：由当前连续 page position 计算焦点矩形，再根据指示器宽度模式映射成最终 frame。这样默认下划线、自定义块状指示器和后续可滚动 TabBar 可以复用同一套 position 输入。

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

刷新仲裁约束：

- 刷新触发优先级低于 Header 展开。Header 未完全展开时，下拉手势只能用于展开 Header。
- `.overall` 模式由 pager 拥有刷新状态，视觉上可以使用 pager 管理的 refresh control 或挂在当前 child scroll view 上的刷新控件，但必须补偿顶部 inset，使刷新语义表现为“整个 pager 顶部刷新”。
- `.child` 模式由当前 child 拥有刷新状态。为了让局部刷新控件稳定显示，Header 不应在 child refresh reveal 阶段继续拉伸或跟随下拉。
- 刷新期间 Header 宿主应保持在稳定父视图中。若外部 refresh control 通过动画修改 `contentOffset`，scroll coordinator 必须避免 Header 在 child mount 和 fixed overlay 之间闪跳。
- 结束刷新时只结束当前 owner。pager 不主动结束 child 内部刷新控件，child 也不结束 pager 级刷新。

### 5.7 横向分页

组件应该支持 child 页面之间的横向滑动。

必备行为：

- 横向滑动时，Tab 选中进度和指示器连续更新。
- 点击 Tab 时，页面横向动画切换。
- 横向滑动取消时，Tab 和指示器回到原状态。
- 快速连续点击 Tab 时，最终停留在最后一次请求的目标页面。
- 正常使用中，纵向滚动手势和横向分页手势不能互相抢夺。

实现约束：

- 第一版横向分页采用内部 `UIScrollView` paging 容器。它更容易和 child scroll view、Header 挂载迁移、吸顶锚点和回弹状态协作。
- Page container 必须输出连续 `PagePosition`，包含 `rawPosition`、`fromIndex`、`toIndex`、`progress`、`direction`、`isInteractive` 和 `isCancelled`。
- 点击 Tab、调用 `selectPage` 和横向拖拽都进入同一套 page request pipeline。区别只是 source 为 `.tap`、`.api` 或 `.gesture`。
- 横向切页开始时，纵向 coordinator 应冻结当前 Header 视觉宿主到 fixed overlay，必要时终止当前 child 的非回弹减速，避免切页后 Header 与旧 child offset 脱钩。
- 如果横向切页发生在顶部回弹中，Header 需要沿用回弹中的视觉位置，切页结束后再根据目标 child 的 offset 恢复挂载关系。

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
public enum CollapsiblePagerHeaderContent {
    case view(UIView)
    case viewController(UIViewController)
}

@MainActor
public protocol CollapsiblePagerDataSource: AnyObject {
    func numberOfPages(in pager: CollapsiblePagerViewController) -> Int
    func pager(_ pager: CollapsiblePagerViewController, titleForPageAt index: Int) -> String
    func pager(_ pager: CollapsiblePagerViewController, viewControllerForPageAt index: Int) -> UIViewController
    func headerContent(in pager: CollapsiblePagerViewController) -> CollapsiblePagerHeaderContent
}
```

Header 可以由业务方提供 `UIView` 或 `UIViewController`。`headerContent(in:)` 在首次 `reloadData()` 和后续完整数据重载时调用；pager 会持有当前 Header content，`reloadHeaderLayout` 只重新测量当前 Header，不重新请求 data source。

当 Header 是 controller 时，pager 使用标准 UIKit containment 管理其生命周期：`addChild`、添加 `headerViewController.view`、`didMove(toParent:)`。Header 在 `HeaderMountView` 和 `FixedHeaderContainer` 之间迁移时，只移动 controller 的 `view`，不反复改变 controller containment。Header controller 的生命周期归 pager 管，不归任何 Tab child 管。

当 `reloadData()` 返回新的 Header content 时，pager 必须先释放旧 Header：如果旧内容是 controller，调用 `willMove(toParent: nil)`、移除 view、`removeFromParent()`；如果旧内容是 view，直接从父视图移除。业务方不应返回已经被其他 parent view controller 管理的 Header controller；如果检测到 `parent != nil && parent !== pager`，pager 应拒绝挂载并通过 assertion 或诊断日志暴露接入错误。

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

第一版要求参与纵向滚动协调的 child view controller 明确遵守该协议。自动查找第一个可见 scroll view 只作为后续可选能力，不进入第一版默认行为。

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
    case automatic(min: CGFloat, estimatedMax: CGFloat?)
    case custom(
        estimated: CollapsiblePagerHeaderHeights?,
        provider: @MainActor (CollapsiblePagerHeaderContent, CollapsiblePagerLayoutContext) -> CollapsiblePagerHeaderHeights
    )
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
}

public enum CollapsiblePagerHeaderOffsetPolicy {
    case preserveVisualPosition
    case preserveCollapseProgress
    case resetToExpanded
    case resetToCollapsed
}
```

默认建议使用 `.immediate` 和 `.preserveVisualPosition`。

高度模式语义：

- `fixed(max:min:)`：业务明确给出展开高度和折叠高度，最稳定。`reloadHeaderLayout` 只重新应用布局，不重新计算高度。
- `automatic(min:estimatedMax:)`：pager 使用 Auto Layout 测量 Header 展开高度，业务提供最小折叠高度；`estimatedMax` 用于图片、异步资料或多行文本稳定前的首屏占位，后续 `reloadHeaderLayout` 会重新测量真实高度。
- `custom(estimated:provider:)`：业务根据 Header content、容器宽度、安全区、TabBar 位置等上下文自行返回 `maxHeight/minHeight`；`estimated` 用于 provider 尚不能给出稳定结果前的首屏占位。

过渡方式语义：

- `immediate`：无动画立刻重新测量并应用布局。适合异步图片、文字变化、刷新回调、横竖屏和 Dynamic Type 变化。
- `animated(duration:curve:)`：第二阶段公开能力。Header 高度、TabBar frame、pin threshold、child inset 和 offset 修正一起动画。适合用户主动展开详情、收起简介等明确 UI 操作。第一版不暴露该 behavior，避免公开未实现的过渡能力。

如果刷新发生在拖拽、减速、横向切页或刷新动画中，内部调度器可以把本次 layout reload 合并为 dirty 标记，等 pager idle 后以 `.immediate` 应用。这个延迟调度是内部安全策略，第一版不作为公开 `HeaderReloadBehavior` case 暴露。

`offsetPolicy` 独立控制视觉位置：

- `.preserveVisualPosition`：默认策略，Header 变高或变矮时尽量保持用户当前看到的内容不跳。
- `.preserveCollapseProgress`：保持折叠百分比。
- `.resetToExpanded`：布局刷新后回到展开态。
- `.resetToCollapsed`：布局刷新后保持吸顶态。

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

### 8.7 分页与手势配置

```swift
public struct CollapsiblePagerPagingConfiguration {
    public var allowsSwipeToChangePage: Bool
    public var bouncesHorizontally: Bool
    public var tabTapAnimationDuration: TimeInterval
    public var gesturePolicy: CollapsiblePagerGesturePolicy
}

public struct CollapsiblePagerGesturePolicy {
    public var horizontalIntentThreshold: CGFloat
    public var verticalIntentThreshold: CGFloat
    public var givesNavigationPopGesturePriority: Bool
    public var disablesHorizontalPagingFromHeaderTouch: Bool
}
```

默认建议：

```swift
allowsSwipeToChangePage = true
bouncesHorizontally = false
tabTapAnimationDuration = 0.28
gesturePolicy = .init(
    horizontalIntentThreshold: 8,
    verticalIntentThreshold: 8,
    givesNavigationPopGesturePriority: true,
    disablesHorizontalPagingFromHeaderTouch: true
)
```

手势配置只决定 page container 的横向意图和系统返回手势优先级，不改变刷新 owner、Header 折叠规则或 child 自己的业务手势。

## 9. 内部架构

### 9.1 主要组件

- `CollapsiblePagerViewController`：公开容器，负责 child view controller 管理和 data source 编排。
- `CollapsiblePagerRootView`：根视图，承载 Header、TabBar 和 PageContainer。
- `CollapsiblePagerHeaderHostView`：包裹业务方提供的 Header，并负责高度测量。
- `CollapsiblePagerHeaderMountView`：每个 child scroll view 内部的 Header 占位挂载点，位于顶部 inset 对应的负坐标区域。
- `CollapsiblePagerFixedHeaderContainer`：吸顶、横向切页、回弹和刷新冲突期间的 fixed overlay 容器。
- `CollapsiblePagerPinAnchor`：内部不可见锚点或值对象，记录 Header/Tab 当前纵向位置并驱动非当前 child offset 同步。
- `CollapsiblePagerTabBar`：管理 Tab 按钮、选中态、指示器容器和 item 布局。
- `CollapsiblePagerTabSelectionController`：把 Tab 点击、API 选择和 page position 统一成 selected/pending/partial selected 状态。
- `CollapsiblePagerPageContainer`：管理横向分页区域、child view controller 挂载和切页进度。
- `CollapsiblePagerScrollCoordinator`：管理纵向滚动手势和 offset 状态机。
- `CollapsiblePagerRefreshCoordinator`：管理刷新手势仲裁和刷新状态。
- `CollapsiblePagerGestureArbiter`：集中处理横向分页、纵向滚动、Header 命中区域和导航返回手势的优先级。
- `CollapsiblePagerLayoutEngine`：纯布局计算，负责 Header、Tab、吸顶和 child content inset。

### 9.2 状态模型

容器应维护明确状态，不要完全依赖任意 scroll offset 反推。

```swift
struct CollapsiblePagerState {
    var selectedIndex: Int
    var pendingSelectedIndex: Int?
    var headerMaxHeight: CGFloat
    var headerMinHeight: CGFloat
    var headerVisibleHeight: CGFloat
    var collapseProgress: CGFloat
    var tabBarFrame: CGRect
    var pinThreshold: CGFloat
    var pinAnchorY: CGFloat
    var headerMountOwner: HeaderMountOwner
    var verticalPhase: VerticalPhase
    var pagePosition: PagePosition
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

辅助状态：

```swift
enum HeaderMountOwner {
    case child(index: Int)
    case fixedOverlay(reason: FixedOverlayReason)
}

enum FixedOverlayReason {
    case pinned
    case horizontalPaging
    case verticalDecelerating
    case topBouncing
    case refreshRevealing
    case layoutReloading
}

enum VerticalPhase {
    case expanded
    case collapsing
    case partiallyPinned
    case pinned
    case expanding
    case topBouncing
    case refreshing
}

struct PagePosition {
    var rawPosition: CGFloat
    var fromIndex: Int
    var toIndex: Int
    var progress: CGFloat
    var direction: PageDirection
    var isInteractive: Bool
    var isCancelled: Bool
}

enum PageDirection {
    case forward
    case reverse
    case none
}
```

### 9.3 Header 挂载与 pin anchor

内部实现采用“每个 child 有自己的 Header mount，占用顶部 inset；真实 Header/Tab 视觉宿主只有一份，并在 mount 与 fixed overlay 之间迁移”的模型。

层级模型：

```text
CollapsiblePagerRootView
├── PageContainerScrollView
│   └── ChildViewController[index].view
│       └── pagerScrollView
│           └── HeaderMountView[index]      // y = -managedTopInset
├── FixedHeaderContainer                    // fixed overlay
│   └── HeaderHostView + TabBarSurface      // 需要固定时迁移到这里
└── PinAnchor                               // 不可见锚点或内部 frame 值
```

挂载规则：

- 普通展开、折叠和未吸顶状态下，Header 宿主挂在当前 child 的 `HeaderMountView`，让用户感知它是当前滚动内容的一部分。
- 完全吸顶时，Header 宿主挂到 `FixedHeaderContainer`，只保留 TabBar 或最小 Header 可见区域。
- 横向切页期间，Header 宿主挂到 `FixedHeaderContainer`，直到 page container 完成、取消或稳定在目标页。
- 当前 child 正在非回弹减速且即将切页时，可以终止该 child 的减速，避免 Header 宿主与旧 child offset 脱钩。
- 当前 child 正在顶部回弹时切页，Header 宿主继续使用回弹中的视觉 Y 值，切页结束后用 `pinAnchorY` 校准目标 child。
- 刷新控件或布局刷新通过动画修改 `contentOffset` 时，Header 宿主可以临时保持在 fixed overlay，动画结束后再恢复到当前 child mount。

`pinAnchorY` 是纵向状态的单一参考点：

- Header visible height、TabBar 吸顶状态和 collapse progress 都从 `pinAnchorY` 与 layout engine 的阈值计算。
- 非当前 child 的 `contentOffset.y` 同步只使用 `pinAnchorY` 的 delta。
- 当当前 child 顶部回弹或 Header 完全吸顶时，`pinAnchorY` 可以保持不变，从而避免把回弹位移传播到其他 child。
- Header 高度变化时，先通过 layout engine 计算新的 pin threshold，再用 offset policy 生成新的 `pinAnchorY` 和每个 loaded child 的 offset 修正。

### 9.4 Layout Engine

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

### 9.5 滚动协调

Scroll coordinator 负责纵向滚动归属。

规则：

- 向上滚动时，先折叠 Header 到最小高度。
- Header 已折叠后，当前 child scroll view 才消费继续向上的滚动。
- 向下滚动时，先让当前 child scroll view 回到顶部。
- Child 到顶部后，继续向下滚动才展开 Header。
- 只有 Header 完全展开并且当前 child 在顶部时，才允许触发刷新。
- 布局变化时，非当前 child 页面也要同步 top inset 和最小 offset。
- 当前 scroll event 必须来自 current child 的 `pagerScrollView`，横向切页期间忽略纵向 KVO/observer 回调。
- 由组件主动设置 `contentOffset` 时必须进入 guarded update，防止递归触发状态机。
- 当 `pinAnchorY` 没有变化时，不同步非当前 child 的 offset，尤其是顶部回弹、完全吸顶和刷新 reveal 阶段。
- 如果业务选择保留每个 child 的滚动位置，非当前 child 只在全局 layout/inset 变化时修正；如果选择不保留，非当前 child 在非吸顶状态跟随 `pinAnchorY` 回到统一视觉位置。

Coordinator 必须避免递归 `contentOffset` 更新。内部主动修正 offset 时，需要标记状态，避免观察回调再次进入协调逻辑。

### 9.6 分页协调

Page container 负责横向移动。

规则：

- 只有点击切换完成或滑动提交后，selected index 才改变。
- 交互式滑动过程中，把 progress 发送给 TabBar 指示器。
- 滑动取消时，恢复原 selected index 和 indicator 状态。
- 连续点击 Tab 时，合并到最后一次目标 index。
- Child view controller 必须通过 UIKit containment API 添加和移除。
- Page container 应持续输出 `PagePosition`。TabBar、indicator 和 selected progress 只订阅该 position。
- 点击 Tab 只产生 page request，不直接提交 `selectedIndex`。`selectedIndex` 在滚动完成后提交；取消时回到来源 index。
- Programmatic scroll 期间可以维护 `pendingSelectedIndex`，用于 Tab item 即时反馈和连续点击合并。
- 滚动完成检查应允许极小浮点误差，避免 contentOffset 接近目标页但未精确相等时状态无法提交。

### 9.7 刷新协调

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
- `.overall` 模式下，刷新控件的视觉位置需要补偿 managed top inset，使用户理解它刷新的是整个 pager，而不是某个列表局部。
- `.child` 模式下，刷新控件保持在 child scroll view 的内容顶部。Header 展开完成后，继续下拉才让 child refresh control reveal。
- 刷新 reveal 和 end-refresh 动画期间，Scroll coordinator 需要识别外部动画导致的 `contentOffset` 变化，必要时将 Header 宿主临时固定，防止闪跳。
- 如果当前 child 不支持 child 刷新，`.child` 模式不降级触发 `.overall`。

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

### 10.5 横向切页与纵向状态

| 当前纵向状态 | 横向切页触发 | Header 宿主策略 | 完成后处理 |
| --- | --- | --- | --- |
| 展开或正常折叠 | 点击 Tab | 迁移到 fixed overlay，按当前 `pinAnchorY` 保持视觉位置 | 提交目标页，恢复到目标 child mount |
| 完全吸顶 | 点击 Tab 或横向滑动 | 保持 fixed overlay | 提交目标页，保持吸顶 |
| 顶部回弹 | 横向滑动 | fixed overlay 跟随回弹视觉 Y 值 | 校准旧 child 回弹 offset，按目标 child 恢复 |
| 纵向非回弹减速 | 横向滑动 | 必要时终止旧 child 减速，避免脱钩 | 用 `pinAnchorY` 同步目标 child |
| 局部刷新 reveal | 横向滑动 | 可禁止横向切页，或固定 Header 并延迟提交 | 第一版建议禁止横向切页 |
| Header 布局刷新中 | 点击 Tab | 合并 layout update 和 page request | 布局稳定后提交最终目标 |

### 10.6 手势优先级

| 手势组合 | 优先级策略 |
| --- | --- |
| Header 区域横向拖拽 vs 页面横向分页 | 默认不从 Header 区域启动横向分页，避免误触切页 |
| Tab item 点击 vs 页面横向拖拽 | 点击发起 programmatic request；如果正在 interactive drag，先取消或等待系统 settle |
| 页面横向分页 vs child 纵向滚动 | 基于初始位移和速度判断方向，横向意图成立后冻结纵向 coordinator |
| 系统返回手势 vs 页面横向分页 | 导航返回手势优先，特别是第一页右滑返回 |
| 下拉刷新 vs Header 展开 | Header 展开优先，Header 完全展开后才进入刷新判断 |

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
- `pinAnchorY` delta 同步非当前 child offset。
- 顶部回弹时 `pinAnchorY` 不传播回弹位移。
- `PagePosition` 从 raw content offset 生成 `fromIndex`、`toIndex`、`progress` 和 direction。
- Tab indicator focus rect 在固定宽度、标题宽度和 item 宽度模式下的 frame 计算。

### 11.2 UIKit 集成测试

可行时增加聚焦型集成测试：

- Child view controller containment 生命周期。
- 通过显式协议发现当前 child scroll view。
- 点击 Tab 后更新 page container 和 indicator。
- `reloadHeaderLayout` 更新所有依赖布局值。
- 横向切页期间 Header 宿主迁移到 fixed overlay，并在完成后恢复正确 mount。
- child 顶部回弹时切页，不出现 Header 与列表顶部脱钩。
- `.overall` 和 `.child` 刷新 owner 互斥。
- 导航返回手势优先于第一页的横向分页。

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
- 测试顶部回弹过程中立即横向切页。
- 测试纵向减速未结束时点击或滑动切 Tab。
- 测试局部刷新 reveal/结束动画期间 Header 不闪跳。
- 测试第一页右滑返回和横向分页的手势优先级。

## 12. 第一版实现范围

建议第一阶段：

- 公开 `CollapsiblePagerViewController`。
- Data source 和 delegate 协议。
- Header content 支持 `UIView` 和 `UIViewController`。
- Fixed 和 automatic 两种 Header 高度模式，automatic 支持首屏估算高度。
- 默认等宽文本 TabBar。
- 默认下划线指示器。
- `belowHeader` 位置。
- 吸顶到导航栏下方或安全区顶部。
- 内部 `UIScrollView` page container，支持点击 Tab 切换和横向滑动切换。
- `pin anchor`、Header mount/fixed overlay 迁移和非当前 child offset 同步。
- 显式 `CollapsiblePagerScrollProviding` child 协议。
- 刷新模式：`.none`、`.overall`、`.child`。
- `.overall` 与 `.child` 刷新 owner 互斥，以及 Header 展开优先于刷新。
- `reloadHeaderLayout` 支持 immediate 行为、内部 idle 合并调度和 preserve visual position 策略。
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

## 13. 已决策与待定设计决策

已决策：

- 第一版横向分页使用内部 `UIScrollView` paging 容器，不使用 `UIPageViewController`，也不依赖第三方 pager 库。
- 第一版要求 child 通过 `CollapsiblePagerScrollProviding` 显式提供主滚动视图，不默认自动查找。
- 第一版默认 TabBar 使用等宽文本 Tab，不支持可横向滚动 Tab。可滚动 Tab 放到后续阶段。
- 第一版不实现 Header 下拉拉伸，先保证 Header 展开、吸顶、刷新仲裁和横向切页稳定。
- 第一版不公开 `deferredUntilIdle` 过渡；拖拽、减速、切页、刷新中的布局请求由内部 idle 合并调度处理。
- Pager 级刷新不默认转发给所有 child。业务方如果需要联动刷新，由 pager delegate 或业务层自行编排。

仍待定：

- Header 半吸顶悬停状态是否需要公开“只在触摸 Header 时移动 Header”的配置。
- 横向切页发生在局部刷新 reveal 中时，第一版是直接禁止切页，还是允许延迟提交。
- 自定义 refresh coordinator 的协议是否在第一版公开，还是先保留为内部设计。

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
    paging: .init(
        allowsSwipeToChangePage: true,
        bouncesHorizontally: false,
        tabTapAnimationDuration: 0.28,
        gesturePolicy: .init(
            horizontalIntentThreshold: 8,
            verticalIntentThreshold: 8,
            givesNavigationPopGesturePriority: true,
            disablesHorizontalPagingFromHeaderTouch: true
        )
    ),
    refreshMode: .none
)
```

## 15. 设计原则

组件负责布局、容器管理、手势和滚动协调。业务方负责业务数据、网络请求、Header 内容、child 内容和刷新工作。

这个边界能让 `CollapsiblePager` 保持可复用，同时支持个人主页、详情页、创作者主页，以及其他“可折叠 Header + Tab 内容”的界面。
