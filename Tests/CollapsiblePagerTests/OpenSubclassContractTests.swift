import CollapsiblePager
import Testing

@MainActor
@Test func pagerViewControllerCanBeSubclassedByClients() {
    final class ClientPagerViewController: CollapsiblePagerViewController {
        var didLoadView = false
        var didLayoutSubviews = false

        override var shouldAutomaticallyForwardAppearanceMethods: Bool {
            super.shouldAutomaticallyForwardAppearanceMethods
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            didLoadView = true
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            didLayoutSubviews = true
        }
    }

    let pager = ClientPagerViewController()

    pager.loadViewIfNeeded()
    pager.view.setNeedsLayout()
    pager.view.layoutIfNeeded()

    #expect(pager.didLoadView)
    #expect(pager.didLayoutSubviews)
}
