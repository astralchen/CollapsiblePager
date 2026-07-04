import UIKit

@MainActor
final class DemoRefreshController: NSObject {
    private weak var refreshControl: UIRefreshControl?

    func attach(to scrollView: UIScrollView, title: String) {
        let control = UIRefreshControl()
        control.attributedTitle = NSAttributedString(string: title)
        control.addTarget(self, action: #selector(refreshTriggered(_:)), for: .valueChanged)
        scrollView.refreshControl = control
        refreshControl = control
    }

    @objc private func refreshTriggered(_ sender: UIRefreshControl) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            sender.endRefreshing()
        }
    }
}
