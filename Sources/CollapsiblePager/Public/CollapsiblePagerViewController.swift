import UIKit

/// 可折叠 Header、TabBar 与多 child 页面的 UIKit 容器。
///
/// V1 容器 API 均在 `MainActor` 上使用。`selectedIndex` 保持 UIKit 常见默认值语义，
/// 即使当前没有页面也为 `0`；是否存在有效页面选择请读取 `effectiveSelectedIndex`。
/// 业务子类可以 override UIKit 生命周期入口；override 时必须调用 `super`，以保持内部布局、
/// child containment 和 appearance transition 状态一致。
@MainActor
open class CollapsiblePagerViewController: UIViewController {
    /// 内容数据源。
    public weak var dataSource: CollapsiblePagerViewControllerDataSource?

    /// 状态变化 delegate。
    public weak var delegate: CollapsiblePagerViewControllerDelegate?

    /// 容器配置。
    public var configuration: CollapsiblePagerConfiguration {
        didSet {
            guard isViewLoaded else {
                return
            }

            let previousHeader = oldValue.header
            let previousRefreshHandoffMode = oldValue.refreshHandoffMode
            refreshHandoffCoordinator.mode = configuration.refreshHandoffMode
            if previousRefreshHandoffMode != configuration.refreshHandoffMode {
                refreshHandoffCoordinator.resetGesture()
                containerRefreshProxyOverscrollOffsetY = 0
                containerRefreshHostRejectedChildGestureIndex = nil
                isRoutingContainerHostUpwardPanToChild = false
                containerRefreshHostScrollViewStorage.resetOffsetIfIdle()
            }
            tabBarView.apply(configuration: configuration.tabBar)
            pageContainer.apply(paging: configuration.paging)
            if previousHeader != configuration.header {
                reloadHeaderLayout(offsetPolicy: .preserveVisualPosition)
            } else {
                applyLayout()
                updateHeaderHostPlacement(reason: .currentChild)
            }
        }
    }

    /// 对外默认选择索引。没有页面时仍为 `0`。
    public private(set) var selectedIndex: Int = 0

    /// 当前是否存在有效页面选择。没有页面时为 `nil`。
    public private(set) var effectiveSelectedIndex: Int?

    /// `.container` 刷新 handoff 模式使用的容器级外层纵向刷新宿主。
    ///
    /// 容器只拥有这个 `UIScrollView` 的布局、手势资格和刷新 handoff 边界。调用方可以按业务需要
    /// 在它上面安装自己的刷新机制；刷新任务和结束时机仍由调用方负责。
    public var containerRefreshHostScrollView: UIScrollView {
        loadViewIfNeeded()
        return containerRefreshHostScrollViewStorage
    }

    private let layoutEngine = CollapsiblePagerLayoutEngine()
    private let gestureArbiter = GestureArbiter()
    private var refreshHandoffCoordinator: RefreshHandoffCoordinator
    private let headerPullDownGateGesture = CollapsiblePagerHeaderPullDownGateGestureRecognizer()
    private let pageRequestPipeline = PageRequestPipeline()
    private let containerRefreshHostScrollViewStorage = CollapsiblePagerContainerRefreshHostScrollView()
    private let pageContainer = CollapsiblePagerPageContainer()
    private let pinnedSurfaceView = CollapsiblePagerPinnedSurfaceView()
    private let fixedHeaderContainer = CollapsiblePagerFixedHeaderContainer()
    private let tabBarView = CollapsiblePagerTabBarView()
    private lazy var childStore = CollapsiblePagerChildStore(owner: self)
    private lazy var headerHostCoordinator = CollapsiblePagerHeaderHostCoordinator(owner: self)
    private lazy var verticalScrollCoordinator = CollapsiblePagerVerticalScrollCoordinator(
        pinAnchorY: state.pinAnchorY,
        pinThreshold: currentLayoutOutput?.pinThreshold ?? headerHeights().normalized.collapseRange,
        managedTopInset: managedTopInsetForChildren()
    )

    private var state = CollapsiblePagerState.initial(pageCount: 0)
    private var loadedChildRecords: [Int: CollapsiblePagerChildRecord] = [:]
    private var preservedContentOffsetYByIndex: [Int: CGFloat] = [:]
    private var scrollObservations: [Int: CollapsiblePagerScrollObservation] = [:]
    private var currentLayoutOutput: CollapsiblePagerLayoutOutput?
    private var appliedHeaderHeights: CollapsiblePagerHeaderHeights?
    private var visitedPageIndexes: Set<Int> = []
    private var isStartingAnimatedPageScroll = false
    private var deferredAnimatedPageCompletionIndex: Int?
    private var isHeaderLayoutReloadActive = false
    private var isPagerVisible = false
    private var parentAppearanceForwardedChildIndex: Int?
    private var appearedChildIndex: Int?
    private var activePageAppearanceTransition: PageAppearanceTransition?
    private var isSuppressingChildScrollIndicatorsForHorizontalPaging = false
    private var containerRefreshHostPriorityChildIndexes: Set<Int> = []
    private var headerPullDownGatePriorityChildIndexes: Set<Int> = []
    private var containerRefreshProxyOverscrollOffsetY: CGFloat = 0
    private var containerRefreshHostRejectedChildGestureIndex: Int?
    private var isRoutingContainerHostUpwardPanToChild = false
    private var tabSelectionOffsetLock: TabSelectionOffsetLock?
    private let loadedChildWindowRadius = 1

