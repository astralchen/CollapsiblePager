import CollapsiblePager
import UIKit

@MainActor
enum DemoPagerFactory {
    static func makeApplicationRoot(dataSource: DemoPagerDataSource) -> UITabBarController {
        let pager = makePager(dataSource: dataSource)
        pager.navigationItem.title = "CollapsiblePager"
        pager.navigationItem.largeTitleDisplayMode = .never

        let navigationController = DemoPagerNavigationController(rootPager: pager, rootDataSource: dataSource)
        navigationController.tabBarItem = makePagerTabBarItem()
        navigationController.navigationBar.prefersLargeTitles = false
        configurePushButton(for: pager, target: navigationController)

        let refreshHandoffModeController = DemoRefreshHandoffModeViewController()
        let refreshNavigationController = UINavigationController(rootViewController: refreshHandoffModeController)
        refreshNavigationController.navigationBar.prefersLargeTitles = false
        refreshNavigationController.tabBarItem = makeRefreshHandoffTabBarItem()

        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [navigationController, refreshNavigationController]
        tabBarController.view.accessibilityIdentifier = "demo-root-tab-bar"

        pager.reloadData()

        return tabBarController
    }

    static func makePager(dataSource: DemoPagerDataSource) -> CollapsiblePagerViewController {
        let pager = CollapsiblePagerViewController()
        pager.dataSource = dataSource
        pager.delegate = dataSource
        pager.view.accessibilityIdentifier = "demo-pager"

        dataSource.headerView.onReloadLayout = { [weak pager] in
            pager?.reloadHeaderLayout(offsetPolicy: .preserveVisualPosition)
        }
        dataSource.configureRefreshHost(for: pager)

        return pager
    }

    fileprivate static func configurePushButton(
        for pager: CollapsiblePagerViewController,
        target: DemoPagerNavigationController
    ) {
        pager.navigationItem.rightBarButtonItem = makePushPagerBarButtonItem(target: target)
    }

    private static func makePagerTabBarItem() -> UITabBarItem {
        UITabBarItem(
            title: "Pager",
            image: makePagerTabBarImage(isSelected: false),
            selectedImage: makePagerTabBarImage(isSelected: true)
        )
    }

    private static func makePagerTabBarImage(isSelected: Bool) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        let image = renderer.image { _ in
            UIColor.black.setStroke()
            UIColor.black.setFill()

            let rearRect = CGRect(x: 5, y: 5, width: 12, height: 10)
            let frontRect = CGRect(x: 7, y: 8, width: 12, height: 11)
            let rearPath = UIBezierPath(roundedRect: rearRect, cornerRadius: 3)
            let frontPath = UIBezierPath(roundedRect: frontRect, cornerRadius: 3)

            rearPath.lineWidth = 1.8
            frontPath.lineWidth = 1.8

            if isSelected {
                UIColor.black.withAlphaComponent(0.35).setFill()
                rearPath.fill()
                UIColor.black.setFill()
                frontPath.fill()
            } else {
                rearPath.stroke()
                frontPath.stroke()
            }
        }

