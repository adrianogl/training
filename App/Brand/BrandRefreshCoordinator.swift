import SwiftUI

@MainActor @Observable final class BrandRefreshCoordinator {
    private(set) var state = BrandRefreshState()
    private(set) var iconFrame: CGRect?
    private(set) var restIconCenterY: CGFloat?
    var overscroll: CGFloat = 0

    var showsPullIndicator: Bool { state.phase == .pulling }

    var hidesLogo: Bool { showsPullIndicator && iconFrame != nil }

    func recordHeader(_ frame: CGRect) {
        iconFrame = frame
        guard !state.isActive else { return }
        restIconCenterY = frame.midY - overscroll
    }

    func feed(overscroll: CGFloat, isInteracting: Bool) -> BrandRefreshEvent? {
        self.overscroll = overscroll
        return state.update(overscroll: overscroll, isInteracting: isInteracting)
    }

    func run(action: () async -> Bool) async {
        _ = await action()
        state.finish()
        state.settle()
    }
}
