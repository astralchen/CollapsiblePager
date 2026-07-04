import CollapsiblePager
import UIKit

@MainActor
enum DemoPagerFactory {
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
