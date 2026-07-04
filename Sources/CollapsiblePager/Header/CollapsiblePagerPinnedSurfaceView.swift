import UIKit

@MainActor
final class CollapsiblePagerPinnedSurfaceView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // 固定宿主只承载 Header/TabBar，可穿透空白区域让 child scroll view 继续接收手势。
        let hitView = super.hitTest(point, with: event)
        return hitView === self ? nil : hitView
    }
}
