import UIKit

enum CollapsiblePagerHeaderHostMoveReason: Sendable, Equatable {
    case currentChild
    case horizontalPaging
    case refresh
    case layoutReload
}

@MainActor
final class CollapsiblePagerHeaderHostCoordinator {
    private struct AppearanceTransition {
        var controller: UIViewController
        var appearing: Bool
    }

    private weak var owner: UIViewController?
    private let hostView = CollapsiblePagerHeaderHostView()
    private var currentHeaderController: UIViewController?
    private var appearedHeaderController: UIViewController?
    private var activeAppearanceTransition: AppearanceTransition?

    var hostSuperviewForTesting: UIView? {
        hostView.superview
    }

    init(owner: UIViewController) {
        self.owner = owner
    }

    func setContent(
        _ content: CollapsiblePagerHeaderContent,
        initialContainer: UIView,
        ownerIsVisible: Bool = false,
        animated: Bool = false
    ) {
        moveHost(to: initialContainer, reason: .currentChild)
        removeCurrentContent(ownerIsVisible: ownerIsVisible, animated: animated)

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
            if ownerIsVisible {
                viewController.beginAppearanceTransition(true, animated: animated)
                viewController.endAppearanceTransition()
                appearedHeaderController = viewController
            }
        }
    }

    func installGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        guard gestureRecognizer.view !== hostView else {
            return
        }

        hostView.addGestureRecognizer(gestureRecognizer)
    }

    func moveHost(to container: UIView, frame: CGRect? = nil, reason: CollapsiblePagerHeaderHostMoveReason) {
        if hostView.superview !== container {
            container.addSubview(hostView)
        }

        hostView.frame = frame ?? container.bounds
        hostView.autoresizingMask = frame == nil ? [.flexibleWidth, .flexibleHeight] : [.flexibleWidth]
    }

    func clearContent(ownerIsVisible: Bool = false, animated: Bool = false) {
        removeCurrentContent(ownerIsVisible: ownerIsVisible, animated: animated)
        hostView.removeFromSuperview()
    }

    func beginAppearanceTransition(appearing: Bool, animated: Bool) {
        guard activeAppearanceTransition == nil,
              let controller = currentHeaderController else {
            return
        }

        activeAppearanceTransition = AppearanceTransition(
            controller: controller,
            appearing: appearing
        )
        controller.beginAppearanceTransition(appearing, animated: animated)
    }

    func endAppearanceTransition(didAppear: Bool) {
        guard let transition = activeAppearanceTransition else {
            return
        }

        transition.controller.endAppearanceTransition()
        if didAppear {
            appearedHeaderController = transition.controller
        } else if appearedHeaderController === transition.controller {
            appearedHeaderController = nil
        }
        activeAppearanceTransition = nil
    }

    private func removeCurrentContent(ownerIsVisible: Bool, animated: Bool) {
        if let controller = currentHeaderController {
            finishActiveAppearanceTransitionIfNeeded(for: controller)
            if ownerIsVisible || appearedHeaderController === controller {
                controller.beginAppearanceTransition(false, animated: animated)
                controller.endAppearanceTransition()
                if appearedHeaderController === controller {
                    appearedHeaderController = nil
                }
            }
            controller.willMove(toParent: nil)
            hostView.setContentView(nil)
            controller.removeFromParent()
            currentHeaderController = nil
        } else {
            hostView.setContentView(nil)
        }
    }

    private func finishActiveAppearanceTransitionIfNeeded(for controller: UIViewController) {
        guard let transition = activeAppearanceTransition,
              transition.controller === controller else {
            return
        }

        controller.endAppearanceTransition()
        if transition.appearing {
            appearedHeaderController = controller
        } else if appearedHeaderController === controller {
            appearedHeaderController = nil
        }
        activeAppearanceTransition = nil
    }
}
