import SwiftUI

@MainActor @Observable final class BrandRefreshCoordinator {
    private(set) var state = BrandRefreshState()
    private(set) var succeeded = true
    private(set) var isLanding = false
    private(set) var iconFrame: CGRect?
    private(set) var restIconCenterY: CGFloat?
    private(set) var landingTarget: CGPoint?
    var overscroll: CGFloat = 0

    var hidesLogo: Bool { state.isActive && iconFrame != nil }

    var spaceHeight: CGFloat {
        switch state.phase {
        case .idle: 0
        case .pulling: state.pull
        case .syncing, .done: BrandRefreshConstants.syncInset
        }
    }

    var insetHeight: CGFloat {
        (state.phase == .syncing || state.phase == .done) && !isLanding ? BrandRefreshConstants.syncInset : 0
    }

    func recordHeader(_ frame: CGRect) {
        iconFrame = frame
        guard !state.isActive else { return }
        restIconCenterY = frame.midY - overscroll
    }

    func feed(overscroll: CGFloat, isInteracting: Bool) -> BrandRefreshEvent? {
        self.overscroll = overscroll
        return state.update(overscroll: overscroll, isInteracting: isInteracting)
    }

    func run(reduceMotion: Bool, action: () async -> Bool) async {
        let ok = await action()
        succeeded = ok
        state.finish()
        try? await Task.sleep(for: .seconds(BrandRefreshConstants.doneSeconds))
        if let frame = iconFrame {
            landingTarget = CGPoint(x: frame.minX + BrandConstants.logoIconSize / 2, y: frame.midY - BrandRefreshConstants.syncInset)
        }
        let animation: Animation? = reduceMotion ? nil : .smooth(duration: BrandRefreshConstants.landSeconds)
        withAnimation(animation) { isLanding = true }
        try? await Task.sleep(for: .seconds(reduceMotion ? 0 : BrandRefreshConstants.landSeconds))
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            state.settle()
            isLanding = false
            landingTarget = nil
        }
    }
}