        return image.withRenderingMode(.alwaysTemplate)
    }

    private static func makeRefreshHandoffTabBarItem() -> UITabBarItem {
        UITabBarItem(
            title: "Refresh",
            image: makeRefreshHandoffTabBarImage(isSelected: false),
            selectedImage: makeRefreshHandoffTabBarImage(isSelected: true)
        )
    }

    private static func makeRefreshHandoffTabBarImage(isSelected: Bool) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        let image = renderer.image { _ in
            UIColor.black.setStroke()
            UIColor.black.setFill()

            let arcCenter = CGPoint(x: 12, y: 12)
            let arcPath = UIBezierPath(
                arcCenter: arcCenter,
                radius: 6.5,
                startAngle: -.pi * 0.15,
                endAngle: .pi * 1.35,
                clockwise: true
            )
            arcPath.lineWidth = 1.9
            arcPath.lineCapStyle = .round
            arcPath.stroke()

            let arrowPath = UIBezierPath()
            arrowPath.lineWidth = 1.9
            arrowPath.lineCapStyle = .round
            arrowPath.lineJoinStyle = .round
            arrowPath.move(to: CGPoint(x: 18.2, y: 7.2))
            arrowPath.addLine(to: CGPoint(x: 18.6, y: 12.2))
            arrowPath.addLine(to: CGPoint(x: 13.8, y: 11.2))
            arrowPath.stroke()

            if isSelected {
                UIBezierPath(ovalIn: CGRect(x: 9, y: 9, width: 6, height: 6)).fill()
            }
        }

        return image.withRenderingMode(.alwaysTemplate)
    }

    private static func makePushPagerBarButtonItem(target: DemoPagerNavigationController) -> UIBarButtonItem {
        let item = UIBarButtonItem(
            image: makePushPagerImage(),
            style: .plain,
            target: target,
            action: #selector(DemoPagerNavigationController.pushPagerFromButton(_:))
        )
        item.accessibilityIdentifier = "push-pager-button"
        item.accessibilityLabel = "Push Pager"
        return item
    }

    private static func makePushPagerImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        let image = renderer.image { _ in
            UIColor.black.setStroke()
            UIColor.black.setFill()

            let rearPath = UIBezierPath(roundedRect: CGRect(x: 4, y: 5, width: 11, height: 10), cornerRadius: 3)
            let frontPath = UIBezierPath(roundedRect: CGRect(x: 7, y: 8, width: 11, height: 10), cornerRadius: 3)
            rearPath.lineWidth = 1.7
            frontPath.lineWidth = 1.7
            rearPath.stroke()
            frontPath.stroke()

            let plusPath = UIBezierPath()
            plusPath.lineWidth = 1.9
            plusPath.lineCapStyle = .round
            plusPath.move(to: CGPoint(x: 17, y: 5))
            plusPath.addLine(to: CGPoint(x: 17, y: 11))
            plusPath.move(to: CGPoint(x: 14, y: 8))
            plusPath.addLine(to: CGPoint(x: 20, y: 8))
            plusPath.stroke()
        }

        return image.withRenderingMode(.alwaysTemplate)
    }
}

@MainActor
final class DemoRefreshHandoffModeViewController: UIViewController {
    private struct ModeEntry {
        var mode: CollapsiblePagerRefreshHandoffMode
        var dataSource: DemoRefreshHandoffModeDataSource
        var pager: CollapsiblePagerViewController
    }

    private static let modes: [CollapsiblePagerRefreshHandoffMode] = [.none, .container, .child]

    private let pagerContainerView = UIView()
    private var entries: [ModeEntry] = []
    private var currentEntryIndex: Int?

    var availableRefreshHandoffModesForTesting: [CollapsiblePagerRefreshHandoffMode] {
        Self.modes
    }

    var currentPagerForTesting: CollapsiblePagerViewController? {
        guard let currentEntryIndex else {
            return nil
        }
        return entries[currentEntryIndex].pager
    }

    init() {
        super.init(nibName: nil, bundle: nil)
        navigationItem.title = "Refresh Handoff"
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        navigationItem.title = "Refresh Handoff"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureModeEntriesIfNeeded()
        selectMode(at: 0)
    }

    func pagerForTesting(mode: CollapsiblePagerRefreshHandoffMode) -> CollapsiblePagerViewController? {
        configureModeEntriesIfNeeded()
        return entries.first { $0.mode == mode }?.pager
    }

    func dataSourceForTesting(mode: CollapsiblePagerRefreshHandoffMode) -> DemoRefreshHandoffModeDataSource? {
        configureModeEntriesIfNeeded()
        return entries.first { $0.mode == mode }?.dataSource
    }

    func selectRefreshHandoffModeForTesting(_ mode: CollapsiblePagerRefreshHandoffMode) {
        guard let index = Self.modes.firstIndex(of: mode) else {
            return
        }

        selectMode(at: index)
    }

    private func configureView() {
        view.backgroundColor = .systemBackground

        pagerContainerView.translatesAutoresizingMaskIntoConstraints = false
        navigationItem.rightBarButtonItem = makeModeMenuBarButtonItem(selectedIndex: 0)

        view.addSubview(pagerContainerView)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            pagerContainerView.topAnchor.constraint(equalTo: guide.topAnchor),
            pagerContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pagerContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pagerContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func makeModeMenuBarButtonItem(selectedIndex: Int) -> UIBarButtonItem {
        let title = Self.modes[selectedIndex].demoTitle
        let item: UIBarButtonItem

        if #available(iOS 14.0, *) {
            item = UIBarButtonItem(
                title: title,
                image: nil,
                primaryAction: nil,
                menu: makeModeMenu(selectedIndex: selectedIndex)
            )
        } else {
            item = UIBarButtonItem(
                title: title,
                style: .plain,
                target: self,
                action: #selector(showModeSelectionFallback(_:))
            )
        }

        item.accessibilityIdentifier = "refresh-mode-menu-button"
        item.accessibilityLabel = "Refresh handoff mode: \(title)"
        return item
    }