    /// 创建容器。
    public init(configuration: CollapsiblePagerConfiguration = .default) {
        self.configuration = configuration
        refreshHandoffCoordinator = RefreshHandoffCoordinator(mode: configuration.refreshHandoffMode)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable, message: "Use init(configuration:) instead.")
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        configureViewHierarchy()
    }

    open override var shouldAutomaticallyForwardAppearanceMethods: Bool {
        false
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        headerHostCoordinator.beginAppearanceTransition(appearing: true, animated: animated)
        beginCurrentChildAppearanceTransition(appearing: true, animated: animated)
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        headerHostCoordinator.endAppearanceTransition(didAppear: true)
        endCurrentChildAppearanceTransition(didAppear: true)
        isPagerVisible = true
        appearedChildIndex = state.effectiveSelectedIndex
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isPagerVisible = false
        headerHostCoordinator.beginAppearanceTransition(appearing: false, animated: animated)
        beginCurrentChildAppearanceTransition(appearing: false, animated: animated)
    }

    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        headerHostCoordinator.endAppearanceTransition(didAppear: false)
        endCurrentChildAppearanceTransition(didAppear: false)
        appearedChildIndex = nil
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyLayout()
        updateHeaderHostPlacement(reason: .currentChild)
    }

    /// 从 data source 重新加载 Header、TabBar 和当前有效页面。
    public func reloadData() {
        loadViewIfNeeded()

        let rawPageCount = dataSource?.numberOfPages(in: self) ?? 0
        let nextPageCount = max(0, rawPageCount)
        let previousSelection = effectiveSelectedIndex ?? selectedIndex

        removeLoadedChildren()
        isSuppressingChildScrollIndicatorsForHorizontalPaging = false
        refreshHandoffCoordinator.mode = configuration.refreshHandoffMode
        refreshHandoffCoordinator.resetGesture()
        containerRefreshProxyOverscrollOffsetY = 0
        containerRefreshHostRejectedChildGestureIndex = nil
        isRoutingContainerHostUpwardPanToChild = false
        tabSelectionOffsetLock = nil
        containerRefreshHostScrollViewStorage.resetOffsetIfIdle()
        visitedPageIndexes.removeAll()
        preservedContentOffsetYByIndex.removeAll()
        pageContainer.removeAllPageViews()
        pageContainer.setPageCount(nextPageCount)
        updateStateForReload(pageCount: nextPageCount, previousSelection: previousSelection)
        syncPublicSelectionFromState()
        if let effectiveSelectedIndex {
            visitedPageIndexes.insert(effectiveSelectedIndex)
        }

        guard nextPageCount > 0, let dataSource else {
            tabBarView.reloadTitles([])
            tabBarView.update(position: nil)
            headerHostCoordinator.clearContent(ownerIsVisible: isPagerVisible)
            applyLayout()
            return
        }

        let titles = (0..<nextPageCount).map { index in
            dataSource.pagerViewController(self, titleForPageAt: index)
        }
        tabBarView.reloadTitles(titles)
        tabBarView.update(position: state.pagePosition)

        if let effectiveSelectedIndex {
            pageContainer.scrollToPage(at: effectiveSelectedIndex, animated: false)
            _ = loadChildIfNeeded(at: effectiveSelectedIndex)
            headerHostCoordinator.setContent(
                dataSource.headerContent(in: self),
                initialContainer: fixedHeaderContainer,
                ownerIsVisible: isPagerVisible
            )
        }

        applyLayout()
        updateLoadedChildWindowIfNeeded()
        updateHeaderHostPlacement(reason: .currentChild)
    }

    /// 请求选择页面。
    public func selectPage(at index: Int, animated: Bool) {
        requestPageSelection(at: index, source: .api, animated: animated)
    }

    private func requestPageSelection(at index: Int, source: PageRequestSource, animated: Bool) {
        debugPagingLog(
            "pageRequest begin source=\(debugPageRequestSource(source)) target=\(index) animated=\(animated) \(debugPagingState()) position=\(debugPagePosition(state.pagePosition))"
        )
        guard let fromIndex = state.effectiveSelectedIndex else {
            debugPagingLog(
                "pageRequest rejected source=\(debugPageRequestSource(source)) target=\(index) reason=noEffectiveSelection \(debugPagingState())"
            )
            return
        }

        if state.pendingSelectedIndex == index {
            if isPagePositionSettled(at: index) {
                debugPagingLog(
                    "pageRequest completingSettledPending source=\(debugPageRequestSource(source)) from=\(fromIndex) target=\(index) \(debugPagingState()) position=\(debugPagePosition(state.pagePosition))"
                )
                completePageTransition(targetIndex: index)
            } else {
                debugPagingLog(
                    "pageRequest ignoredDuplicatePending source=\(debugPageRequestSource(source)) from=\(fromIndex) target=\(index) \(debugPagingState()) position=\(debugPagePosition(state.pagePosition))"
                )
            }
            return
        }

        let previousPendingSelectedIndex = state.pendingSelectedIndex
        let request = PageRequest(source: source, fromIndex: fromIndex, targetIndex: index, animated: animated)
        guard pageRequestPipeline.request(request, state: &state) else {
            debugPagingLog(
                "pageRequest rejected source=\(debugPageRequestSource(source)) from=\(fromIndex) target=\(index) reason=pipelineRejected \(debugPagingState()) position=\(debugPagePosition(state.pagePosition))"
            )
            return
        }
        let didCancelPendingSelection = previousPendingSelectedIndex != nil &&
            state.pendingSelectedIndex == nil &&
            state.effectiveSelectedIndex == index
        if didCancelPendingSelection || deferredAnimatedPageCompletionIndex.map({ $0 != index }) == true {
            deferredAnimatedPageCompletionIndex = nil
        }
        tabSelectionOffsetLock = nil
        if didCancelPendingSelection {
            debugPagingLog(
                "pageRequest cancelledPending source=\(debugPageRequestSource(source)) from=\(fromIndex) target=\(index) previousPending=\(debugIndex(previousPendingSelectedIndex)) \(debugPagingState()) position=\(debugPagePosition(state.pagePosition))"
            )
        } else {
            debugPagingLog(
                "pageRequest accepted source=\(debugPageRequestSource(source)) from=\(fromIndex) target=\(index) animated=\(animated) \(debugPagingState()) position=\(debugPagePosition(state.pagePosition))"
            )
        }

        tabBarView.update(position: state.pagePosition)
        _ = loadChildIfNeeded(at: index)
        prepareUnvisitedTargetChildForTabTapIfNeeded(at: index, source: source)
        beginPageAppearanceTransitionForNewRequest(
            to: index,
            animated: shouldAnimateChildAppearanceTransition(
                source: source,
                from: fromIndex,
                to: index,
                requestedAnimated: animated
            )
        )
        updateHeaderHostPlacement(reason: .horizontalPaging)
        let shouldAnimateScroll = shouldAnimatePageScroll(from: fromIndex, to: index, animated: animated)
        scrollToRequestedPage(at: index, animated: shouldAnimateScroll)

        if didCancelPendingSelection {
            finishCancelledPageTransition(targetIndex: index, source: source)
            return
        }
        if !shouldAnimateScroll {
            completePageTransition(targetIndex: index)
        }
    }

    /// 重新测量 Header 布局，并按策略修正 Header 折叠状态与 child 滚动位置。
    ///
    /// Header 高度变化时，容器会保持 `PinAnchor` 与当前 Header 区间内 child `contentOffset` 的一致性。
    public func reloadHeaderLayout(offsetPolicy: CollapsiblePagerHeaderOffsetPolicy = .preserveVisualPosition) {
        guard isViewLoaded else {
            return
        }

        isHeaderLayoutReloadActive = true
        defer {
            isHeaderLayoutReloadActive = false
        }

        let previousHeights = currentAppliedHeaderHeights()
        let nextHeights = headerHeights().normalized
        let transition = layoutEngine.headerOffsetTransition(
            from: previousHeights,
            to: nextHeights,
            currentPinAnchorY: state.pinAnchorY,
            policy: offsetPolicy
        )
        let minimumOffsetY = -(nextHeights.maxHeight + max(0, configuration.tabBar.height))
        let correctedLoadedOffsets = loadedChildRecords.mapValues { record in
            max(record.scrollView.contentOffset.y + transition.contentOffsetCorrectionY, minimumOffsetY)
        }

        state.pinAnchorY = transition.nextPinAnchorY
        verticalScrollCoordinator.setPinAnchorY(transition.nextPinAnchorY)
        syncPreservedContentOffsets(
            by: transition.contentOffsetCorrectionY,
            minimumOffsetY: minimumOffsetY
        )
        // contentInset 变化可能同步触发 didScroll；reload 内部修正不应被当作用户滚动。
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
        updateHeaderHostPlacement(reason: .layoutReload)
    }

    var tabBarItemCountForTesting: Int {
        tabBarView.itemCount
    }

    var pageContainerPageCountForTesting: Int {
        pageContainer.pageCount
    }

    var pageContainerBouncesForTesting: Bool {
        pageContainer.scrollView.bounces
    }

    var pageContainerAlwaysBouncesHorizontallyForTesting: Bool {
        pageContainer.scrollView.alwaysBounceHorizontal
    }

    var containerRefreshHostScrollViewForTesting: UIScrollView {
        containerRefreshHostScrollViewStorage
    }

    var pageContainerLoadedPageIndexesForTesting: [Int] {
        pageContainer.loadedPageIndexes
    }

    var loadedChildIndexesForTesting: [Int] {
        loadedChildRecords.keys.sorted()
    }

    func childScrollViewForTesting(at index: Int) -> UIScrollView? {
        loadedChildRecords[index]?.scrollView
    }

    var collapseProgressForTesting: CGFloat {
        currentLayoutOutput?.collapseProgress ?? 0
    }

    var tabBarFrameForTesting: CGRect {
        tabBarView.convert(tabBarView.bounds, to: view)
    }

    var headerFrameForTesting: CGRect {
        fixedHeaderContainer.convert(fixedHeaderContainer.bounds, to: view)
    }

    var headerHostSuperviewForTesting: UIView? {
        headerHostCoordinator.hostSuperviewForTesting
    }

    var pinnedSurfaceSuperviewForTesting: UIView? {
        pinnedSurfaceView.superview
    }

    var fixedHeaderContainerForTesting: UIView {
        fixedHeaderContainer
    }

    func headerMountViewForTesting(at index: Int) -> UIView? {
        loadedChildRecords[index]?.mountView
    }

    func completePendingPageTransitionForTesting(targetIndex: Int) {
        completePageTransition(targetIndex: targetIndex)
    }

    func tapTabItemForTesting(at index: Int) {
        tabBarView.itemView(at: index)?.sendActions(for: .touchUpInside)
    }

    func updatePagePositionForTesting(_ position: PagePosition?) {
        handlePagePositionChanged(position)
    }

    func shouldBeginHorizontalPagingForTesting(translation: CGSize, location: CGPoint) -> Bool {
        shouldBeginHorizontalPaging(translation: translation, location: location)
    }

    func shouldBeginContainerRefreshHostPanForTesting(
        translation: CGSize,
        velocity: CGSize,
        location: CGPoint? = nil
    ) -> Bool {
        shouldBeginContainerRefreshHostPan(translation: translation, velocity: velocity, location: location)
    }

    func containerRefreshHostPanHasPriorityOverChildPanForTesting(at index: Int) -> Bool {
        containerRefreshHostPriorityChildIndexes.contains(index)
    }

    func headerPullDownGateHasPriorityOverChildPanForTesting(at index: Int) -> Bool {
        headerPullDownGatePriorityChildIndexes.contains(index)
    }

    func shouldBeginHeaderPullDownGateForTesting(translation: CGSize, velocity: CGSize) -> Bool {
        shouldBeginHeaderPullDownGate(translation: translation, velocity: velocity, location: nil)
    }

    var activeRefreshHandoffForTesting: RefreshHandoff? {
        refreshHandoffCoordinator.activeHandoff
    }

    func applyContainerRefreshProxyOverscrollForTesting(_ offsetY: CGFloat) {
        containerRefreshProxyOverscrollOffsetY = offsetY
        updateHeaderHostPlacement(reason: .currentChild)
    }

    func finishProxiedContainerRefreshHandoffForTesting(at index: Int) {
        finishProxiedContainerRefreshHandoffIfPossible(forChildAt: index)
    }

    private func configureViewHierarchy() {
        view.backgroundColor = .systemBackground

        pageContainer.shouldBeginHorizontalPan = { [weak self] pan in
            guard let self else {
                return true
            }

            let translation = pan.translation(in: self.view)
            let velocity = pan.velocity(in: self.view)
            let location = pan.location(in: self.view)
            self.debugPagingLog(
                "horizontalPan gesture state=\(self.debugGestureState(pan.state)) panView=\(self.debugViewName(pan.view)) \(self.debugTouchContext(at: location)) translation=\(self.debugSize(CGSize(width: translation.x, height: translation.y))) velocity=\(self.debugSize(CGSize(width: velocity.x, height: velocity.y)))"
            )
            return self.shouldBeginHorizontalPaging(
                translation: CGSize(width: translation.x, height: translation.y),
                location: location
            )
        }
        pageContainer.onPagePositionChanged = { [weak self] position in
            self?.handlePagePositionChanged(position)
        }
        pageContainer.onPageTransitionCompleted = { [weak self] index in
            guard let self else {
                return
            }

            if self.isStartingAnimatedPageScroll {
                // UIKit 可能在 setContentOffset(animated:) 启动期间同步回调完成；先等 PagePosition 证明目标页已稳定。
                self.deferredAnimatedPageCompletionIndex = index
                self.debugPagingLog(
                    "transitionCompleted deferred index=\(index) reason=startingAnimatedPageScroll \(self.debugPagingState()) position=\(self.debugPagePosition(self.state.pagePosition))"
                )
                return
            }

            self.handlePageTransitionCompleted(index)
        }
        containerRefreshHostScrollViewStorage.shouldBeginRefreshPan = { [weak self] pan in
            guard let self else {
                return false
            }

            let translation = pan.translation(in: self.view)
            let velocity = pan.velocity(in: self.view)
            let location = pan.location(in: self.view)
            self.debugPullDownLog(
                "containerPan gesture state=\(self.debugGestureState(pan.state)) panView=\(self.debugViewName(pan.view)) \(self.debugTouchContext(at: location))"
            )
            return self.shouldBeginContainerRefreshHostPan(
                translation: CGSize(width: translation.x, height: translation.y),
                velocity: CGSize(width: velocity.x, height: velocity.y),
                location: location
            )
        }
        containerRefreshHostScrollViewStorage.onRefreshPanWillBegin = { [weak self] in
            guard let self else {
                return
            }

            if self.isRoutingContainerHostUpwardPanToChild {
                self.refreshHandoffCoordinator.resetGesture()
                self.containerRefreshProxyOverscrollOffsetY = 0
                self.containerRefreshHostRejectedChildGestureIndex = nil
            } else {
                self.beginContainerRefreshHandoffFromHostIfNeeded(adoptingProxyOverscroll: true)
            }
        }
        containerRefreshHostScrollViewStorage.onShouldScrollToTop = { [weak self] scrollView in
            self?.handleContainerScrollsToTopRequest(scrollView) ?? false
        }
        containerRefreshHostScrollViewStorage.onDidScroll = { [weak self] scrollView in
            self?.handleContainerRefreshHostDidScroll(scrollView)
        }
        containerRefreshHostScrollViewStorage.onScrollInteractionDidEnd = { [weak self] scrollView in
            self?.finishContainerRefreshHostHandoffIfPossible(sourceScrollView: scrollView)
            self?.isRoutingContainerHostUpwardPanToChild = false
        }
        headerPullDownGateGesture.shouldBeginGate = { [weak self] pan in
            guard let self else {
                return false
            }

            let translation = pan.translation(in: self.view)
            let velocity = pan.velocity(in: self.view)
            let location = pan.location(in: self.view)
            self.debugPullDownLog(
                "headerGate gesture state=\(self.debugGestureState(pan.state)) panView=\(self.debugViewName(pan.view)) \(self.debugTouchContext(at: location))"
            )
            return self.shouldBeginHeaderPullDownGate(
                translation: CGSize(width: translation.x, height: translation.y),
                velocity: CGSize(width: velocity.x, height: velocity.y),
                location: location
            )
        }
        headerHostCoordinator.installGestureRecognizer(headerPullDownGateGesture)
        tabBarView.onRequestSelection = { [weak self] index in
            guard let self else {
                return
            }

            self.debugPagingLog(
                "tabTap index=\(index) \(self.debugTabItemContext(at: index)) \(self.debugPagingState()) position=\(self.debugPagePosition(self.state.pagePosition))"
            )
            self.requestPageSelection(at: index, source: .tabTap, animated: true)
        }
        tabBarView.apply(configuration: configuration.tabBar)
        pageContainer.apply(paging: configuration.paging)
        verticalScrollCoordinator.onPinAnchorChanged = { [weak self] result in
            self?.handlePinAnchorChanged(result)
        }

        view.addSubview(containerRefreshHostScrollViewStorage)
        containerRefreshHostScrollViewStorage.addSubview(pageContainer)
        containerRefreshHostScrollViewStorage.addSubview(pinnedSurfaceView)
        pinnedSurfaceView.addSubview(fixedHeaderContainer)
        pinnedSurfaceView.addSubview(tabBarView)
    }

    private func updateStateForReload(pageCount: Int, previousSelection: Int) {
        state = CollapsiblePagerState.initial(pageCount: pageCount)

        guard pageCount > 0 else {
            state.selectedIndex = 0
            state.effectiveSelectedIndex = nil
            state.pendingSelectedIndex = nil
            state.pendingPageRequestSource = nil
            state.pagePosition = nil
            return
        }

        let clampedSelection = previousSelection.clamped(to: 0...(pageCount - 1))
        state.selectedIndex = clampedSelection
        state.effectiveSelectedIndex = clampedSelection
        state.pendingSelectedIndex = nil
        state.pendingPageRequestSource = nil
        state.pagePosition = PagePosition.make(rawPosition: CGFloat(clampedSelection), pageCount: pageCount, isInteractive: false)
    }

    private func syncPublicSelectionFromState() {
        selectedIndex = state.selectedIndex
        effectiveSelectedIndex = state.effectiveSelectedIndex
    }

    private func loadChildIfNeeded(at index: Int) -> CollapsiblePagerChildRecord? {
        guard loadedChildRecords[index] == nil,
              state.pageCount > 0,
              (0..<state.pageCount).contains(index),
              let dataSource,
              let pageView = pageContainer.pageView(at: index) else {
            return loadedChildRecords[index]
        }

        let child = dataSource.pagerViewController(self, viewControllerForPageAt: index)
        let managedTopInset = managedTopInsetForChildren()
        let pinThreshold = currentLayoutOutput?.pinThreshold ?? headerHeights().normalized.collapseRange
        let initialPinAnchorY = visitedPageIndexes.contains(index) ? state.pinAnchorY : 0
        guard let record = childStore.makeRecord(
            for: child,
            index: index,
            managedTopInset: managedTopInset,
            managedBottomInset: currentLayoutOutput?.childContentInset.bottom ?? bottomObstructionInset(),
            pinThreshold: pinThreshold,
            initialPinAnchorY: initialPinAnchorY
        ) else {
            return nil
        }

        childStore.attach(record, to: pageView)
        loadedChildRecords[index] = record
        observeScrollView(for: record)
        observeChildPanInteractionEnd(for: record)
        prioritizeContainerRefreshHostPan(over: record)
        prioritizeHeaderPullDownGate(over: record)
        applyChildScrollIndicatorSuppression(to: record)
        updateLoadedChildForCurrentLayout(record)
        restorePreservedContentOffsetIfNeeded(
            for: record,
            managedTopInset: managedTopInset,
            pinThreshold: pinThreshold
        )
        syncVerticalScrollCoordinatorRecords()
        return record
    }

    private func removeLoadedChildren() {
        scrollObservations.removeAll()
        containerRefreshHostPriorityChildIndexes.removeAll()
        headerPullDownGatePriorityChildIndexes.removeAll()
        containerRefreshHostRejectedChildGestureIndex = nil
        for record in loadedChildRecords.values {
            removeChildPanInteractionEndObservation(for: record)
            childStore.detach(record)
            record.mountView.removeFromSuperview()
        }
        loadedChildRecords.removeAll()
    }

    private func unloadChild(at index: Int) {
        guard let record = loadedChildRecords[index] else {
            pageContainer.removePageView(at: index)
            return
        }

        scrollObservations[index] = nil
        containerRefreshHostPriorityChildIndexes.remove(index)
        headerPullDownGatePriorityChildIndexes.remove(index)
        if containerRefreshHostRejectedChildGestureIndex == index {
            containerRefreshHostRejectedChildGestureIndex = nil
        }
        removeChildPanInteractionEndObservation(for: record)
        if visitedPageIndexes.contains(index) {
            preservedContentOffsetYByIndex[index] = record.scrollView.contentOffset.y
        } else {
            preservedContentOffsetYByIndex[index] = nil
        }
        childStore.detach(record)
        record.mountView.removeFromSuperview()
        loadedChildRecords[index] = nil
        pageContainer.removePageView(at: index)
    }

    private func handlePagePositionChanged(_ position: PagePosition?) {
        let previousPosition = state.pagePosition
        let wasHorizontalPagingActive = verticalScrollCoordinator.isHorizontalPagingActive
        let willSuppressIndicators = shouldSuppressChildScrollIndicators(for: position)
        prepareInteractivePageTransitionIfNeeded(for: position)
        state.pagePosition = position
        verticalScrollCoordinator.isHorizontalPagingActive = position?.isInteractive == true
        updateChildScrollIndicatorSuppression(willSuppressIndicators)
        tabBarView.update(position: position)
        debugPagingLog(
            "positionChanged from={\(debugPagePosition(previousPosition))} to={\(debugPagePosition(position))} horizontalActive=\(wasHorizontalPagingActive)->\(verticalScrollCoordinator.isHorizontalPagingActive) suppressIndicators=\(willSuppressIndicators) \(debugPagingState())"
        )
        updateHeaderHostPlacement(
            reason: willSuppressIndicators ? .horizontalPaging : .currentChild
        )
        completeDeferredPageTransitionIfSettled()
    }

    private func handlePageTransitionCompleted(_ index: Int) {
        debugPagingLog(
            "transitionCompleted callback index=\(index) \(debugPagingState()) position=\(debugPagePosition(state.pagePosition))"
        )
        completePageTransition(targetIndex: index)
    }

    private func completeDeferredPageTransitionIfSettled() {
        guard let index = deferredAnimatedPageCompletionIndex,
              isPagePositionSettled(at: index) else {
            return
        }

        deferredAnimatedPageCompletionIndex = nil
        debugPagingLog(
            "transitionCompleted consumingDeferred index=\(index) \(debugPagingState()) position=\(debugPagePosition(state.pagePosition))"
        )
        handlePageTransitionCompleted(index)
    }

    private func completePageTransition(targetIndex: Int) {
        debugPagingLog(
            "transitionComplete begin target=\(targetIndex) \(debugPagingState()) position=\(debugPagePosition(state.pagePosition))"
        )

        if let deferredIndex = deferredAnimatedPageCompletionIndex, deferredIndex == targetIndex {
            deferredAnimatedPageCompletionIndex = nil
        }
        let pendingTargetIndex = state.pendingSelectedIndex
        let pendingSource = state.pendingPageRequestSource
        let completionResult = pageRequestPipeline.complete(targetIndex: targetIndex, state: &state)
        guard completionResult != .ignored, let completedIndex = state.effectiveSelectedIndex else {
            debugPagingLog(
                "transitionComplete ignored target=\(targetIndex) result=\(completionResult) \(debugPagingState()) position=\(debugPagePosition(state.pagePosition))"
            )
            return
        }

        let shouldNotifySelection = completionResult == .committed
        syncPublicSelectionFromState()
        tabBarView.update(position: state.pagePosition)
        _ = loadChildIfNeeded(at: completedIndex)
        finishPageAppearanceTransition(completedIndex: completedIndex)
        pageContainer.scrollToPage(at: completedIndex, animated: false)
        updateLoadedChildWindowIfNeeded()
        syncVerticalScrollCoordinatorRecords()
        switch pendingSource {
        case .tabTap:
            preservePinAnchorForCurrentChildAfterTabSelection()
        case .gesture where pendingTargetIndex == completedIndex:
            // 正常手势提交时目标页已参与触摸和命中区域，提交后以目标页 offset 作为新的纵向锚点。
            adoptPinAnchorFromCurrentChildOffset()
        case .gesture, .api, nil:
            alignCurrentChildOffsetToPinAnchor()
        }
        visitedPageIndexes.insert(completedIndex)
        updateChildScrollIndicatorSuppression(false)
        updateHeaderHostPlacement(reason: .currentChild)

        debugPagingLog(
            "transitionComplete end target=\(targetIndex) result=\(completionResult) completed=\(completedIndex) notified=\(shouldNotifySelection && state.effectiveSelectedIndex == completedIndex) \(debugPagingState()) position=\(debugPagePosition(state.pagePosition))"
        )
        if shouldNotifySelection, state.effectiveSelectedIndex == completedIndex {
            delegate?.pagerViewController(self, didSelectPageAt: completedIndex)
        }
    }

    private func isPagePositionSettled(at index: Int) -> Bool {
        guard let position = state.pagePosition else {
            return false
        }

        return position.fromIndex == index &&
            position.toIndex == index &&
            position.progress == 0 &&
            !position.isInteractive
    }

    private func finishCancelledPageTransition(targetIndex: Int, source: PageRequestSource) {
        syncPublicSelectionFromState()
        tabBarView.update(position: state.pagePosition)
        _ = loadChildIfNeeded(at: targetIndex)
        finishPageAppearanceTransition(completedIndex: targetIndex)
        updateLoadedChildWindowIfNeeded()
        syncVerticalScrollCoordinatorRecords()
        adoptPinAnchorFromCurrentChildOffset()
        visitedPageIndexes.insert(targetIndex)
        updateChildScrollIndicatorSuppression(false)
        updateHeaderHostPlacement(reason: .currentChild)

        debugPagingLog(
            "transitionCancel end source=\(debugPageRequestSource(source)) target=\(targetIndex) \(debugPagingState()) position=\(debugPagePosition(state.pagePosition))"
        )
    }

    private func applyLayout() {
        guard isViewLoaded else {
            return
        }

        let output = layoutEngine.layout(layoutInput())
        currentLayoutOutput = output
        appliedHeaderHeights = headerHeights().normalized
        let refreshBaselineTop = output.pageContainerFrame.minY
        containerRefreshHostScrollViewStorage.frame = view.bounds
        containerRefreshHostScrollViewStorage.updateRefreshBaselineTop(refreshBaselineTop)
        // Refresh host 的 top inset 只移动刷新 reveal 基线；内容层反向平移以保持布局输出的屏幕位置。
        pinnedSurfaceView.frame = view.bounds.offsetBy(dx: 0, dy: -refreshBaselineTop)
        pageContainer.frame = output.pageContainerFrame.offsetBy(dx: 0, dy: -refreshBaselineTop)
        fixedHeaderContainer.frame = output.headerFrame
        tabBarView.frame = output.tabBarFrame
        verticalScrollCoordinator.updateLayout(
            pinThreshold: output.pinThreshold,
            managedTopInset: output.childContentInset.top
        )
        updateLoadedChildrenForLayout(output)
        syncVerticalScrollCoordinatorRecords()
        restoreContainerRefreshProxyOverscrollIfNeeded()

        containerRefreshHostScrollViewStorage.bringSubviewToFront(pinnedSurfaceView)

        delegate?.pagerViewController(self, didUpdateCollapseProgress: output.collapseProgress)
        delegate?.pagerViewController(
            self,
            didUpdateLayout: CollapsiblePagerLayoutContext(
                headerVisibleHeight: output.headerVisibleHeight,
                collapseProgress: output.collapseProgress,
                effectiveSelectedIndex: state.effectiveSelectedIndex
            )
        )
    }

    private func updateLoadedChildrenForLayout(_ output: CollapsiblePagerLayoutOutput) {
        for record in loadedChildRecords.values {
            updateLoadedChild(record, for: output)
        }
    }

    private func updateLoadedChildForCurrentLayout(_ record: CollapsiblePagerChildRecord) {
        guard let currentLayoutOutput else {
            return
        }

        updateLoadedChild(record, for: currentLayoutOutput)
    }

    private func updateLoadedChild(_ record: CollapsiblePagerChildRecord, for output: CollapsiblePagerLayoutOutput) {
        childStore.updateManagedInset(
            for: record,
            managedTopInset: output.childContentInset.top,
            managedBottomInset: output.childContentInset.bottom,
            pinThreshold: output.pinThreshold
        )
    }

    private func observeScrollView(for record: CollapsiblePagerChildRecord) {
        scrollObservations[record.index] = CollapsiblePagerScrollObservation(
            scrollView: record.scrollView,
            offsetHandler: { [weak self] scrollView in
                self?.handleChildScrollViewDidScroll(scrollView)
            },
            contentSizeHandler: { [weak self] scrollView in
                self?.handleChildScrollViewContentSizeDidChange(scrollView)
            }
        )
    }

    private func observeChildPanInteractionEnd(for record: CollapsiblePagerChildRecord) {
        record.scrollView.panGestureRecognizer.addTarget(
            self,
            action: #selector(handleChildPanGestureStateChanged(_:))
        )
    }

    private func removeChildPanInteractionEndObservation(for record: CollapsiblePagerChildRecord) {
        record.scrollView.panGestureRecognizer.removeTarget(
            self,
            action: #selector(handleChildPanGestureStateChanged(_:))
        )
    }

    @objc private func handleChildPanGestureStateChanged(_ panGestureRecognizer: UIPanGestureRecognizer) {
        switch panGestureRecognizer.state {
        case .ended, .cancelled, .failed:
            break
        default:
            return
        }

        guard let record = loadedChildRecords.values.first(where: {
            $0.scrollView.panGestureRecognizer === panGestureRecognizer
        }) else {
            return
        }

        if containerRefreshProxyOverscrollOffsetY < 0 ||
            containerRefreshHostScrollViewStorage.contentOffset.y < containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY {
            debugPullDownLog(
                "childPan ended state=\(debugGestureState(panGestureRecognizer.state)) index=\(record.index) childOffsetY=\(debugNumber(record.scrollView.contentOffset.y)) hostOffsetY=\(debugNumber(containerRefreshHostScrollViewStorage.contentOffset.y)) baselineY=\(debugNumber(containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY)) proxyY=\(debugNumber(containerRefreshProxyOverscrollOffsetY)) insetTop=\(debugNumber(containerRefreshHostScrollViewStorage.contentInset.top)) activeHandoff=\(String(describing: refreshHandoffCoordinator.activeHandoff))"
            )
        }

        finishProxiedContainerRefreshHandoffIfPossible(sourceScrollView: record.scrollView)
        if containerRefreshHostRejectedChildGestureIndex == record.index {
            containerRefreshHostRejectedChildGestureIndex = nil
        }
    }

    private func prioritizeContainerRefreshHostPan(over record: CollapsiblePagerChildRecord) {
        let childPan = record.scrollView.panGestureRecognizer
        let containerPan = containerRefreshHostScrollViewStorage.panGestureRecognizer
        guard childPan !== containerPan else {
            return
        }

        // `.container` 模式的顶部下拉应由外层 host 先判定；否则 child 会先进入 top bounce，
        // 再被容器拉回 managed boundary，造成 child 内容顶部抖动。
        childPan.require(toFail: containerPan)
        containerRefreshHostPriorityChildIndexes.insert(record.index)
    }

    private func prioritizeHeaderPullDownGate(over record: CollapsiblePagerChildRecord) {
        let childPan = record.scrollView.panGestureRecognizer
        guard childPan !== headerPullDownGateGesture else {
            return
        }

        // Header 展开时 host 可能位于 child scroll content 内。策略要求 Header 区域下拉不拉出
        // child refresh 时，让 child pan 先等内部 gate 判定，避免 child 自己进入 top bounce。
        childPan.require(toFail: headerPullDownGateGesture)
        headerPullDownGatePriorityChildIndexes.insert(record.index)
    }

    private func handleChildScrollViewDidScroll(_ scrollView: UIScrollView) {
        if reassertTabSelectionOffsetLockIfNeeded(for: scrollView) {
            return
        }

        let result = verticalScrollCoordinator.handleScrollViewDidScroll(scrollView)
        tryBeginRefreshHandoffIfNeeded(for: scrollView)
        if let currentIndex = state.effectiveSelectedIndex,
           let record = loadedChildRecords[currentIndex],
           scrollView === record.scrollView,
           let output = currentLayoutOutput {
            let managedTopBoundary = -output.childContentInset.top
            if scrollView.contentOffset.y <= managedTopBoundary + 8 {
                let location = scrollView.panGestureRecognizer.location(in: view)
                debugPullDownLog(
                    "childDidScroll region=\(debugPullDownRegion(at: location)) location=\(debugPoint(location)) childOffsetY=\(debugNumber(scrollView.contentOffset.y)) boundaryY=\(debugNumber(managedTopBoundary)) collapse=\(debugNumber(output.collapseProgress)) pinY=\(debugNumber(state.pinAnchorY)) hostOffsetY=\(debugNumber(containerRefreshHostScrollViewStorage.contentOffset.y)) hostBaselineY=\(debugNumber(containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY)) proxyY=\(debugNumber(containerRefreshProxyOverscrollOffsetY)) activeHandoff=\(String(describing: refreshHandoffCoordinator.activeHandoff)) resultPinY=\(result.map { debugNumber($0.pinAnchorY) } ?? "nil")"
                )
            }
        }

        if result?.shouldSyncNonCurrentChildren != true {
            updateHeaderHostPlacement(reason: .currentChild)
        }
    }

    private func reassertTabSelectionOffsetLockIfNeeded(for scrollView: UIScrollView) -> Bool {
        guard let lock = tabSelectionOffsetLock,
              let currentIndex = state.effectiveSelectedIndex,
              currentIndex == lock.index,
              let record = loadedChildRecords[currentIndex],
              scrollView === record.scrollView else {
            return false
        }

        guard !scrollView.isTracking,
              !scrollView.isDragging,
              !scrollView.isDecelerating else {
            tabSelectionOffsetLock = nil
            return false
        }

        if scrollView.contentOffset.y < lock.offsetY - 0.5 {
            tabSelectionOffsetLock = nil
            return false
        }

        guard scrollView.contentOffset.y > lock.offsetY + 0.5 else {
            return false
        }

        debugPagingLog(
            "tabSelectionOffsetLock reassert index=\(lock.index) expectedOffsetY=\(debugNumber(lock.offsetY)) actualOffsetY=\(debugNumber(scrollView.contentOffset.y)) pinY=\(debugNumber(lock.pinAnchorY))"
        )
        state.pinAnchorY = lock.pinAnchorY
        verticalScrollCoordinator.setPinAnchorY(lock.pinAnchorY)
        verticalScrollCoordinator.setContentOffsetY(lock.offsetY, for: scrollView)
        record.lastKnownContentOffsetY = record.scrollView.contentOffset.y
        preservedContentOffsetYByIndex[currentIndex] = record.scrollView.contentOffset.y
        applyLayout()
        updateHeaderHostPlacement(reason: .currentChild)
        return true
    }

    private func handleChildScrollViewContentSizeDidChange(_ scrollView: UIScrollView) {
        guard let record = loadedChildRecords.values.first(where: { $0.scrollView === scrollView }) else {
            return
        }

        updateLoadedChildForCurrentLayout(record)
        restorePreservedContentOffsetForCurrentLayoutIfNeeded(record)
    }

    private func handlePinAnchorChanged(_ result: VerticalScrollModelResult) {
        state.pinAnchorY = result.pinAnchorY
        syncPreservedContentOffsets(by: result.pinDeltaY)
        applyLayout()
        updateHeaderHostPlacement(reason: .currentChild)
    }

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
            isCurrentChildTopBouncing(record, layoutOutput: currentLayoutOutput) ||
            shouldSuppressChildScrollIndicators(for: state.pagePosition) ||
            state.pendingSelectedIndex != nil ||
            activePageAppearanceTransition != nil ||
            refreshHandoffCoordinator.activeHandoff != nil ||
            containerRefreshProxyOverscrollOffsetY < 0 ||
            reason == .horizontalPaging ||
            reason == .refresh ||
            reason == .layoutReload

        if isCurrentChildTopBouncing(record, layoutOutput: currentLayoutOutput) ||
            refreshHandoffCoordinator.activeHandoff != nil ||
            containerRefreshProxyOverscrollOffsetY < 0 ||
            reason == .refresh {
            debugPullDownLog(
                "headerPlacement target=\(shouldUseFixedOverlay ? "fixed" : "childMount") reason=\(reason) collapse=\(debugNumber(currentLayoutOutput.collapseProgress)) childOffsetY=\(debugNumber(record.scrollView.contentOffset.y)) boundaryY=\(debugNumber(-currentLayoutOutput.childContentInset.top)) hostOffsetY=\(debugNumber(containerRefreshHostScrollViewStorage.contentOffset.y)) proxyY=\(debugNumber(containerRefreshProxyOverscrollOffsetY)) activeHandoff=\(String(describing: refreshHandoffCoordinator.activeHandoff))"
            )
        }

        if shouldUseFixedOverlay {
            headerHostCoordinator.moveHost(to: fixedHeaderContainer, reason: reason)
        } else {
            let frame = childMountedHeaderHostFrame(in: record.mountView, layoutOutput: currentLayoutOutput)
            headerHostCoordinator.moveHost(to: record.mountView, frame: frame, reason: .currentChild)
        }
    }

    private func isCurrentChildTopBouncing(
        _ record: CollapsiblePagerChildRecord,
        layoutOutput: CollapsiblePagerLayoutOutput
    ) -> Bool {
        record.scrollView.contentOffset.y < -layoutOutput.childContentInset.top
    }

    private func childMountedHeaderHostFrame(
        in mountView: UIView,
        layoutOutput: CollapsiblePagerLayoutOutput
    ) -> CGRect {
        let tabBarHeight = max(0, configuration.tabBar.height)
        let headerHostHeight = max(0, layoutOutput.childContentInset.top - tabBarHeight)

        return CGRect(x: 0, y: 0, width: mountView.bounds.width, height: headerHostHeight)
    }

    private func debugPullDownRegion(at location: CGPoint?) -> String {
        guard let location else {
            return "unknown"
        }
        guard let output = currentLayoutOutput else {
            return view.bounds.contains(location) ? "bounds" : "outside"
        }

        if output.headerFrame.contains(location) {
            return "header"
        }
        if output.tabBarFrame.contains(location) {
            return "tabBar"
        }
        if output.pageContainerFrame.contains(location) {
            return "content"
        }
        return view.bounds.contains(location) ? "chrome" : "outside"
    }

    private func debugNumber(_ value: CGFloat) -> String {
        String(format: "%.2f", Double(value))
    }

    private func debugPoint(_ point: CGPoint?) -> String {
        guard let point else {
            return "nil"
        }
        return "(\(debugNumber(point.x)),\(debugNumber(point.y)))"
    }

    private func debugSize(_ size: CGSize) -> String {
        "(\(debugNumber(size.width)),\(debugNumber(size.height)))"
    }

    private func debugRect(_ rect: CGRect?) -> String {
        guard let rect else {
            return "nil"
        }

        return "(\(debugNumber(rect.minX)),\(debugNumber(rect.minY)),\(debugNumber(rect.width)),\(debugNumber(rect.height)))"
    }

    private func debugIndex(_ index: Int?) -> String {
        index.map(String.init) ?? "nil"
    }

    private func debugTouchContext(at location: CGPoint?) -> String {
        guard let location else {
            return "touchLocation=nil hitView=nil owner=unknown"
        }

        let hitView = view.hitTest(location, with: nil)
        return "touchLocation=\(debugPoint(location)) hitView=\(debugViewName(hitView)) owner=\(debugTouchOwner(for: hitView))"
    }

    private func debugTouchOwner(for hitView: UIView?) -> String {
        guard let hitView else {
            return "nil"
        }

        if hitView === fixedHeaderContainer || hitView.isDescendant(of: fixedHeaderContainer) {
            return "fixedHeader"
        }
        if hitView === tabBarView || hitView.isDescendant(of: tabBarView) {
            return "tabBar"
        }
        for record in loadedChildRecords.values.sorted(by: { $0.index < $1.index }) {
            if hitView === record.scrollView || hitView.isDescendant(of: record.scrollView) {
                return "childScroll[\(record.index)]"
            }
            if hitView === record.mountView || hitView.isDescendant(of: record.mountView) {
                return "headerMount[\(record.index)]"
            }
        }
        if hitView === pageContainer || hitView.isDescendant(of: pageContainer) {
            return "pageContainer"
        }
        if hitView === containerRefreshHostScrollViewStorage ||
            hitView.isDescendant(of: containerRefreshHostScrollViewStorage) {
            return "containerHost"
        }
        return "pagerRoot"
    }

    private func debugViewName(_ view: UIView?) -> String {
        guard let view else {
            return "nil"
        }
        return String(describing: type(of: view))
    }

    private func debugGestureState(_ state: UIGestureRecognizer.State) -> String {
        switch state {
        case .possible:
            return "possible"
        case .began:
            return "began"
        case .changed:
            return "changed"
        case .ended:
            return "ended"
        case .cancelled:
            return "cancelled"
        case .failed:
            return "failed"
        @unknown default:
            return "unknown"
        }
    }

    private func debugPullDownLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[CollapsiblePager][PullDown] \(message())")
        #endif
    }

    private func debugPagingLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[CollapsiblePager][Paging] \(message())")
        #endif
    }

    private func debugPagingState() -> String {
        let pendingSource = state.pendingPageRequestSource.map(debugPageRequestSource) ?? "nil"
        return "selected=\(state.selectedIndex) effective=\(debugIndex(state.effectiveSelectedIndex)) pending=\(debugIndex(state.pendingSelectedIndex)) pendingSource=\(pendingSource) pageCount=\(state.pageCount)"
    }

    private func debugPagePosition(_ position: PagePosition?) -> String {
        guard let position else {
            return "nil"
        }

        return "raw=\(debugNumber(position.rawPosition)) from=\(position.fromIndex) to=\(position.toIndex) progress=\(debugNumber(position.progress)) direction=\(debugPageDirection(position.direction)) interactive=\(position.isInteractive)"
    }

    private func debugPageDirection(_ direction: PageDirection) -> String {
        switch direction {
        case .backward:
            return "backward"
        case .forward:
            return "forward"
        case .stationary:
            return "stationary"
        }
    }

    private func debugPageRequestSource(_ source: PageRequestSource) -> String {
        switch source {
        case .tabTap:
            return "tabTap"
        case .api:
            return "api"
        case .gesture:
            return "gesture"
        }
    }

    private func debugGesturePriority(_ priority: GesturePriority) -> String {
        switch priority {
        case .systemBack:
            return "systemBack"
        case .horizontalPaging:
            return "horizontalPaging"
        case .verticalScrolling:
            return "verticalScrolling"
        case .ignored:
            return "ignored"
        }
    }

    private func debugTabItemContext(at index: Int) -> String {
        guard let itemView = tabBarView.itemView(at: index) else {
            return "itemFrame=nil"
        }

        return "itemFrame=\(debugRect(itemView.convert(itemView.bounds, to: view)))"
    }

    private func shouldBeginHorizontalPaging(translation: CGSize, location: CGPoint) -> Bool {
        guard state.pageCount > 1 else {
            debugPagingLog(
                "horizontalPan shouldBegin=false reason=singlePage location=\(debugPoint(location)) translation=\(debugSize(translation)) \(debugPagingState())"
            )
            return false
        }

        let isInHeader = currentLayoutOutput?.headerFrame.contains(location) ?? false
        let priority = gestureArbiter.gesturePriority(
            for: GestureArbiterInput(
                translation: translation,
                isOnFirstPage: state.effectiveSelectedIndex == 0,
                startsAtLeadingEdge: location.x <= 24,
                isInHeader: isInHeader,
                isRefreshAnimationActive: refreshHandoffCoordinator.activeHandoff != nil,
                isLayoutReloadActive: isHeaderLayoutReloadActive
            )
        )
        let shouldBegin = priority == .horizontalPaging
        debugPagingLog(
            "horizontalPan shouldBegin=\(shouldBegin) priority=\(debugGesturePriority(priority)) region=\(debugPullDownRegion(at: location)) location=\(debugPoint(location)) translation=\(debugSize(translation)) isInHeader=\(isInHeader) leadingEdge=\(location.x <= 24) refreshActive=\(refreshHandoffCoordinator.activeHandoff != nil) layoutReload=\(isHeaderLayoutReloadActive) \(debugPagingState())"
        )
        return shouldBegin
    }

    private func shouldBeginContainerRefreshHostPan(
        translation: CGSize,
        velocity: CGSize,
        location: CGPoint?
    ) -> Bool {
        let region = debugPullDownRegion(at: location)
        guard configuration.refreshHandoffMode == .container else {
            debugPullDownLog("containerPan shouldBegin=false region=\(region) location=\(debugPoint(location)) reason=mode:\(configuration.refreshHandoffMode)")
            return false
        }
        guard !isHeaderLayoutReloadActive else {
            debugPullDownLog("containerPan shouldBegin=false region=\(region) location=\(debugPoint(location)) reason=layoutReload")
            return false
        }
        guard !verticalScrollCoordinator.isHorizontalPagingActive else {
            debugPullDownLog("containerPan shouldBegin=false region=\(region) location=\(debugPoint(location)) reason=horizontalPaging")
            return false
        }
        guard let currentIndex = state.effectiveSelectedIndex,
              let record = loadedChildRecords[currentIndex],
              let output = currentLayoutOutput else {
            debugPullDownLog("containerPan shouldBegin=false region=\(region) location=\(debugPoint(location)) reason=noCurrentChild")
            return false
        }
        guard output.collapseProgress == 0 else {
            debugPullDownLog(
                "containerPan shouldBegin=false region=\(region) location=\(debugPoint(location)) reason=headerNotExpanded collapse=\(debugNumber(output.collapseProgress)) childOffsetY=\(debugNumber(record.scrollView.contentOffset.y))"
            )
            return false
        }

        if let activeHandoff = refreshHandoffCoordinator.activeHandoff,
           activeHandoff != .containerHost(index: currentIndex) {
            debugPullDownLog("containerPan shouldBegin=false region=\(region) location=\(debugPoint(location)) reason=activeHandoff:\(activeHandoff)")
            return false
        }

        let isVerticalPullDown = isVerticalPullDownIntent(translation: translation, velocity: velocity)
        let isVerticalPullUp = isVerticalPullUpIntent(translation: translation, velocity: velocity)
        let hasDownwardVelocity = velocity.height >= 0 || abs(velocity.height) < abs(velocity.width)
        let managedTopBoundary = -output.childContentInset.top
        let childIsAtTop = record.scrollView.contentOffset.y <= managedTopBoundary + 0.5
        let hostBaselineY = containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY
        let hasActiveContainerOverscroll =
            refreshHandoffCoordinator.activeHandoff == .containerHost(index: currentIndex) &&
            (
                containerRefreshProxyOverscrollOffsetY < 0 ||
                containerRefreshHostScrollViewStorage.contentOffset.y < hostBaselineY - 0.5
            )
        let shouldProxyUpwardChromePan =
            isVerticalPullUp && isContainerHostUpwardProxyRegion(location: location, output: output)

        let shouldBegin = childIsAtTop && (
            shouldProxyUpwardChromePan ||
            (hasActiveContainerOverscroll && !isVerticalPullUp) ||
            (isVerticalPullDown && hasDownwardVelocity)
        )
        if shouldBegin {
            if containerRefreshHostRejectedChildGestureIndex == currentIndex {
                containerRefreshHostRejectedChildGestureIndex = nil
            }
            isRoutingContainerHostUpwardPanToChild = shouldProxyUpwardChromePan
        } else if childIsAtTop,
                  !hasActiveContainerOverscroll,
                  isVerticalPullUp {
            containerRefreshHostRejectedChildGestureIndex = currentIndex
            isRoutingContainerHostUpwardPanToChild = false
        } else {
            isRoutingContainerHostUpwardPanToChild = false
        }
        debugPullDownLog(
            "containerPan shouldBegin=\(shouldBegin) region=\(region) location=\(debugPoint(location)) translation=(\(debugNumber(translation.width)),\(debugNumber(translation.height))) velocity=(\(debugNumber(velocity.width)),\(debugNumber(velocity.height))) childOffsetY=\(debugNumber(record.scrollView.contentOffset.y)) boundaryY=\(debugNumber(managedTopBoundary)) hostOffsetY=\(debugNumber(containerRefreshHostScrollViewStorage.contentOffset.y)) hostBaselineY=\(debugNumber(hostBaselineY)) proxyY=\(debugNumber(containerRefreshProxyOverscrollOffsetY)) ownerContinuation=\(hasActiveContainerOverscroll) upwardChromeProxy=\(shouldProxyUpwardChromePan) activeHandoff=\(String(describing: refreshHandoffCoordinator.activeHandoff))"
        )
        return shouldBegin
    }

    private func isContainerHostUpwardProxyRegion(
        location: CGPoint?,
        output: CollapsiblePagerLayoutOutput
    ) -> Bool {
        guard let location else {
            return false
        }

        return output.headerFrame.contains(location) || output.tabBarFrame.contains(location)
    }

    private func shouldBeginHeaderPullDownGate(
        translation: CGSize,
        velocity: CGSize,
        location: CGPoint?
    ) -> Bool {
        let region = debugPullDownRegion(at: location)
        guard configuration.headerPullDownRefreshBehavior == .suppressesChildRefresh else {
            debugPullDownLog("headerGate shouldBegin=false region=\(region) location=\(debugPoint(location)) reason=behavior:\(configuration.headerPullDownRefreshBehavior)")
            return false
        }
        guard configuration.refreshHandoffMode != .container else {
            debugPullDownLog("headerGate shouldBegin=false region=\(region) location=\(debugPoint(location)) reason=containerMode")
            return false
        }
        guard !isHeaderLayoutReloadActive else {
            debugPullDownLog("headerGate shouldBegin=false region=\(region) location=\(debugPoint(location)) reason=layoutReload")
            return false
        }
        guard !verticalScrollCoordinator.isHorizontalPagingActive else {
            debugPullDownLog("headerGate shouldBegin=false region=\(region) location=\(debugPoint(location)) reason=horizontalPaging")
            return false
        }
        guard let currentIndex = state.effectiveSelectedIndex,
              let record = loadedChildRecords[currentIndex],
              let output = currentLayoutOutput else {
            debugPullDownLog("headerGate shouldBegin=false region=\(region) location=\(debugPoint(location)) reason=noCurrentChild")
            return false
        }
        guard output.collapseProgress == 0 else {
            debugPullDownLog(
                "headerGate shouldBegin=false region=\(region) location=\(debugPoint(location)) reason=headerNotExpanded collapse=\(debugNumber(output.collapseProgress)) childOffsetY=\(debugNumber(record.scrollView.contentOffset.y))"
            )
            return false
        }

        let isVerticalPullDown = isVerticalPullDownIntent(translation: translation, velocity: velocity)
        let hasDownwardVelocity = velocity.height >= 0 || abs(velocity.height) < abs(velocity.width)
        let managedTopBoundary = -output.childContentInset.top
        let childIsAtTop = record.scrollView.contentOffset.y <= managedTopBoundary + 0.5

        let shouldBegin = isVerticalPullDown && hasDownwardVelocity && childIsAtTop
        debugPullDownLog(
            "headerGate shouldBegin=\(shouldBegin) region=\(region) location=\(debugPoint(location)) translation=(\(debugNumber(translation.width)),\(debugNumber(translation.height))) velocity=(\(debugNumber(velocity.width)),\(debugNumber(velocity.height))) childOffsetY=\(debugNumber(record.scrollView.contentOffset.y)) boundaryY=\(debugNumber(managedTopBoundary))"
        )
        return shouldBegin
    }

    private func isVerticalPullDownIntent(translation: CGSize, velocity: CGSize) -> Bool {
        let translationMagnitude = max(abs(translation.width), abs(translation.height))
        if translationMagnitude >= 0.5 {
            return translation.height > 0 && abs(translation.height) >= abs(translation.width)
        }

        return velocity.height > 0 && abs(velocity.height) >= abs(velocity.width)
    }

    private func isVerticalPullUpIntent(translation: CGSize, velocity: CGSize) -> Bool {
        let translationMagnitude = max(abs(translation.width), abs(translation.height))
        if translationMagnitude >= 0.5 {
            return translation.height < 0 && abs(translation.height) >= abs(translation.width)
        }

        return velocity.height < 0 && abs(velocity.height) >= abs(velocity.width)
    }

    private func beginContainerRefreshHandoffFromHostIfNeeded(adoptingProxyOverscroll: Bool = false) {
        guard configuration.refreshHandoffMode == .container,
              let index = state.effectiveSelectedIndex,
              let record = loadedChildRecords[index],
              let output = currentLayoutOutput else {
            debugPullDownLog("containerHandoff beginSkipped reason=notReady mode=\(configuration.refreshHandoffMode)")
            return
        }

        if refreshHandoffCoordinator.activeHandoff == .containerHost(index: index) {
            containerRefreshHostRejectedChildGestureIndex = nil
            if adoptingProxyOverscroll && containerRefreshProxyOverscrollOffsetY < 0 {
                debugPullDownLog(
                    "containerHandoff adoptProxy index=\(index) hostOffsetY=\(debugNumber(containerRefreshHostScrollViewStorage.contentOffset.y)) proxyY=\(debugNumber(containerRefreshProxyOverscrollOffsetY))"
                )
                containerRefreshProxyOverscrollOffsetY = 0
            }
            debugPullDownLog(
                "containerHandoff alreadyActive index=\(index) childOffsetY=\(debugNumber(record.scrollView.contentOffset.y)) hostOffsetY=\(debugNumber(containerRefreshHostScrollViewStorage.contentOffset.y)) proxyY=\(debugNumber(containerRefreshProxyOverscrollOffsetY))"
            )
            return
        }

        let managedTopBoundary = -output.childContentInset.top
        let handoff = refreshHandoffCoordinator.tryBeginHandoff(
            headerIsExpanded: output.collapseProgress == 0,
            childIsAtTop: record.scrollView.contentOffset.y <= managedTopBoundary + 0.5,
            index: index
        )

        debugPullDownLog(
            "containerHandoff tryBegin result=\(String(describing: handoff)) index=\(index) collapse=\(debugNumber(output.collapseProgress)) childOffsetY=\(debugNumber(record.scrollView.contentOffset.y)) boundaryY=\(debugNumber(managedTopBoundary)) hostOffsetY=\(debugNumber(containerRefreshHostScrollViewStorage.contentOffset.y)) proxyY=\(debugNumber(containerRefreshProxyOverscrollOffsetY))"
        )
        if handoff != nil {
            containerRefreshHostRejectedChildGestureIndex = nil
            updateHeaderHostPlacement(reason: .refresh)
        }
    }

    private func handleContainerRefreshHostDidScroll(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y < containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY ||
            containerRefreshProxyOverscrollOffsetY < 0 {
            debugPullDownLog(
                "hostDidScroll offsetY=\(debugNumber(scrollView.contentOffset.y)) baselineY=\(debugNumber(containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY)) proxyY=\(debugNumber(containerRefreshProxyOverscrollOffsetY)) insetTop=\(debugNumber(scrollView.contentInset.top)) panState=\(debugGestureState(containerRefreshHostScrollViewStorage.panGestureRecognizer.state)) tracking=\(scrollView.isTracking)/\(scrollView.isDragging)/\(scrollView.isDecelerating) activeHandoff=\(String(describing: refreshHandoffCoordinator.activeHandoff))"
            )
        }

        if releaseProxiedContainerRefreshOverscrollToExternalInsetIfNeeded() {
            return
        }

        if routeContainerHostUpwardScrollToChildIfNeeded(scrollView) {
            return
        }

        if clampActiveContainerRefreshHostToNeutralBaselineIfNeeded(scrollView) {
            return
        }

        if restoreContainerRefreshProxyOverscrollIfNeeded(for: scrollView) {
            beginContainerRefreshHandoffFromHostIfNeeded()
            return
        }

        if scrollView.contentOffset.y < containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY {
            beginContainerRefreshHandoffFromHostIfNeeded()
            return
        }

        if containerRefreshProxyOverscrollOffsetY < 0 {
            beginContainerRefreshHandoffFromHostIfNeeded()
            return
        }
    }

    private func routeContainerHostUpwardScrollToChildIfNeeded(_ scrollView: UIScrollView) -> Bool {
        guard scrollView === containerRefreshHostScrollViewStorage,
              isRoutingContainerHostUpwardPanToChild,
              containerRefreshProxyOverscrollOffsetY >= 0,
              containerRefreshHostScrollViewStorage.usesNeutralRefreshContentInset() else {
            return false
        }

        let hostBaselineY = containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY
        guard scrollView.contentOffset.y > hostBaselineY else {
            debugPullDownLog(
                "hostRouteUpwardClamp offsetY=\(debugNumber(scrollView.contentOffset.y)) baselineY=\(debugNumber(hostBaselineY))"
            )
            containerRefreshProxyOverscrollOffsetY = 0
            containerRefreshHostRejectedChildGestureIndex = nil
            refreshHandoffCoordinator.resetGesture()
            containerRefreshHostScrollViewStorage.setContentOffset(
                CGPoint(x: 0, y: hostBaselineY),
                animated: false
            )
            return true
        }

        guard let currentIndex = state.effectiveSelectedIndex,
              let record = loadedChildRecords[currentIndex],
              let output = currentLayoutOutput else {
            containerRefreshHostScrollViewStorage.setContentOffset(
                CGPoint(x: 0, y: hostBaselineY),
                animated: false
            )
            return true
        }

        let managedTopBoundary = -output.childContentInset.top
        let upwardDeltaY = scrollView.contentOffset.y - hostBaselineY
        guard upwardDeltaY > 0.5 else {
            containerRefreshHostScrollViewStorage.setContentOffset(
                CGPoint(x: 0, y: hostBaselineY),
                animated: false
            )
            return true
        }

        let maximumOffsetY = max(
            managedTopBoundary,
            record.scrollView.contentSize.height + record.scrollView.contentInset.bottom - record.scrollView.bounds.height
        )
        let targetChildOffsetY = min(record.scrollView.contentOffset.y + upwardDeltaY, maximumOffsetY)
        debugPullDownLog(
            "hostRouteUpward index=\(currentIndex) deltaY=\(debugNumber(upwardDeltaY)) childOffsetY=\(debugNumber(record.scrollView.contentOffset.y)) targetChildOffsetY=\(debugNumber(targetChildOffsetY)) hostOffsetY=\(debugNumber(scrollView.contentOffset.y)) baselineY=\(debugNumber(containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY)) activeHandoff=\(String(describing: refreshHandoffCoordinator.activeHandoff))"
        )

        refreshHandoffCoordinator.resetGesture()
        containerRefreshProxyOverscrollOffsetY = 0
        containerRefreshHostRejectedChildGestureIndex = nil
        _ = containerRefreshHostScrollViewStorage.clampToNeutralBaselineIfNeeded()
        verticalScrollCoordinator.setContentOffsetY(targetChildOffsetY, for: record.scrollView)
        adoptPinAnchorFromCurrentChildOffset()
        updateHeaderHostPlacement(reason: .currentChild)
        return true
    }

    private func clampActiveContainerRefreshHostToNeutralBaselineIfNeeded(_ scrollView: UIScrollView) -> Bool {
        guard case .containerHost(index: _)? = refreshHandoffCoordinator.activeHandoff,
              scrollView === containerRefreshHostScrollViewStorage,
              scrollView.contentOffset.y > containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY,
              containerRefreshProxyOverscrollOffsetY >= 0,
              containerRefreshHostScrollViewStorage.usesNeutralRefreshContentInset() else {
            return false
        }

        debugPullDownLog(
            "hostClampBaseline currentOffsetY=\(debugNumber(scrollView.contentOffset.y)) baselineY=\(debugNumber(containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY)) activeHandoff=\(String(describing: refreshHandoffCoordinator.activeHandoff))"
        )
        return containerRefreshHostScrollViewStorage.clampToNeutralBaselineIfNeeded()
    }

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

        if configuration.refreshHandoffMode == .container {
            routeContainerRefreshOverscrollFromChild(
                scrollView,
                managedTopBoundary: managedTopBoundary,
                layoutOutput: output,
                index: index
            )
            return
        }

        if scrollView.contentOffset.y >= managedTopBoundary {
            let hadActiveHandoff = refreshHandoffCoordinator.activeHandoff != nil
            refreshHandoffCoordinator.resetGesture()
            isRoutingContainerHostUpwardPanToChild = false
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

    private func routeContainerRefreshOverscrollFromChild(
        _ scrollView: UIScrollView,
        managedTopBoundary: CGFloat,
        layoutOutput: CollapsiblePagerLayoutOutput,
        index: Int
    ) {
        guard layoutOutput.collapseProgress == 0 else {
            _ = cancelProxiedContainerRefreshHandoffIfNeeded(
                reason: "headerNotExpanded",
                sourceScrollView: scrollView
            )
            debugPullDownLog(
                "childProxy skipped reason=headerNotExpanded collapse=\(debugNumber(layoutOutput.collapseProgress)) childOffsetY=\(debugNumber(scrollView.contentOffset.y)) boundaryY=\(debugNumber(managedTopBoundary))"
            )
            return
        }

        guard scrollView.contentOffset.y < managedTopBoundary else {
            if containerRefreshProxyOverscrollOffsetY < 0 ||
                containerRefreshHostScrollViewStorage.contentOffset.y < containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY {
                debugPullDownLog(
                    "childProxy finishCheck childOffsetY=\(debugNumber(scrollView.contentOffset.y)) boundaryY=\(debugNumber(managedTopBoundary)) hostOffsetY=\(debugNumber(containerRefreshHostScrollViewStorage.contentOffset.y)) proxyY=\(debugNumber(containerRefreshProxyOverscrollOffsetY)) tracking child=\(scrollView.isTracking)/\(scrollView.isDragging)/\(scrollView.isDecelerating) host=\(containerRefreshHostScrollViewStorage.isTracking)/\(containerRefreshHostScrollViewStorage.isDragging)/\(containerRefreshHostScrollViewStorage.isDecelerating)"
                )
            }
            finishProxiedContainerRefreshHandoffIfPossible(sourceScrollView: scrollView)
            return
        }

        if shouldKeepChildOwnedPanAtTopBoundary(index: index, scrollView: scrollView) {
            debugPullDownLog(
                "childProxy skipped reason=containerPanRejected index=\(index) childOffsetY=\(debugNumber(scrollView.contentOffset.y)) boundaryY=\(debugNumber(managedTopBoundary))"
            )
            verticalScrollCoordinator.setContentOffsetY(managedTopBoundary, for: scrollView)
            return
        }

        if shouldKeepIdleChildOverscrollAtTopBoundary(scrollView: scrollView) {
            debugPullDownLog(
                "childProxy skipped reason=idleChildOverscroll childOffsetY=\(debugNumber(scrollView.contentOffset.y)) boundaryY=\(debugNumber(managedTopBoundary))"
            )
            verticalScrollCoordinator.setContentOffsetY(managedTopBoundary, for: scrollView)
            return
        }

        let hostOffsetY = scrollView.contentOffset.y - managedTopBoundary
        containerRefreshProxyOverscrollOffsetY = min(0, hostOffsetY)
        verticalScrollCoordinator.setContentOffsetY(managedTopBoundary, for: scrollView)
        debugPullDownLog(
            "childProxy route index=\(index) hostOverscrollY=\(debugNumber(hostOffsetY)) childOffsetY=\(debugNumber(scrollView.contentOffset.y)) boundaryY=\(debugNumber(managedTopBoundary)) hostOffsetY=\(debugNumber(containerRefreshHostScrollViewStorage.contentOffset.y)) hostBaselineY=\(debugNumber(containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY)) proxyY=\(debugNumber(containerRefreshProxyOverscrollOffsetY))"
        )

        if refreshHandoffCoordinator.activeHandoff != .containerHost(index: index) {
            let handoff = refreshHandoffCoordinator.tryBeginHandoff(
                headerIsExpanded: true,
                childIsAtTop: true,
                index: index
            )
            if handoff != nil {
                updateHeaderHostPlacement(reason: .refresh)
            }
        }

        containerRefreshHostScrollViewStorage.setRefreshOverscrollOffsetY(hostOffsetY)
    }

    private func shouldKeepChildOwnedPanAtTopBoundary(index: Int, scrollView: UIScrollView) -> Bool {
        guard containerRefreshHostRejectedChildGestureIndex == index,
              refreshHandoffCoordinator.activeHandoff == nil,
              containerRefreshProxyOverscrollOffsetY >= 0,
              scrollView.isTracking || scrollView.isDragging else {
            return false
        }

        // 同一 child 手势中 container pan 已拒绝接管时，不再中途开启 proxy handoff。
        // 否则 child 的 top bounce 会和 idle host 的程序化 offset 更新互相校正。
        return true
    }

    private func shouldKeepIdleChildOverscrollAtTopBoundary(scrollView: UIScrollView) -> Bool {
        guard refreshHandoffCoordinator.activeHandoff == nil,
              containerRefreshProxyOverscrollOffsetY >= 0,
              !scrollView.isTracking,
              !scrollView.isDragging,
              !scrollView.isDecelerating,
              !containerRefreshHostScrollViewStorage.isTracking,
              !containerRefreshHostScrollViewStorage.isDragging,
              !containerRefreshHostScrollViewStorage.isDecelerating else {
            return false
        }

        // 空闲或程序性 child offset 回调不代表新的下拉刷新手势。
        // 只夹回 managed top boundary，避免创建孤立的 container proxy。
        return true
    }

    @discardableResult
    private func cancelProxiedContainerRefreshHandoffIfNeeded(
        reason: String,
        sourceScrollView: UIScrollView
    ) -> Bool {
        let hasContainerHandoff: Bool
        if case .containerHost(index: _)? = refreshHandoffCoordinator.activeHandoff {
            hasContainerHandoff = true
        } else {
            hasContainerHandoff = false
        }

        let hasHostOverscroll =
            containerRefreshHostScrollViewStorage.contentOffset.y < containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY

        guard hasContainerHandoff || hasHostOverscroll else {
            return false
        }

        guard containerRefreshHostScrollViewStorage.usesNeutralRefreshContentInset() else {
            debugPullDownLog(
                "childProxy cancelSkipped reason=\(reason) childOffsetY=\(debugNumber(sourceScrollView.contentOffset.y)) hostOffsetY=\(debugNumber(containerRefreshHostScrollViewStorage.contentOffset.y)) baselineY=\(debugNumber(containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY)) proxyY=\(debugNumber(containerRefreshProxyOverscrollOffsetY)) insetTop=\(debugNumber(containerRefreshHostScrollViewStorage.contentInset.top))"
            )
            return false
        }

        debugPullDownLog(
            "childProxy cancel reason=\(reason) childOffsetY=\(debugNumber(sourceScrollView.contentOffset.y)) hostOffsetY=\(debugNumber(containerRefreshHostScrollViewStorage.contentOffset.y)) baselineY=\(debugNumber(containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY)) proxyY=\(debugNumber(containerRefreshProxyOverscrollOffsetY)) activeHandoff=\(String(describing: refreshHandoffCoordinator.activeHandoff))"
        )
        refreshHandoffCoordinator.resetGesture()
        containerRefreshProxyOverscrollOffsetY = 0
        containerRefreshHostRejectedChildGestureIndex = nil
        isRoutingContainerHostUpwardPanToChild = false
        containerRefreshHostScrollViewStorage.setContentOffset(
            CGPoint(x: 0, y: containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY),
            animated: false
        )
        updateHeaderHostPlacement(reason: .currentChild)
        return true
    }

    private func finishProxiedContainerRefreshHandoffIfPossible(forChildAt index: Int) {
        guard let record = loadedChildRecords[index] else {
            return
        }

        finishProxiedContainerRefreshHandoffIfPossible(sourceScrollView: record.scrollView)
    }

    private func finishProxiedContainerRefreshHandoffIfPossible(sourceScrollView: UIScrollView) {
        let hasContainerOverscroll =
            containerRefreshHostScrollViewStorage.contentOffset.y < containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY ||
            containerRefreshProxyOverscrollOffsetY < 0

        if releaseProxiedContainerRefreshOverscrollToExternalInsetIfNeeded() {
            return
        }

        guard case .containerHost(index: _)? = refreshHandoffCoordinator.activeHandoff,
              hasContainerOverscroll,
              !sourceScrollView.isTracking,
              !sourceScrollView.isDragging,
              !sourceScrollView.isDecelerating,
              !containerRefreshHostScrollViewStorage.isTracking,
              !containerRefreshHostScrollViewStorage.isDragging,
              !containerRefreshHostScrollViewStorage.isDecelerating,
              containerRefreshHostScrollViewStorage.usesNeutralRefreshContentInset() else {
            return
        }

        debugPullDownLog(
            "childProxy finishReset childOffsetY=\(debugNumber(sourceScrollView.contentOffset.y)) hostOffsetY=\(debugNumber(containerRefreshHostScrollViewStorage.contentOffset.y)) baselineY=\(debugNumber(containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY)) proxyY=\(debugNumber(containerRefreshProxyOverscrollOffsetY))"
        )
        refreshHandoffCoordinator.resetGesture()
        containerRefreshProxyOverscrollOffsetY = 0
        containerRefreshHostRejectedChildGestureIndex = nil
        isRoutingContainerHostUpwardPanToChild = false
        containerRefreshHostScrollViewStorage.setContentOffset(
            CGPoint(x: 0, y: containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY),
            animated: false
        )
        updateHeaderHostPlacement(reason: .currentChild)
    }

    private func finishContainerRefreshHostHandoffIfPossible(sourceScrollView: UIScrollView) {
        guard case .containerHost(index: _)? = refreshHandoffCoordinator.activeHandoff,
              sourceScrollView.contentOffset.y >= containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY,
              containerRefreshProxyOverscrollOffsetY >= 0,
              !sourceScrollView.isTracking,
              !sourceScrollView.isDragging,
              !sourceScrollView.isDecelerating,
              containerRefreshHostScrollViewStorage.usesNeutralRefreshContentInset() else {
            return
        }

        debugPullDownLog(
            "containerHandoff finishFromHost offsetY=\(debugNumber(sourceScrollView.contentOffset.y)) baselineY=\(debugNumber(containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY)) proxyY=\(debugNumber(containerRefreshProxyOverscrollOffsetY)) tracking=\(sourceScrollView.isTracking)/\(sourceScrollView.isDragging)/\(sourceScrollView.isDecelerating)"
        )
        refreshHandoffCoordinator.resetGesture()
        containerRefreshProxyOverscrollOffsetY = 0
        containerRefreshHostRejectedChildGestureIndex = nil
        isRoutingContainerHostUpwardPanToChild = false
        updateHeaderHostPlacement(reason: .currentChild)
    }

    private func syncVerticalScrollCoordinatorRecords() {
        verticalScrollCoordinator.replaceRecords(
            loadedChildRecords.values.sorted { $0.index < $1.index },
            currentIndex: state.effectiveSelectedIndex,
            syncEligibleIndexes: []
        )
        updateScrollsToTopOwnership()
    }

    private func updateScrollsToTopOwnership() {
        pageContainer.scrollView.scrollsToTop = false

        guard state.pageCount > 0,
              let currentIndex = state.effectiveSelectedIndex,
              let output = currentLayoutOutput else {
            containerRefreshHostScrollViewStorage.scrollsToTop = false
            containerRefreshHostScrollViewStorage.setStatusBarScrollToTopActivationEnabled(false)
            for record in loadedChildRecords.values {
                record.scrollView.scrollsToTop = false
            }
            return
        }

        let isPinned = output.collapseProgress >= 1
        containerRefreshHostScrollViewStorage.scrollsToTop = !isPinned
        containerRefreshHostScrollViewStorage.setStatusBarScrollToTopActivationEnabled(
            output.collapseProgress > 0 && !isPinned
        )
        for record in loadedChildRecords.values {
            record.scrollView.scrollsToTop = isPinned && record.index == currentIndex
        }
    }

    private func handleContainerScrollsToTopRequest(_ scrollView: UIScrollView) -> Bool {
        guard scrollView === containerRefreshHostScrollViewStorage,
              let currentIndex = state.effectiveSelectedIndex,
              let record = loadedChildRecords[currentIndex],
              let output = currentLayoutOutput,
              output.collapseProgress < 1 else {
            return false
        }

        let expandedOffsetY = -output.childContentInset.top
        if abs(record.scrollView.contentOffset.y - expandedOffsetY) >= 0.5 {
            // 未吸顶时由容器 host 作为状态栏顶滚 owner；V1 的 PinAnchor 仍由当前 child offset 表达。
            record.scrollView.setContentOffset(
                CGPoint(x: record.scrollView.contentOffset.x, y: expandedOffsetY),
                animated: true
            )
        }
        return false
    }

    private func restoreContainerRefreshProxyOverscrollIfNeeded() {
        guard containerRefreshProxyOverscrollOffsetY < 0 else {
            return
        }

        containerRefreshHostScrollViewStorage.setRefreshOverscrollOffsetY(containerRefreshProxyOverscrollOffsetY)
    }

    private func restoreContainerRefreshProxyOverscrollIfNeeded(for scrollView: UIScrollView) -> Bool {
        guard containerRefreshProxyOverscrollOffsetY < 0,
              containerRefreshHostScrollViewStorage.usesNeutralRefreshContentInset() else {
            return false
        }

        let expectedOffsetY = containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY
            + containerRefreshProxyOverscrollOffsetY
        guard abs(scrollView.contentOffset.y - expectedOffsetY) >= 0.5 else {
            return false
        }

        // child 已把 overscroll 交给 container host 后，proxy offset 是 reveal 的源值；
        // idle host 被 UIKit 暂时校正回 baseline 时必须恢复，否则整体内容会回跳。
        debugPullDownLog(
            "hostRestoreProxy currentOffsetY=\(debugNumber(scrollView.contentOffset.y)) expectedOffsetY=\(debugNumber(expectedOffsetY)) baselineY=\(debugNumber(containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY)) proxyY=\(debugNumber(containerRefreshProxyOverscrollOffsetY))"
        )
        containerRefreshHostScrollViewStorage.setRefreshOverscrollOffsetY(containerRefreshProxyOverscrollOffsetY)
        return true
    }

    @discardableResult
    private func releaseProxiedContainerRefreshOverscrollToExternalInsetIfNeeded() -> Bool {
        guard containerRefreshProxyOverscrollOffsetY < 0,
              !containerRefreshHostScrollViewStorage.usesNeutralRefreshContentInset() else {
            return false
        }

        debugPullDownLog(
            "childProxy releaseProxyToExternalInset hostOffsetY=\(debugNumber(containerRefreshHostScrollViewStorage.contentOffset.y)) baselineY=\(debugNumber(containerRefreshHostScrollViewStorage.neutralBaselineContentOffsetY)) proxyY=\(debugNumber(containerRefreshProxyOverscrollOffsetY)) insetTop=\(debugNumber(containerRefreshHostScrollViewStorage.contentInset.top)) activeHandoff=\(String(describing: refreshHandoffCoordinator.activeHandoff))"
        )
        containerRefreshProxyOverscrollOffsetY = 0
        containerRefreshHostRejectedChildGestureIndex = nil
        isRoutingContainerHostUpwardPanToChild = false
        updateHeaderHostPlacement(reason: refreshHandoffCoordinator.activeHandoff == nil ? .currentChild : .refresh)
        return true
    }

    private func shouldSuppressChildScrollIndicators(for position: PagePosition?) -> Bool {
        guard let position else {
            return false
        }

        return position.isInteractive || position.progress > 0
    }

    private func updateChildScrollIndicatorSuppression(_ isSuppressed: Bool) {
        guard isSuppressingChildScrollIndicatorsForHorizontalPaging != isSuppressed else {
            return
        }

        isSuppressingChildScrollIndicatorsForHorizontalPaging = isSuppressed
        for record in loadedChildRecords.values {
            applyChildScrollIndicatorSuppression(to: record)
        }
    }

    private func applyChildScrollIndicatorSuppression(to record: CollapsiblePagerChildRecord) {
        record.scrollView.showsVerticalScrollIndicator = isSuppressingChildScrollIndicatorsForHorizontalPaging
            ? false
            : record.baseShowsVerticalScrollIndicator
        record.scrollView.showsHorizontalScrollIndicator = isSuppressingChildScrollIndicatorsForHorizontalPaging
            ? false
            : record.baseShowsHorizontalScrollIndicator
    }

    private func restorePreservedContentOffsetIfNeeded(
        for record: CollapsiblePagerChildRecord,
        managedTopInset: CGFloat,
        pinThreshold: CGFloat
    ) {
        guard let preservedOffsetY = preservedContentOffsetYByIndex[record.index] else {
            return
        }

        let pinAnchorY = state.pinAnchorY.clamped(to: 0...pinThreshold)
        let minimumOffsetYForCurrentPin = pinAnchorY - managedTopInset
        let restoredOffsetY = max(preservedOffsetY, minimumOffsetYForCurrentPin)
        verticalScrollCoordinator.setContentOffsetY(restoredOffsetY, for: record.scrollView)
        let actualOffsetY = record.scrollView.contentOffset.y
        record.lastKnownContentOffsetY = actualOffsetY
        if actualOffsetY == restoredOffsetY {
            preservedContentOffsetYByIndex[record.index] = nil
        } else {
            preservedContentOffsetYByIndex[record.index] = restoredOffsetY
        }
    }

    private func restorePreservedContentOffsetForCurrentLayoutIfNeeded(_ record: CollapsiblePagerChildRecord) {
        guard let currentLayoutOutput else {
            return
        }

        restorePreservedContentOffsetIfNeeded(
            for: record,
            managedTopInset: currentLayoutOutput.childContentInset.top,
            pinThreshold: currentLayoutOutput.pinThreshold
        )
    }

    private func syncPreservedContentOffsets(by offsetDeltaY: CGFloat, minimumOffsetY explicitMinimumOffsetY: CGFloat? = nil) {
        guard offsetDeltaY != 0 else {
            return
        }

        let minimumOffsetY = explicitMinimumOffsetY
            ?? -(currentLayoutOutput?.childContentInset.top ?? managedTopInsetForChildren())
        for (index, offsetY) in preservedContentOffsetYByIndex {
            preservedContentOffsetYByIndex[index] = max(offsetY + offsetDeltaY, minimumOffsetY)
        }
    }

    private func alignCurrentChildOffsetToPinAnchor() {
        tabSelectionOffsetLock = nil
        guard let currentIndex = state.effectiveSelectedIndex,
              let record = loadedChildRecords[currentIndex],
              let currentLayoutOutput else {
            return
        }

        let pinAnchorY = state.pinAnchorY.clamped(to: 0...currentLayoutOutput.pinThreshold)
        let targetOffsetY = pinAnchorY - currentLayoutOutput.childContentInset.top
        let currentOffsetY = record.scrollView.contentOffset.y
        // 新 current child 只在低于当前 PinAnchor 要求时补齐；已经滚得更深的页面保留自己的列表位置。
        guard currentOffsetY < targetOffsetY else {
            return
        }

        verticalScrollCoordinator.setContentOffsetY(targetOffsetY, for: record.scrollView)
        record.lastKnownContentOffsetY = targetOffsetY
        preservedContentOffsetYByIndex[currentIndex] = record.scrollView.contentOffset.y
    }

    private func prepareUnvisitedTargetChildForTabTapIfNeeded(at index: Int, source: PageRequestSource) {
        guard source == .tabTap,
              !visitedPageIndexes.contains(index),
              let record = loadedChildRecords[index],
              let currentLayoutOutput else {
            return
        }

        let pinAnchorY = state.pinAnchorY.clamped(to: 0...currentLayoutOutput.pinThreshold)
        let targetOffsetY = pinAnchorY - currentLayoutOutput.childContentInset.top
        verticalScrollCoordinator.setContentOffsetY(targetOffsetY, for: record.scrollView)
        record.lastKnownContentOffsetY = record.scrollView.contentOffset.y
    }

    private func preservePinAnchorForCurrentChildAfterTabSelection() {
        guard let currentIndex = state.effectiveSelectedIndex,
              let record = loadedChildRecords[currentIndex],
              let currentLayoutOutput else {
            return
        }

        let pinAnchorY = state.pinAnchorY.clamped(to: 0...currentLayoutOutput.pinThreshold)
        let insetTop = currentLayoutOutput.childContentInset.top
        let currentOffsetY = record.scrollView.contentOffset.y
        let currentChildPinAnchorY = (currentOffsetY + insetTop)
            .clamped(to: 0...currentLayoutOutput.pinThreshold)

        // Tab 切换共享同一个 Header 位置。目标页只有在当前已经吸顶且自己也超过吸顶阈值时，
        // 才保留更深的列表 offset；其他情况都校准到当前 PinAnchor，避免点击 Tab 时 Header 跳动。
        let pinTolerance: CGFloat = 0.5
        let isCurrentPinned = pinAnchorY >= currentLayoutOutput.pinThreshold - pinTolerance
        let isChildPinned = currentChildPinAnchorY >= currentLayoutOutput.pinThreshold - pinTolerance
        let canPreserveDeepOffset = isCurrentPinned && isChildPinned
        if !canPreserveDeepOffset {
            let targetOffsetY = pinAnchorY - insetTop
            verticalScrollCoordinator.setContentOffsetY(targetOffsetY, for: record.scrollView)
            tabSelectionOffsetLock = TabSelectionOffsetLock(
                index: currentIndex,
                offsetY: record.scrollView.contentOffset.y,
                pinAnchorY: pinAnchorY
            )
        } else {
            tabSelectionOffsetLock = nil
        }

        state.pinAnchorY = pinAnchorY
        verticalScrollCoordinator.setPinAnchorY(pinAnchorY)
        record.lastKnownContentOffsetY = record.scrollView.contentOffset.y
        preservedContentOffsetYByIndex[currentIndex] = record.scrollView.contentOffset.y
        applyLayout()
    }

    private func adoptPinAnchorFromCurrentChildOffset() {
        tabSelectionOffsetLock = nil
        guard let currentIndex = state.effectiveSelectedIndex,
              let record = loadedChildRecords[currentIndex],
              let currentLayoutOutput else {
            return
        }

        let pinAnchorY = (record.scrollView.contentOffset.y + currentLayoutOutput.childContentInset.top)
            .clamped(to: 0...currentLayoutOutput.pinThreshold)
        state.pinAnchorY = pinAnchorY
        verticalScrollCoordinator.setPinAnchorY(pinAnchorY)
        record.lastKnownContentOffsetY = record.scrollView.contentOffset.y
        preservedContentOffsetYByIndex[currentIndex] = record.scrollView.contentOffset.y
        applyLayout()
    }

    private func updateLoadedChildWindowIfNeeded() {
        guard let currentIndex = state.effectiveSelectedIndex else {
            return
        }

        updateLoadedChildWindow(centeredAt: currentIndex)
    }

    private func updateLoadedChildWindow(centeredAt currentIndex: Int) {
        let retainedIndexes = retainedChildIndexes(centeredAt: currentIndex)
        for index in retainedIndexes.sorted() {
            _ = loadChildIfNeeded(at: index)
        }

        let transitionIndexes = activePageAppearanceTransition.map { Set([$0.fromIndex, $0.toIndex]) } ?? []
        for index in Array(loadedChildRecords.keys) where !retainedIndexes.contains(index) && !transitionIndexes.contains(index) {
            unloadChild(at: index)
        }
        for index in pageContainer.loadedPageIndexes where !retainedIndexes.contains(index) && !transitionIndexes.contains(index) {
            pageContainer.removePageView(at: index)
        }

        syncVerticalScrollCoordinatorRecords()
    }

    private func retainedChildIndexes(centeredAt currentIndex: Int) -> Set<Int> {
        guard state.pageCount > 0 else {
            return []
        }

        let lowerBound = max(0, currentIndex - loadedChildWindowRadius)
        let upperBound = min(state.pageCount - 1, currentIndex + loadedChildWindowRadius)
        return Set(lowerBound...upperBound)
    }

    private func scrollToRequestedPage(at index: Int, animated: Bool) {
        debugPagingLog(
            "scrollToRequestedPage target=\(index) animated=\(animated) \(debugPagingState()) position=\(debugPagePosition(state.pagePosition))"
        )
        guard animated else {
            pageContainer.scrollToPage(at: index, animated: false)
            return
        }

        isStartingAnimatedPageScroll = true
        pageContainer.scrollToPage(at: index, animated: true)
        isStartingAnimatedPageScroll = false
    }

    private func shouldAnimatePageScroll(from sourceIndex: Int, to targetIndex: Int, animated: Bool) -> Bool {
        // 跨多页跳转采用 source/target 语义，避免 contentOffset 扫过未加载的中间页。
        animated && abs(targetIndex - sourceIndex) == 1
    }

    private func shouldAnimateChildAppearanceTransition(
        source: PageRequestSource,
        from sourceIndex: Int,
        to targetIndex: Int,
        requestedAnimated: Bool
    ) -> Bool {
        switch source {
        case .tabTap:
            return requestedAnimated && abs(targetIndex - sourceIndex) == 1
        case .api, .gesture:
            return requestedAnimated
        }
    }

    private func prepareInteractivePageTransitionIfNeeded(for position: PagePosition?) {
        guard let position,
              position.isInteractive,
              let fromIndex = state.effectiveSelectedIndex,
              let targetIndex = interactiveTargetIndex(for: position, currentIndex: fromIndex),
              state.pendingSelectedIndex != targetIndex else {
            return
        }

        let request = PageRequest(source: .gesture, fromIndex: fromIndex, targetIndex: targetIndex, animated: true)
        guard pageRequestPipeline.request(request, state: &state) else {
            debugPagingLog(
                "gestureRequest rejected from=\(fromIndex) target=\(targetIndex) position={\(debugPagePosition(position))} \(debugPagingState())"
            )
            return
        }

        debugPagingLog(
            "gestureRequest accepted from=\(fromIndex) target=\(targetIndex) position={\(debugPagePosition(position))} \(debugPagingState())"
        )
        _ = loadChildIfNeeded(at: targetIndex)
        beginPageAppearanceTransitionForNewRequest(to: targetIndex, animated: true)
    }

    private func interactiveTargetIndex(for position: PagePosition, currentIndex: Int) -> Int? {
        guard position.progress > 0 else {
            return nil
        }

        if position.rawPosition > CGFloat(currentIndex) {
            return position.toIndex
        }
        if position.rawPosition < CGFloat(currentIndex) {
            return position.fromIndex
        }
        return nil
    }

    private func beginCurrentChildAppearanceTransition(appearing: Bool, animated: Bool) {
        guard let index = state.effectiveSelectedIndex,
              let record = loadedChildRecords[index] else {
            return
        }

        parentAppearanceForwardedChildIndex = index
        record.viewController.beginAppearanceTransition(appearing, animated: animated)
    }

    private func endCurrentChildAppearanceTransition(didAppear: Bool) {
        guard let index = parentAppearanceForwardedChildIndex,
              let record = loadedChildRecords[index] else {
            parentAppearanceForwardedChildIndex = nil
            return
        }

        record.viewController.endAppearanceTransition()
        if didAppear {
            appearedChildIndex = index
        }
        parentAppearanceForwardedChildIndex = nil
    }

    private func beginPageAppearanceTransition(to targetIndex: Int, animated: Bool) {
        guard isPagerVisible,
              activePageAppearanceTransition == nil,
              let fromIndex = appearedChildIndex ?? state.effectiveSelectedIndex,
              fromIndex != targetIndex,
              let fromRecord = loadedChildRecords[fromIndex],
              let targetRecord = loadedChildRecords[targetIndex] else {
            return
        }

        activePageAppearanceTransition = PageAppearanceTransition(
            fromIndex: fromIndex,
            toIndex: targetIndex,
            animated: animated
        )
        fromRecord.viewController.beginAppearanceTransition(false, animated: animated)
        targetRecord.viewController.beginAppearanceTransition(true, animated: animated)
    }

    private func beginPageAppearanceTransitionForNewRequest(to targetIndex: Int, animated: Bool) {
        if let transition = activePageAppearanceTransition, transition.toIndex != targetIndex {
            finishPageAppearanceTransition(completedIndex: transition.fromIndex)
        }
        beginPageAppearanceTransition(to: targetIndex, animated: animated)
    }

    private func finishPageAppearanceTransition(completedIndex: Int) {
        guard let transition = activePageAppearanceTransition else {
            return
        }

        let fromRecord = loadedChildRecords[transition.fromIndex]
        let toRecord = loadedChildRecords[transition.toIndex]

        if completedIndex == transition.fromIndex {
            toRecord?.viewController.beginAppearanceTransition(false, animated: transition.animated)
            fromRecord?.viewController.beginAppearanceTransition(true, animated: transition.animated)
            toRecord?.viewController.endAppearanceTransition()
            fromRecord?.viewController.endAppearanceTransition()
        } else {
            fromRecord?.viewController.endAppearanceTransition()
            toRecord?.viewController.endAppearanceTransition()
        }
        appearedChildIndex = completedIndex
        activePageAppearanceTransition = nil
    }

    private func layoutInput() -> CollapsiblePagerLayoutInput {
        CollapsiblePagerLayoutInput(
            containerBounds: view.bounds,
            safeAreaInsets: CollapsiblePagerEdgeInsets(
                top: view.safeAreaInsets.top,
                left: view.safeAreaInsets.left,
                bottom: view.safeAreaInsets.bottom,
                right: view.safeAreaInsets.right
            ),
            bottomObstructionInset: bottomObstructionInset(),
            navigationBarMaxY: navigationBarMaxY(),
            headerHeights: headerHeights(),
            headerTopBehavior: configuration.header.topBehavior,
            tabBarHeight: configuration.tabBar.height,
            tabBarPlacement: configuration.tabBar.placement,
            tabBarPinning: configuration.tabBar.pinning,
            pinAnchorY: state.pinAnchorY
        )
    }

    private func headerHeights() -> CollapsiblePagerHeaderHeights {
        switch configuration.header.heightMode {
        case let .fixed(max, min):
            return CollapsiblePagerHeaderHeights(maxHeight: max, minHeight: min)
        }
    }

    private func currentAppliedHeaderHeights() -> CollapsiblePagerHeaderHeights {
        appliedHeaderHeights ?? headerHeights().normalized
    }

    private func managedTopInsetForChildren() -> CGFloat {
        currentLayoutOutput?.childContentInset.top ?? (headerHeights().normalized.maxHeight + max(0, configuration.tabBar.height))
    }

    private func navigationBarMaxY() -> CGFloat? {
        guard let navigationBar = navigationController?.navigationBar, !navigationBar.isHidden else {
            return nil
        }

        // navigationBar.frame 属于导航控制器坐标系，布局输入需要 pager.view 的本地坐标。
        return navigationBar.convert(navigationBar.bounds, to: view).maxY
    }

    private func bottomObstructionInset() -> CGFloat {
        var inset = max(0, view.safeAreaInsets.bottom)
        guard let tabBar = tabBarController?.tabBar,
              !tabBar.isHidden,
              tabBar.alpha > 0.01,
              view.window != nil,
              tabBar.window === view.window else {
            return inset
        }

        let tabBarFrame = tabBar.convert(tabBar.bounds, to: view)
        let intersection = view.bounds.intersection(tabBarFrame)
        guard !intersection.isNull, !intersection.isEmpty else {
            return inset
        }

        inset = max(inset, view.bounds.maxY - intersection.minY)
        return inset
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private struct PageAppearanceTransition {
    var fromIndex: Int
    var toIndex: Int
    var animated: Bool
}

private struct TabSelectionOffsetLock {
    var index: Int
    var offsetY: CGFloat
    var pinAnchorY: CGFloat
}
