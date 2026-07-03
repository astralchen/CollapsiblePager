# AGENTS.md

本文件为自动化编码代理在本仓库工作的工程约定。适用范围为仓库根目录及全部子目录。

## Project Overview

- 工程名：`CollapsiblePager`。
- 定位：通用 UIKit 容器组件，用于构建“可折叠 Header + TabBar + 多 child 页面”的界面。
- 当前形态：Swift Package 为核心库，`Examples/` 为示例 iOS App 工程。
- 最低系统版本：iOS 13。
- Swift：`swift-tools-version: 6.2`，`swiftLanguageModes: [.v6]`。
- 核心包不依赖第三方 pager 库；第一版以 UIKit、UIScrollView 和标准 view controller containment 为基础。
- 组件必须保持业务无关：个人主页、详情页、创作者主页等只是使用场景，不能把头像、背景图、用户资料、作品列表等业务 UI 写死进核心包。

## Communication

- 默认使用中文回答。
- 代码解释、架构分析、审查意见和提交说明优先使用中文。
- 新增代码注释应简短、有实际解释价值；不要为显而易见的语句写注释。

## Repository Layout

- `Package.swift`: Swift Package 定义，声明核心库 target 和 Swift Testing 单元测试 target。
- `Sources/CollapsiblePager/`: 核心库源码。
- `Tests/CollapsiblePagerTests/`: 核心库单元测试，使用 Swift Testing。
- `Examples/Examples.xcodeproj`: 示例 App Xcode 工程。
- `Examples/Examples/`: 示例 App 源码和资源。
- `Examples/ExamplesTests/`: 示例 App 单元测试，使用 Swift Testing。
- `Examples/ExamplesUITests/`: 示例 App UI 测试，使用 XCTest。
- `docs/requirements-and-architecture.md`: 需求、公开 API、内部架构和第一版范围的主文档。
- `docs/ui-design-and-animation-dsl.md`: 默认 UI、动画交互和验收 DSL 文档。
- `docs/superpowers/plans/2026-07-03-collapsible-pager-v1.md`: V1 重写实施计划；当前源码按该计划从干净占位模块重建。
- `docs/assets/`: 文档效果图资源。

## Source Of Truth

- 架构和 API 设计以 `docs/requirements-and-architecture.md` 为第一优先级。
- UI、动画、手势交互和验收语义以 `docs/ui-design-and-animation-dsl.md` 为第一优先级。
- 具体实现顺序以 `docs/superpowers/plans/2026-07-03-collapsible-pager-v1.md` 为第一优先级。
- 如果代码与文档冲突，先确认用户意图；除非用户明确要求，否则优先让代码回到文档描述的第一版范围。
- 不要把后续阶段能力提前塞进第一版实现。后续阶段包括但不限于可横向滚动 TabBar、自定义指示器、Header 下拉拉伸、Header 布局刷新动画、自定义 Header 高度 provider、自定义 TabBar layout provider。

## Architecture References

