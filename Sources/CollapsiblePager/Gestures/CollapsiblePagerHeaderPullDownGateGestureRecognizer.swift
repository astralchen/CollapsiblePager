import UIKit

@MainActor
final class CollapsiblePagerHeaderPullDownGateGestureRecognizer: UIPanGestureRecognizer, UIGestureRecognizerDelegate {
    var shouldBeginGate: (@MainActor (UIPanGestureRecognizer) -> Bool)?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === self else {
            return false
        }

        return shouldBeginGate?(self) ?? false
    }
}
