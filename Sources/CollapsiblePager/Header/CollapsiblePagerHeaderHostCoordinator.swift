import UIKit

enum CollapsiblePagerHeaderHostMoveReason: Sendable, Equatable {
    case currentChild
    case horizontalPaging
    case refresh
    case layoutReload
}

@MainActor
final class CollapsiblePagerHeaderHostCoordinator {
    private weak var owner: UIViewController?
    private let hostView = CollapsiblePagerHeaderHostView()
    private var currentHeaderController: UIViewController?

    init(owner: UIViewController) {
        self.owner = owner
    }

    func setContent(_ content: CollapsiblePagerHeaderContent, initialContainer: UIView) {
        moveHost(to: initialContainer, reason: .currentChild)
        removeCurrentContent()

        switch content {
        case let .view(view):
            hostView.setContentView(view)
        case let .viewController(viewController):
            guard let owner else {
                return
            }

            owner.addChild(viewController)
            hostView.setContentView(viewController.view)
            viewController.didMove(toParent: owner)
            currentHeaderController = viewController
        }
    }

    func moveHost(to container: UIView, reason: CollapsiblePagerHeaderHostMoveReason) {
        if hostView.superview !== container {
            container.addSubview(hostView)
        }

        hostView.frame = container.bounds
        hostView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    func clearContent() {
        removeCurrentContent()
        hostView.removeFromSuperview()
    }

    private func removeCurrentContent() {
        if let controller = currentHeaderController {
            controller.willMove(toParent: nil)
            hostView.setContentView(nil)
            controller.removeFromParent()
            currentHeaderController = nil
        } else {
            hostView.setContentView(nil)
        }
    }
}