- Nested scrolling、悬浮吸顶、Header 挂载迁移、整体/局部刷新 handoff、下拉刷新边界和手势冲突处理参考 [SPStore/NestedPageViewController](https://github.com/SPStore/NestedPageViewController)，已阅读版本 `94cc01a`。
- Tab 点击切换、横向滑动切页、Tab selected progress、indicator focus rect 和状态提交链路参考 [uias/Tabman](https://github.com/uias/Tabman)，已阅读版本 `b666020`。
- 两个参考库侧重点不同：NestedPageViewController 只作为纵向嵌套滚动和 Header/刷新/手势边界参考；Tabman 只作为横向分页、Tab 渲染和状态提交链路参考。
- 参考项目只提供架构启发，不作为运行时依赖；不要直接复制第三方 public API、命名或内部结构。
- 真正落地到本项目的设计结论必须写回 `docs/requirements-and-architecture.md` 和 `docs/ui-design-and-animation-dsl.md`，并保持第一版范围一致。

## Architecture Rules

- `CollapsiblePagerViewController` 是公开容器，负责编排 data source、delegate、child view controller 和内部协调器。
- 核心组件只负责布局、容器管理、TabBar、分页、手势、滚动协调和刷新 handoff；业务方负责 Header 内容、child 内容、业务数据、刷新控件、刷新任务和结束时机。
- Header content 必须支持 `UIView` 和 `UIViewController`。当 Header 是 controller 时，使用标准 UIKit containment；Header 视觉宿主迁移时只移动 controller 的 `view`，不反复 add/remove child controller。
- 第一版 child 主滚动视图必须通过 `CollapsiblePagerScrollProviding` 显式提供；不要默认自动查找第一个 scroll view。
- 纵向滚动协调必须基于内部 `PinAnchor` 和 layout engine 输出的阈值，不要只靠当前 child 的 `contentOffset.y` 反推全局状态。
- Header/TabBar 视觉宿主应能在当前 child 的 `HeaderMountView` 和 fixed overlay 之间迁移，用于吸顶、横向切页、回弹、刷新 reveal 和布局刷新冲突处理。
- TabBar 只负责渲染和发出选择请求，不直接修改 child 或纵向滚动状态。
- 点击 Tab、API 选择和横向拖拽必须进入同一套 page request pipeline；最终 selected index 由 page container 完成或取消后统一提交。
- 对外 `selectedIndex` 默认等于 `0`；当 `pageCount == 0` 时，内部 `effectiveSelectedIndex` 为 `nil`，不加载 child，不渲染 Tab item，不显示 indicator，选择请求为 no-op。
- 横向分页状态以 `PagePosition` 为唯一输入；Tab selected progress、indicator frame 和后续可横向滚动 TabBar 的 focus rect 都从 `PagePosition` 推导。
- 横向分页第一版使用内部 `UIScrollView` paging 容器，不使用 `UIPageViewController`，也不引入第三方分页库。
- 刷新必须有唯一 handoff 目标。`.overall` 与 `.child` 不得在同一次下拉手势中同时移交；Header 展开优先级高于刷新。
- 核心包不得要求 `UIRefreshControl`，不得新增专门的刷新 child 协议，也不得通过 delegate 转发刷新事件；外部刷新机制自行决定是否开始和何时结束。
- `reloadHeaderLayout` 第一版只公开 immediate 行为，并保持视觉位置；拖拽、减速、横向切页或刷新动画中的布局请求由内部 idle 合并调度处理，不公开延迟布局行为作为 API。

## Swift Safe Concurrency And UIKit Guidelines

- 新代码必须符合 Swift 6 安全并发模型；并发警告、actor 隔离警告和潜在 data race 警告都要当作设计问题处理。
- UI 类型、UIKit 回调、公开容器 API 和状态更新保持在 `@MainActor`。
- 公开的 data source、delegate、configuration builder 和 UIKit 入口优先标注 `@MainActor`，避免业务方从后台线程驱动 UIKit 状态。
- `UIView`、`UIViewController`、`UIScrollView`、`UIGestureRecognizer`、`UIRefreshControl` 等 UIKit 对象不得跨 actor 或后台任务传递；后台任务只接收快照值、标识符或不可变配置。
- 跨任务、跨 actor 或异步边界传递的数据优先使用不可变值类型，并按需要显式满足 `Sendable`。
- 存储并跨并发边界调用的闭包必须按语义标注 `@Sendable` 或 `@MainActor`；不要让闭包隐式捕获非线程安全 UIKit 对象。
- 共享可变状态必须有明确隔离：UI 协调器和滚动状态归 `@MainActor`，非 UI 的异步工作使用 `actor` 或不可变数据流，不用全局可变单例绕过隔离。
- 避免使用 `Task.detached`。如确实需要脱离当前 actor，必须只传入 `Sendable` 值，并在回到 UI 前显式切回 `MainActor`。
- 生命周期相关任务要可取消；view controller、coordinator、observer 和 KVO/token 持有的 `Task` 应在 `deinit` 或生命周期结束时取消。
- 避免使用 `@unchecked Sendable`、`nonisolated(unsafe)`、`@preconcurrency` 来压制编译器。确需使用时，必须在代码附近说明线程安全依据和替代方案为什么不可行。
- 新增 public API 要小而稳定，优先用配置结构体、协议和明确的枚举表达行为。
- 避免用业务命名污染核心库；示例 App 可以出现个人主页等演示内容，核心 target 不应出现业务场景专属类型。
- Layout engine 尽量保持纯计算，输入配置、尺寸、安全区、Header 高度，输出 frame、inset、阈值和 offset 修正，方便单元测试。
- 主动设置 `contentOffset` 时必须有 guarded update，避免递归触发 scroll coordinator。
- 修改 `contentInset`、`adjustedContentInset` 相关逻辑时，要同时考虑短内容、空内容、刷新阈值、导航栏安全区和横竖屏变化。
- 支持 iOS 13；使用更高版本 API 时必须加 `#available` 和合理降级。

## Code Comment Style

- 注释风格参照 iOS SDK：简洁、客观、以 API 行为和调用契约为中心，不写实现流水账。
- 注释默认使用中文；公开 API 的符号名、参数名、类型名和 Swift/UIKit 术语保持英文。
- public/open 类型、协议、枚举、配置项和非显而易见的 public 方法应使用 Swift DocC 风格 `///` 文档注释。第一句写一句话摘要，后续只在必要时补充 discussion、调用时机、线程/actor 要求和重要边界。
- 参数、返回值、错误和注意事项采用 DocC/iOS SDK 常见结构，例如 `- Parameters:`、`- Returns:`、`- Throws:`、`- Note:`、`- Warning:`；没有实际信息时不要为了格式凑小节。
- API 注释应描述“调用者可以依赖什么”和“调用者需要保证什么”，例如是否必须在 `MainActor` 调用、是否会触发布局重算、是否保持视觉位置、是否会回调 delegate。
- internal/private 注释只解释“为什么”和“不变量”，不要复述“这行代码做了什么”。
- 滚动状态机、Header mount/fixed overlay 迁移、`PinAnchor`、offset 修正、刷新 handoff、手势仲裁和并发隔离点必须在关键类型或关键分支附近写明设计意图。
- 对安全并发相关代码，注释应说明 actor 隔离、`Sendable` 依据、任务取消语义或为什么必须回到 `MainActor`。
- `TODO`、`FIXME` 必须带原因、后续动作或阶段归属；不要留下没有 owner 和上下文的占位注释。
- 示例 App 可以写面向阅读的演示注释；核心库注释要保持组件化语气，避免出现个人主页等业务专属解释。
- 不要提交大段废弃代码注释、调试日志注释或纯分隔线注释。

## Testing

- 核心逻辑优先写 Swift Testing 单元测试，位置在 `Tests/CollapsiblePagerTests/`。
- Layout engine、Header 高度 clamp、TabBar frame、pin threshold、offset policy、刷新资格、selected index/effective selected index 兜底、PagePosition 和 indicator focus rect 都应可单测。
- UIKit 生命周期、controller containment、Header mount/fixed overlay 迁移、刷新 handoff 互斥和导航返回手势优先级应通过集成测试或示例工程手动 QA 覆盖。
- 改动示例 App 用户流程时，按需要更新 `Examples/ExamplesTests/` 或 `Examples/ExamplesUITests/`。
- 文档或架构调整至少运行 `git diff --check`，并用 `rg` 扫描旧 API 名称或已废弃设计是否残留。

## Common Commands

Swift Package:

```sh
xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=<Simulator Name>' test
```

核心包依赖 UIKit，是 iOS-only Swift Package。`swift build` / `swift test` 可能按 macOS 目标编译并找不到 UIKit；实现和验证优先使用 iOS Simulator 的 `xcodebuild` 命令。

Examples 工程:

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' build
```

如需运行示例 UI 测试，先查询本机可用模拟器：

```sh
xcrun simctl list devices available
```

然后选择可用设备运行：

```sh
xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'platform=iOS Simulator,name=<Simulator Name>' test
```

## Documentation Workflow

- 修改公开 API、第一版范围、状态机、手势仲裁、刷新语义或 Header 高度策略时，同步更新 `docs/requirements-and-architecture.md`。
- 修改默认视觉、动画、交互验收或 DSL 表达时，同步更新 `docs/ui-design-and-animation-dsl.md`。
- 文档中的第一版范围、后续阶段和待定设计决策必须保持一致；不要一处写第一版支持，另一处写后续再做。
- 参考外部项目时，记录项目名、链接、阅读版本或 commit，以及本项目真正采用的设计结论。

## Git Commit Requirements

- 只有在用户明确要求提交、推送或创建 PR 时，才执行 `git add`、`git commit`、`git push` 或 PR 操作。
- 提交前必须重新检查 `git status --short` 和待提交 diff，确认只包含本次任务相关文件。
- 不要 stage 或提交用户已有的无关修改；如果相关文件里混有用户改动，先阅读并保留它们，只提交本次任务需要的最小范围。
- 提交前必须运行与改动范围匹配的验证：
  - 文档类改动至少运行 `git diff --check`，并按需要用 `rg` 扫描旧术语、旧 API 或互相矛盾的描述。
  - Swift Package 行为改动优先运行 `xcodebuild -scheme CollapsiblePager -destination 'platform=iOS Simulator,name=<Simulator Name>' test`，并确认没有新增 Swift 6 安全并发警告。
  - 示例 App 或 UIKit 集成改动按需要运行 `xcodebuild -project Examples/Examples.xcodeproj -scheme Examples -destination 'generic/platform=iOS Simulator' build`。
- Commit message 优先使用 Conventional Commits 风格，允许中文摘要，例如 `docs: 补充架构设计与代理协作规则`、`feat: 实现 Header 高度测量`、`fix: 修正刷新手势仲裁`。
- 单个提交应聚焦一个意图。不要把无关格式化、文档整理、功能实现和测试修复混在一个提交里。
- 如果验证无法运行或失败，不要伪装为通过；在提交说明或最终回复中明确原因、失败命令和剩余风险。
- 推送前确认当前分支和远端目标，禁止 force push，除非用户明确要求并理解风险。

## Agent Workflow

- 开始改动前先检查 `git status --short`，不要覆盖用户未提交修改。
- 搜索文件和文本优先使用 `rg` / `rg --files`。
- 先阅读相邻实现、测试和文档，再按现有模式改动。
- 代码改动应保持小步、聚焦，不做无关重构，不重排 Xcode 工程文件无关 section。
- 行为改动优先补测试；无法补测试时，在最终说明中写清剩余风险。
- 完成后运行与改动范围匹配的最小验证；如果无法运行，说明原因。
- 不要执行破坏性 git 命令，不要回滚非本人改动，除非用户明确要求。
