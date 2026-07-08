import UIKit

struct VerticalScrollModelResult: Sendable, Equatable {
    var pinAnchorY: CGFloat
    var pinDeltaY: CGFloat
    var shouldSyncNonCurrentChildren: Bool
}

struct VerticalScrollModel: Sendable, Equatable {
    private var pinAnchor: PinAnchor
    var pinThreshold: CGFloat
    var managedTopInset: CGFloat

    init(pinAnchorY: CGFloat, pinThreshold: CGFloat, managedTopInset: CGFloat) {
        self.pinAnchor = PinAnchor(value: max(0, pinAnchorY))
        self.pinThreshold = max(0, pinThreshold)
        self.managedTopInset = max(0, managedTopInset)
    }

    var pinAnchorY: CGFloat {
        pinAnchor.value
    }

    mutating func update(pinThreshold: CGFloat, managedTopInset: CGFloat) {
        self.pinThreshold = max(0, pinThreshold)
        self.managedTopInset = max(0, managedTopInset)
        _ = pinAnchor.update(to: pinAnchor.value.clamped(to: 0...self.pinThreshold))
    }

    mutating func setPinAnchorY(_ pinAnchorY: CGFloat) {
        _ = pinAnchor.update(to: max(0, pinAnchorY).clamped(to: 0...pinThreshold))
    }

    mutating func handleCurrentOffsetY(_ offsetY: CGFloat) -> VerticalScrollModelResult {
        let proposedPinAnchorY = (offsetY + managedTopInset).clamped(to: 0...pinThreshold)
        let pinDeltaY = pinAnchor.update(to: proposedPinAnchorY)

        return VerticalScrollModelResult(
            pinAnchorY: pinAnchor.value,
            pinDeltaY: pinDeltaY,
            shouldSyncNonCurrentChildren: pinDeltaY != 0
        )
    }
}

@MainActor
final class CollapsiblePagerVerticalScrollCoordinator {
    var isHorizontalPagingActive = false
    var onPinAnchorChanged: (@MainActor (VerticalScrollModelResult) -> Void)?

    private var model: VerticalScrollModel
    private var records: [CollapsiblePagerChildRecord] = []
    private var currentIndex: Int?
    private var syncEligibleIndexes: Set<Int>?
    private var guardedOffsetUpdateDepth = 0

    init(pinAnchorY: CGFloat, pinThreshold: CGFloat, managedTopInset: CGFloat) {
        self.model = VerticalScrollModel(
            pinAnchorY: pinAnchorY,
            pinThreshold: pinThreshold,
            managedTopInset: managedTopInset
        )
    }

    var pinAnchorY: CGFloat {
        model.pinAnchorY
    }

    func updateLayout(pinThreshold: CGFloat, managedTopInset: CGFloat) {
        model.update(pinThreshold: pinThreshold, managedTopInset: managedTopInset)
    }

    func setPinAnchorY(_ pinAnchorY: CGFloat) {
        model.setPinAnchorY(pinAnchorY)
    }

    func replaceRecords(
        _ records: [CollapsiblePagerChildRecord],
        currentIndex: Int?,
        syncEligibleIndexes: Set<Int>? = nil
    ) {
        self.records = records
        self.currentIndex = currentIndex
        self.syncEligibleIndexes = syncEligibleIndexes
    }

    func updateCurrentIndex(_ currentIndex: Int?) {
        self.currentIndex = currentIndex
    }

    @discardableResult
    func handleScrollViewDidScroll(_ scrollView: UIScrollView) -> VerticalScrollModelResult? {
        guard guardedOffsetUpdateDepth == 0,
              !isHorizontalPagingActive,
              let currentRecord,
              scrollView === currentRecord.scrollView else {
            return nil
        }

        let result = model.handleCurrentOffsetY(scrollView.contentOffset.y)
        currentRecord.lastKnownContentOffsetY = scrollView.contentOffset.y

        if result.shouldSyncNonCurrentChildren {
            syncNonCurrentChildren(by: result.pinDeltaY, excluding: currentRecord.index)
            onPinAnchorChanged?(result)
        }

        return result
    }

    func setContentOffsetY(_ offsetY: CGFloat, for scrollView: UIScrollView) {
        performGuardedOffsetUpdate {
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: offsetY), animated: false)
        }
    }

    func performGuardedOffsetUpdate(_ updates: () -> Void) {
        guardedOffsetUpdateDepth += 1
        defer {
            guardedOffsetUpdateDepth -= 1
        }

        updates()
    }

    private var currentRecord: CollapsiblePagerChildRecord? {
        guard let currentIndex else {
            return nil
        }
        return records.first { $0.index == currentIndex }
    }

    private func syncNonCurrentChildren(by pinDeltaY: CGFloat, excluding currentIndex: Int) {
        for record in records where record.index != currentIndex {
            if let syncEligibleIndexes, !syncEligibleIndexes.contains(record.index) {
                continue
            }

            let minimumOffsetY = -model.managedTopInset
            let targetOffsetY = max(record.scrollView.contentOffset.y + pinDeltaY, minimumOffsetY)
            setContentOffsetY(targetOffsetY, for: record.scrollView)
            record.lastKnownContentOffsetY = targetOffsetY
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
