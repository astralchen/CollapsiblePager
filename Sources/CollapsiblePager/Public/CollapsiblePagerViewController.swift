import UIKit

/// 可折叠 Header、TabBar 与多 child 页面的 UIKit 容器。
///
/// V1 容器 API 均在 `MainActor` 上使用。`selectedIndex` 保持 UIKit 常见默认值语义，
/// 即使当前没有页面也为 `0`；是否存在有效页面选择请读取 `effectiveSelectedIndex`。
@MainActor
public final class CollapsiblePagerViewController: UIViewController {
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

            tabBarView.apply(configuration: configuration.tabBar)
            pageContainer.apply(paging: configuration.paging)
            applyLayout()
        }
    }

    /// 对外默认选择索引。没有页面时仍为 `0`。
    public private(set) var selectedIndex: Int = 0

    /// 当前是否存在有效页面选择。没有页面时为 `nil`。
    public private(set) var effectiveSelectedIndex: Int?

    private let layoutEngine = CollapsiblePagerLayoutEngine()
    private let pageRequestPipeline = PageRequestPipeline()
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
    private var isStartingAnimatedPageScroll = false
    private var isPagerVisible = false
    private var parentAppearanceForwardedChildIndex: Int?
    private var appearedChildIndex: Int?
    private var activePageAppearanceTransition: PageAppearanceTransition?
    private var isSuppressingChildScrollIndicatorsForHorizontalPaging = false
    private let loadedChildWindowRadius = 1

    /// 创建容器。
    public init(configuration: CollapsiblePagerConfiguration = .default) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable, message: "Use init(configuration:) instead.")
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        configureViewHierarchy()
    }

    public override var shouldAutomaticallyForwardAppearanceMethods: Bool {
        false
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        beginCurrentChildAppearanceTransition(appearing: true, animated: animated)
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        endCurrentChildAppearanceTransition(didAppear: true)
        isPagerVisible = true
        appearedChildIndex = state.effectiveSelectedIndex
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isPagerVisible = false
        beginCurrentChildAppearanceTransition(appearing: false, animated: animated)
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        endCurrentChildAppearanceTransition(didAppear: false)
        appearedChildIndex = nil
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyLayout()
    }

    /// 从 data source 重新加载 Header、TabBar 和当前有效页面。
    public func reloadData() {
        loadViewIfNeeded()

        let rawPageCount = dataSource?.numberOfPages(in: self) ?? 0
        let nextPageCount = max(0, rawPageCount)
        let previousSelection = effectiveSelectedIndex ?? selectedIndex

        removeLoadedChildren()
        isSuppressingChildScrollIndicatorsForHorizontalPaging = false
        preservedContentOffsetYByIndex.removeAll()
        pageContainer.removeAllPageViews()
        pageContainer.setPageCount(nextPageCount)
        updateStateForReload(pageCount: nextPageCount, previousSelection: previousSelection)
        syncPublicSelectionFromState()

        guard nextPageCount > 0, let dataSource else {
            tabBarView.reloadTitles([])
            tabBarView.update(position: nil)
            headerHostCoordinator.clearContent()
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
            headerHostCoordinator.setContent(dataSource.headerContent(in: self), initialContainer: fixedHeaderContainer)
        }

        applyLayout()
        updateLoadedChildWindowIfNeeded()
    }

    /// 请求选择页面。
    public func selectPage(at index: Int, animated: Bool) {
        requestPageSelection(at: index, source: .api, animated: animated)
    }

    private func requestPageSelection(at index: Int, source: PageRequestSource, animated: Bool) {
        guard let fromIndex = state.effectiveSelectedIndex else {
            return
        }

        let request = PageRequest(source: source, fromIndex: fromIndex, targetIndex: index, animated: animated)
        guard pageRequestPipeline.request(request, state: &state) else {
            return
        }

        tabBarView.update(position: state.pagePosition)
        _ = loadChildIfNeeded(at: index)
        beginPageAppearanceTransition(
            to: index,
            animated: shouldAnimateChildAppearanceTransition(
                source: source,
                from: fromIndex,
                to: index,
                requestedAnimated: animated
            )
        )
        let shouldAnimateScroll = shouldAnimatePageScroll(from: fromIndex, to: index, animated: animated)
        scrollToRequestedPage(at: index, animated: shouldAnimateScroll)

        if !shouldAnimateScroll {
            completePageTransition(targetIndex: index)
        }
    }

    /// 重新测量 Header 布局。
    public func reloadHeaderLayout(offsetPolicy: CollapsiblePagerHeaderOffsetPolicy = .preserveVisualPosition) {
        applyLayout()
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

    func completePendingPageTransitionForTesting(targetIndex: Int) {
        completePageTransition(targetIndex: targetIndex)
    }

    func tapTabItemForTesting(at index: Int) {
        tabBarView.itemView(at: index)?.sendActions(for: .touchUpInside)
    }

    func updatePagePositionForTesting(_ position: PagePosition?) {
        handlePagePositionChanged(position)
    }

    private func configureViewHierarchy() {
        view.backgroundColor = .systemBackground

        pageContainer.onPagePositionChanged = { [weak self] position in
            self?.handlePagePositionChanged(position)
        }
        pageContainer.onPageTransitionCompleted = { [weak self] index in
            guard let self, !self.isStartingAnimatedPageScroll else {
                return
            }

            self.completePageTransition(targetIndex: index)
        }
        tabBarView.onRequestSelection = { [weak self] index in
            self?.requestPageSelection(at: index, source: .tabTap, animated: true)
        }
        tabBarView.apply(configuration: configuration.tabBar)
        pageContainer.apply(paging: configuration.paging)
        verticalScrollCoordinator.onPinAnchorChanged = { [weak self] result in
            self?.handlePinAnchorChanged(result)
        }

        view.addSubview(pageContainer)
        view.addSubview(pinnedSurfaceView)
        pinnedSurfaceView.addSubview(fixedHeaderContainer)
        pinnedSurfaceView.addSubview(tabBarView)
    }

    private func updateStateForReload(pageCount: Int, previousSelection: Int) {
        state = CollapsiblePagerState.initial(pageCount: pageCount)

        guard pageCount > 0 else {
            state.selectedIndex = 0
            state.effectiveSelectedIndex = nil
            state.pendingSelectedIndex = nil
            state.pagePosition = nil
            return
        }

        let clampedSelection = previousSelection.clamped(to: 0...(pageCount - 1))
        state.selectedIndex = clampedSelection
        state.effectiveSelectedIndex = clampedSelection
        state.pendingSelectedIndex = nil
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
        guard let record = childStore.makeRecord(
            for: child,
            index: index,
            managedTopInset: managedTopInset,
            managedBottomInset: currentLayoutOutput?.childContentInset.bottom ?? view.safeAreaInsets.bottom,
            pinThreshold: pinThreshold,
            initialPinAnchorY: state.pinAnchorY
        ) else {
            return nil
        }

        childStore.attach(record, to: pageView)
        loadedChildRecords[index] = record
        observeScrollView(for: record)
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
        for record in loadedChildRecords.values {
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
        preservedContentOffsetYByIndex[index] = record.scrollView.contentOffset.y
        childStore.detach(record)
        record.mountView.removeFromSuperview()
        loadedChildRecords[index] = nil
        pageContainer.removePageView(at: index)
    }

    private func handlePagePositionChanged(_ position: PagePosition?) {
        prepareInteractivePageTransitionIfNeeded(for: position)
        state.pagePosition = position
        verticalScrollCoordinator.isHorizontalPagingActive = position?.isInteractive == true
        updateChildScrollIndicatorSuppression(shouldSuppressChildScrollIndicators(for: position))
        tabBarView.update(position: position)
    }

    private func completePageTransition(targetIndex: Int) {
        let shouldNotifySelection = state.pendingSelectedIndex == targetIndex

        pageRequestPipeline.complete(targetIndex: targetIndex, state: &state)
        syncPublicSelectionFromState()
        tabBarView.update(position: state.pagePosition)
        _ = loadChildIfNeeded(at: targetIndex)
        finishPageAppearanceTransition(completedIndex: targetIndex)
        pageContainer.scrollToPage(at: targetIndex, animated: false)
        updateLoadedChildWindowIfNeeded()
        alignCurrentChildOffsetToPinAnchor()
        updateChildScrollIndicatorSuppression(false)

        if shouldNotifySelection, state.effectiveSelectedIndex == targetIndex {
            delegate?.pagerViewController(self, didSelectPageAt: targetIndex)
        }
    }

    private func applyLayout() {
        guard isViewLoaded else {
            return
        }

        let output = layoutEngine.layout(layoutInput())
        currentLayoutOutput = output
        pinnedSurfaceView.frame = view.bounds
        pageContainer.frame = output.pageContainerFrame
        fixedHeaderContainer.frame = output.headerFrame
        tabBarView.frame = output.tabBarFrame
        verticalScrollCoordinator.updateLayout(
            pinThreshold: output.pinThreshold,
            managedTopInset: output.childContentInset.top
        )
        updateLoadedChildrenForLayout(output)
        syncVerticalScrollCoordinatorRecords()

        view.bringSubviewToFront(pinnedSurfaceView)

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

    private func handleChildScrollViewDidScroll(_ scrollView: UIScrollView) {
        _ = verticalScrollCoordinator.handleScrollViewDidScroll(scrollView)
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
    }

    private func syncVerticalScrollCoordinatorRecords() {
        verticalScrollCoordinator.replaceRecords(
            loadedChildRecords.values.sorted { $0.index < $1.index },
            currentIndex: state.effectiveSelectedIndex
        )
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

    private func syncPreservedContentOffsets(by pinDeltaY: CGFloat) {
        guard pinDeltaY != 0 else {
            return
        }

        let minimumOffsetY = -(currentLayoutOutput?.childContentInset.top ?? managedTopInsetForChildren())
        for (index, offsetY) in preservedContentOffsetYByIndex {
            preservedContentOffsetYByIndex[index] = max(offsetY + pinDeltaY, minimumOffsetY)
        }
    }

    private func alignCurrentChildOffsetToPinAnchor() {
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
            return
        }

        _ = loadChildIfNeeded(at: targetIndex)
        beginPageAppearanceTransition(to: targetIndex, animated: true)
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

    private func managedTopInsetForChildren() -> CGFloat {
        currentLayoutOutput?.childContentInset.top ?? (headerHeights().normalized.maxHeight + max(0, configuration.tabBar.height))
    }

    private func navigationBarMaxY() -> CGFloat? {
        guard let navigationBar = navigationController?.navigationBar, !navigationBar.isHidden else {
            return nil
        }

        return navigationBar.frame.maxY
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