    @available(iOS 14.0, *)
    private func makeModeMenu(selectedIndex: Int) -> UIMenu {
        let actions = Self.modes.enumerated().map { index, mode in
            UIAction(
                title: mode.demoTitle,
                state: index == selectedIndex ? .on : .off
            ) { [weak self] _ in
                self?.selectMode(at: index)
            }
        }

        return UIMenu(title: "Refresh Handoff", children: actions)
    }

    @objc private func showModeSelectionFallback(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "Refresh Handoff", message: nil, preferredStyle: .actionSheet)

        for (index, mode) in Self.modes.enumerated() {
            alert.addAction(UIAlertAction(title: mode.demoTitle, style: .default) { [weak self] _ in
                self?.selectMode(at: index)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = sender

        present(alert, animated: true)
    }

    private func configureModeEntriesIfNeeded() {
        guard entries.isEmpty else {
            return
        }

        entries = Self.modes.map { mode in
            let dataSource = DemoRefreshHandoffModeDataSource(mode: mode)
            var configuration = CollapsiblePagerConfiguration.default
            configuration.refreshHandoffMode = mode
            if mode == .child {
                configuration.headerPullDownRefreshBehavior = .suppressesChildRefresh
            }
            let pager = CollapsiblePagerViewController(configuration: configuration)
            pager.dataSource = dataSource
            pager.delegate = dataSource
            pager.view.accessibilityIdentifier = "refresh-mode-\(mode.demoIdentifier)-pager"
            dataSource.headerView.onReloadLayout = { [weak pager] in
                pager?.reloadHeaderLayout(offsetPolicy: .preserveVisualPosition)
            }
            dataSource.configureRefreshHost(for: pager)
            pager.reloadData()
            return ModeEntry(mode: mode, dataSource: dataSource, pager: pager)
        }
    }

    private func selectMode(at index: Int) {
        guard entries.indices.contains(index),
              currentEntryIndex != index else {
            return
        }

        if let currentEntryIndex {
            let currentPager = entries[currentEntryIndex].pager
            currentPager.willMove(toParent: nil)
            currentPager.view.removeFromSuperview()
            currentPager.removeFromParent()
        }

        let entry = entries[index]
        addChild(entry.pager)
        pagerContainerView.addSubview(entry.pager.view)
        entry.pager.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            entry.pager.view.topAnchor.constraint(equalTo: pagerContainerView.topAnchor),
            entry.pager.view.leadingAnchor.constraint(equalTo: pagerContainerView.leadingAnchor),
            entry.pager.view.trailingAnchor.constraint(equalTo: pagerContainerView.trailingAnchor),
            entry.pager.view.bottomAnchor.constraint(equalTo: pagerContainerView.bottomAnchor),
        ])
        entry.pager.didMove(toParent: self)
        currentEntryIndex = index
        navigationItem.rightBarButtonItem = makeModeMenuBarButtonItem(selectedIndex: index)
    }
}

@MainActor
final class DemoPagerNavigationController: UINavigationController {
    private var retainedDataSources: [DemoPagerDataSource]

    init(rootPager: CollapsiblePagerViewController, rootDataSource: DemoPagerDataSource) {
        retainedDataSources = [rootDataSource]
        super.init(rootViewController: rootPager)
    }

    required init?(coder: NSCoder) {
        retainedDataSources = []
        super.init(coder: coder)
    }

    @objc func pushPagerFromButton(_ sender: UIBarButtonItem) {
        let dataSource = DemoPagerDataSource()
        let pager = DemoPagerFactory.makePager(dataSource: dataSource)
        pager.navigationItem.title = "Pushed Pager"
        pager.navigationItem.largeTitleDisplayMode = .never
        pager.hidesBottomBarWhenPushed = true
        DemoPagerFactory.configurePushButton(for: pager, target: self)
        retainedDataSources.append(dataSource)
        pager.reloadData()
        pushViewController(pager, animated: true)
    }
}

@MainActor
final class DemoRefreshHandoffModeDataSource: NSObject, CollapsiblePagerViewControllerDataSource, CollapsiblePagerViewControllerDelegate {
    private struct Page {
        var title: String
        var rowCount: Int
        var refreshTitle: String?
        var accessibilityID: String
    }

    let headerViewController = DemoHeaderViewController()
    var headerView: DemoHeaderView {
        headerViewController.headerView
    }

    private let mode: CollapsiblePagerRefreshHandoffMode
    private let pages: [Page]
    private let containerRefreshController = DemoRefreshController()
    private var hasConfiguredContainerRefreshHost = false

