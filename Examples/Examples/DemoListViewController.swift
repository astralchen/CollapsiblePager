import CollapsiblePager
import Refreshable
import UIKit

struct DemoLoadMoreConfiguration: Sendable, Equatable {
    var batchSize: Int
    var maximumAdditionalRows: Int
    var delayNanoseconds: UInt64
}

enum DemoLoadMoreFooterMetrics {
    static let contentSpacing: CGFloat = 8
    static let outerSpacing: CGFloat = 8
    static let crossAxisInset: CGFloat = 16
    static let defaultStyleExtent: CGFloat = 54

    static var reservedExtent: CGFloat {
        contentSpacing + defaultStyleExtent + outerSpacing
    }
}

@MainActor
final class DemoListPageState {
    let title: String
    let refreshTitle: String?
    let accessibilityID: String
    let loadMoreConfiguration: DemoLoadMoreConfiguration?
    private let initialRowCount: Int
    private var loadedAdditionalRows = 0
    var shouldRevealNoMoreFooter = false

    var rowCount: Int {
        initialRowCount + loadedAdditionalRows
    }

    var isLoadMoreExhausted: Bool {
        guard let loadMoreConfiguration else {
            return false
        }
        return loadedAdditionalRows >= loadMoreConfiguration.maximumAdditionalRows
    }

    init(
        title: String,
        rowCount: Int,
        refreshTitle: String?,
        loadMoreConfiguration: DemoLoadMoreConfiguration? = nil,
        accessibilityID: String
    ) {
        self.title = title
        self.initialRowCount = rowCount
        self.refreshTitle = refreshTitle
        self.loadMoreConfiguration = loadMoreConfiguration
        self.accessibilityID = accessibilityID
    }

    func appendLoadMoreRows() -> Bool {
        guard let loadMoreConfiguration else {
            return false
        }

        let remainingRows = max(loadMoreConfiguration.maximumAdditionalRows - loadedAdditionalRows, 0)
        guard remainingRows > 0 else {
            return false
        }

        loadedAdditionalRows += min(loadMoreConfiguration.batchSize, remainingRows)
        return true
    }
}

@MainActor
final class DemoListViewController: UITableViewController, CollapsiblePagerScrollProviding {
    private let pageState: DemoListPageState
    private let demoRefreshController = DemoRefreshController()
    private var isPageVisibleForLoadMore = false
    private var didRestoreNoMoreFooterVisibility = false
    private var pendingNoMoreFooterRestoreTask: Task<Void, Never>?

    var pagerScrollView: UIScrollView {
        tableView
    }

    convenience init(
        title: String,
        rowCount: Int,
        refreshTitle: String?,
        loadMoreConfiguration: DemoLoadMoreConfiguration? = nil,
        accessibilityID: String
    ) {
        self.init(
            state: DemoListPageState(
                title: title,
                rowCount: rowCount,
                refreshTitle: refreshTitle,
                loadMoreConfiguration: loadMoreConfiguration,
                accessibilityID: accessibilityID
            )
        )
    }

    init(state: DemoListPageState) {
        self.pageState = state
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        pendingNoMoreFooterRestoreTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.accessibilityIdentifier = pageState.accessibilityID
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        if let refreshTitle = pageState.refreshTitle {
            demoRefreshController.attach(to: tableView, title: refreshTitle)
        }
        if pageState.loadMoreConfiguration != nil {
            configureLoadMore()
        }
        configureEmptyState()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateEmptyStateLayout()
        ensureNoMoreFooterClearsBottomObstructionIfNeeded()
        scheduleNoMoreFooterRestoreIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isPageVisibleForLoadMore = true
        restoreNoMoreFooterVisibilityIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        captureNoMoreFooterVisibility()
        super.viewWillDisappear(animated)
        isPageVisibleForLoadMore = false
        pendingNoMoreFooterRestoreTask?.cancel()
        pendingNoMoreFooterRestoreTask = nil
        if pageState.loadMoreConfiguration != nil {
            tableView.endLoadingMore()
        }
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateEmptyStateLayout()
        restoreNoMoreFooterVisibilityIfNeeded()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        pageState.rowCount
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = "\(pageState.title) row \(indexPath.row + 1)"
        cell.detailTextLabel?.text = nil
        cell.accessibilityIdentifier = "\(pageState.accessibilityID)-row-\(indexPath.row)"
        cell.selectionStyle = .none
        return cell
    }

    private func configureEmptyState() {
        guard pageState.rowCount == 0 else {
            tableView.backgroundView = nil
            return
        }

        tableView.backgroundView = DemoEmptyStateBackgroundView(
            text: "No rows in Empty",
            accessibilityIdentifier: "\(pageState.accessibilityID)-empty"
        )
        updateEmptyStateLayout()
    }

    private func updateEmptyStateLayout() {
        guard let emptyStateView = tableView.backgroundView as? DemoEmptyStateBackgroundView else {
            return
        }

        emptyStateView.frame = tableView.bounds
        let visibleTopY = max(0, min(-tableView.contentOffset.y, tableView.bounds.height))
        let bottomObstruction = max(0, tableView.verticalScrollIndicatorInsets.bottom)
        let visibleBottomY = max(visibleTopY, tableView.bounds.height - bottomObstruction)
        emptyStateView.visibleContentFrame = CGRect(
            x: tableView.bounds.minX,
            y: visibleTopY,
            width: tableView.bounds.width,
            height: visibleBottomY - visibleTopY
        )
    }

