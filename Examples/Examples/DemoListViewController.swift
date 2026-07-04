import CollapsiblePager
import UIKit

@MainActor
final class DemoListViewController: UITableViewController, CollapsiblePagerScrollProviding {
    private let pageTitle: String
    private let rowCount: Int
    private let refreshTitle: String
    private let tableAccessibilityID: String
    private let demoRefreshController = DemoRefreshController()

    var pagerScrollView: UIScrollView {
        tableView
    }

    init(title: String, rowCount: Int, refreshTitle: String, accessibilityID: String) {
        self.pageTitle = title
        self.rowCount = rowCount
        self.refreshTitle = refreshTitle
        self.tableAccessibilityID = accessibilityID
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.accessibilityIdentifier = tableAccessibilityID
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        demoRefreshController.attach(to: tableView, title: refreshTitle)
        configureEmptyState()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rowCount
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = "\(pageTitle) row \(indexPath.row + 1)"
        cell.detailTextLabel?.text = nil
        cell.selectionStyle = .none
        return cell
    }

    private func configureEmptyState() {
        guard rowCount == 0 else {
            tableView.backgroundView = nil
            return
        }

        let label = UILabel()
        label.text = "No rows in Empty"
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        tableView.backgroundView = label
    }
}