    init(mode: CollapsiblePagerRefreshHandoffMode) {
        self.mode = mode
        pages = [
            Page(
                title: mode.demoTitle,
                rowCount: 40,
                refreshTitle: mode == .container ? nil : "\(mode.demoTitle) refresh",
                accessibilityID: "refresh-mode-\(mode.demoIdentifier)-list"
            ),
        ]
        super.init()
        headerView.setTitle("Refresh Handoff: \(mode.demoTitle)", subtitle: mode.demoSubtitle)
        headerView.setSelectionText("Selected: \(mode.demoTitle)")
    }

    func configureRefreshHost(for pager: CollapsiblePagerViewController) {
        guard mode == .container, !hasConfiguredContainerRefreshHost else {
            return
        }

        containerRefreshController.attach(to: pager.containerRefreshHostScrollView, title: "Container refresh")
        hasConfiguredContainerRefreshHost = true
    }

    func numberOfPages(in pagerViewController: CollapsiblePagerViewController) -> Int {
        pages.count
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, titleForPageAt index: Int) -> String {
        pages[index].title
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, viewControllerForPageAt index: Int) -> UIViewController {
        let page = pages[index]
        return DemoListViewController(
            title: page.title,
            rowCount: page.rowCount,
            refreshTitle: page.refreshTitle,
            accessibilityID: page.accessibilityID
        )
    }

    func headerContent(in pagerViewController: CollapsiblePagerViewController) -> CollapsiblePagerHeaderContent {
        .viewController(headerViewController)
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, didSelectPageAt index: Int) {
        headerView.setSelectionText("Selected: \(pages[index].title)")
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, didUpdateCollapseProgress progress: CGFloat) {
        headerView.setProgress(progress)
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, didUpdateLayout context: CollapsiblePagerLayoutContext) {
    }
}

@MainActor
final class DemoPagerDataSource: NSObject, CollapsiblePagerViewControllerDataSource, CollapsiblePagerViewControllerDelegate {
    struct Page {
        var title: String
        var rowCount: Int
        var refreshTitle: String?
        var accessibilityID: String
    }

    let headerViewController = DemoHeaderViewController()
    var headerView: DemoHeaderView {
        headerViewController.headerView
    }

    private let pages = [
        Page(title: "Long", rowCount: 60, refreshTitle: nil, accessibilityID: "demo-list-long"),
        Page(title: "Short", rowCount: 8, refreshTitle: nil, accessibilityID: "demo-list-short"),
        Page(title: "Empty", rowCount: 0, refreshTitle: nil, accessibilityID: "demo-list-empty"),
    ]
    private let containerRefreshController = DemoRefreshController()
    private var hasConfiguredContainerRefreshHost = false

    func configureRefreshHost(for pager: CollapsiblePagerViewController) {
        guard !hasConfiguredContainerRefreshHost else {
            return
        }

        containerRefreshController.attach(to: pager.containerRefreshHostScrollView, title: "Container refresh")
        hasConfiguredContainerRefreshHost = true
    }

    func numberOfPages(in pagerViewController: CollapsiblePagerViewController) -> Int {
        pages.count
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, titleForPageAt index: Int) -> String {
        pages[index].title
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, viewControllerForPageAt index: Int) -> UIViewController {
        let page = pages[index]
        return DemoListViewController(
            title: page.title,
            rowCount: page.rowCount,
            refreshTitle: page.refreshTitle,
            accessibilityID: page.accessibilityID
        )
    }

    func headerContent(in pagerViewController: CollapsiblePagerViewController) -> CollapsiblePagerHeaderContent {
        .viewController(headerViewController)
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, didSelectPageAt index: Int) {
        headerView.setSelectionText("Selected: \(pages[index].title)")
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, didUpdateCollapseProgress progress: CGFloat) {
        headerView.setProgress(progress)
    }

    func pagerViewController(_ pagerViewController: CollapsiblePagerViewController, didUpdateLayout context: CollapsiblePagerLayoutContext) {
    }
}

extension CollapsiblePagerRefreshHandoffMode {
    var demoTitle: String {
        switch self {
        case .none:
            "None"
        case .container:
            "Container"
        case .child:
            "Child"
        }
    }

    var demoIdentifier: String {
        switch self {
        case .none:
            "none"
        case .container:
            "container"
        case .child:
            "child"
        }
    }

    var demoSubtitle: String {
        switch self {
        case .none:
            "No handoff: child scroll behavior is left to UIKit or an installed refresh control."
        case .container:
            "Container mode: continued pull-down is routed to the container-owned refresh host."
        case .child:
            "Child mode: header pull-down is suppressed; pull from list content to trigger child refresh."
        }
    }

    var demoTitleForTesting: String {
        demoTitle
    }
}