    private func configureLoadMore() {
        let options = RefreshableOptions(
            triggerOffset: 72,
            animationDuration: 0.25,
            automaticallyEndRefreshing: false,
            allowsLoadMoreWhenContentFits: false,
            automaticTriggerOffset: nil,
            placement: RefreshablePlacement(
                contentSpacing: DemoLoadMoreFooterMetrics.contentSpacing,
                outerSpacing: DemoLoadMoreFooterMetrics.outerSpacing,
                crossAxisInset: DemoLoadMoreFooterMetrics.crossAxisInset
            )
        )

        tableView.loadMoreable(options: options) { [weak self] in
            await self?.performLoadMore()
        }
        if pageState.isLoadMoreExhausted {
            markNoMoreData()
        }
    }

    private func performLoadMore() async {
        guard let loadMoreConfiguration = pageState.loadMoreConfiguration else {
            return
        }

        if loadMoreConfiguration.delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: loadMoreConfiguration.delayNanoseconds)
        }
        guard !Task.isCancelled else {
            return
        }
        guard isPageVisibleForLoadMore else {
            tableView.endLoadingMore()
            return
        }

        appendRows()
    }

    private func appendRows() {
        guard pageState.appendLoadMoreRows() else {
            markNoMoreData()
            return
        }

        tableView.reloadData()
        configureEmptyState()

        if pageState.isLoadMoreExhausted {
            markNoMoreData()
        } else {
            tableView.endLoadingMore()
        }
    }

    private func markNoMoreData() {
        pageState.shouldRevealNoMoreFooter = true
        didRestoreNoMoreFooterVisibility = false
        tableView.noMoreData()
        ensureNoMoreFooterClearsBottomObstructionIfNeeded()
        restoreNoMoreFooterVisibilityIfNeeded()
    }

    private func ensureNoMoreFooterClearsBottomObstructionIfNeeded() {
        guard pageState.isLoadMoreExhausted else {
            return
        }

        let bottomObstruction = max(0, tableView.verticalScrollIndicatorInsets.bottom)
        let requiredBottomInset = bottomObstruction + DemoLoadMoreFooterMetrics.reservedExtent
        guard requiredBottomInset.isFinite,
              tableView.contentInset.bottom + 0.5 < requiredBottomInset else {
            return
        }

        var contentInset = tableView.contentInset
        contentInset.bottom = requiredBottomInset
        tableView.contentInset = contentInset
    }

    private func scheduleNoMoreFooterRestoreIfNeeded() {
        guard pageState.isLoadMoreExhausted,
              pageState.shouldRevealNoMoreFooter,
              !didRestoreNoMoreFooterVisibility,
              pendingNoMoreFooterRestoreTask == nil else {
            return
        }

        pendingNoMoreFooterRestoreTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled else {
                return
            }
            self?.pendingNoMoreFooterRestoreTask = nil
            self?.restoreNoMoreFooterVisibilityIfNeeded()
        }
    }

    private func restoreNoMoreFooterVisibilityIfNeeded() {
        guard pageState.isLoadMoreExhausted,
              pageState.shouldRevealNoMoreFooter,
              !didRestoreNoMoreFooterVisibility,
              (isPageVisibleForLoadMore || view.window != nil),
              tableView.bounds.height > 0 else {
            return
        }

        ensureNoMoreFooterClearsBottomObstructionIfNeeded()
        let targetOffsetY = maximumNoMoreFooterOffsetY()
        guard targetOffsetY.isFinite else {
            return
        }

        didRestoreNoMoreFooterVisibility = true
        pendingNoMoreFooterRestoreTask?.cancel()
        pendingNoMoreFooterRestoreTask = nil
        guard tableView.contentOffset.y + 0.5 < targetOffsetY else {
            return
        }

        tableView.setContentOffset(
            CGPoint(x: tableView.contentOffset.x, y: targetOffsetY),
            animated: false
        )
    }

    private func captureNoMoreFooterVisibility() {
        guard pageState.isLoadMoreExhausted,
              tableView.bounds.height > 0 else {
            return
        }

        let targetOffsetY = maximumNoMoreFooterOffsetY()
        guard targetOffsetY.isFinite else {
            return
        }

        pageState.shouldRevealNoMoreFooter = tableView.contentOffset.y >= targetOffsetY - 8
    }

    private func maximumNoMoreFooterOffsetY() -> CGFloat {
        max(
            -tableView.contentInset.top,
            tableView.contentSize.height + tableView.contentInset.bottom - tableView.bounds.height
        )
    }

    func beginLoadingMoreForTesting() {
        tableView.beginLoadingMore()
    }
}

@MainActor
private final class DemoEmptyStateBackgroundView: UIView {
    private let label = UILabel()
    var visibleContentFrame: CGRect = .zero {
        didSet {
            setNeedsLayout()
        }
    }

    init(text: String, accessibilityIdentifier: String) {
        super.init(frame: .zero)
        self.accessibilityIdentifier = "demo-list-empty-background"
        label.text = text
        label.accessibilityIdentifier = accessibilityIdentifier
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let contentFrame = effectiveVisibleContentFrame()
        let maximumLabelWidth = max(0, contentFrame.width - 48)
        let fittingSize = label.sizeThatFits(
            CGSize(width: maximumLabelWidth, height: CGFloat.greatestFiniteMagnitude)
        )
        let labelSize = CGSize(
            width: min(maximumLabelWidth, fittingSize.width),
            height: fittingSize.height
        )
        label.frame = CGRect(
            x: contentFrame.midX - labelSize.width / 2,
            y: contentFrame.midY - labelSize.height / 2,
            width: labelSize.width,
            height: labelSize.height
        )
    }

    private func effectiveVisibleContentFrame() -> CGRect {
        let candidate = visibleContentFrame.isEmpty ? bounds : visibleContentFrame.intersection(bounds)
        guard !candidate.isNull, !candidate.isEmpty else {
            return bounds
        }
        return candidate
    }
}
