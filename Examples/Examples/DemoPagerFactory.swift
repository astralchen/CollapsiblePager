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

        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [navigationController]
        tabBarController.view.accessibilityIdentifier = "demo-root-tab-bar"

        pager.reloadData()

        return tabBarController
    }

    static func makePager(dataSource: DemoPagerDataSource) -> CollapsiblePagerViewController {
        var configuration = CollapsiblePagerConfiguration.default
        configuration.refreshMode = .child

        let pager = CollapsiblePagerViewController(configuration: configuration)
        pager.dataSource = dataSource
        pager.delegate = dataSource
        pager.view.accessibilityIdentifier = "demo-pager"

        dataSource.headerView.onReloadLayout = { [weak pager] in
            pager?.reloadHeaderLayout(offsetPolicy: .preserveVisualPosition)
        }

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
        DemoPagerFactory.configurePushButton(for: pager, target: self)
        retainedDataSources.append(dataSource)
        pager.reloadData()
        pushViewController(pager, animated: true)
    }
}

@MainActor
final class DemoPagerDataSource: NSObject, CollapsiblePagerViewControllerDataSource, CollapsiblePagerViewControllerDelegate {
    struct Page {
        var title: String
        var rowCount: Int
        var refreshTitle: String
        var accessibilityID: String
    }

    let headerView = DemoHeaderView()

    private let pages = [
        Page(title: "Long", rowCount: 60, refreshTitle: "Overall refresh", accessibilityID: "demo-list-long"),
        Page(title: "Short", rowCount: 8, refreshTitle: "Child refresh", accessibilityID: "demo-list-short"),
        Page(title: "Empty", rowCount: 0, refreshTitle: "Empty refresh", accessibilityID: "demo-list-empty"),
    ]

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
        .view(headerView)
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
