import SwiftUI

struct BrandRefreshable: ViewModifier {
    let action: () async -> Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var coordinator = BrandRefreshCoordinator()
    @State private var isInteracting = false
    @State private var overscroll: CGFloat = 0
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                max(0, -(geometry.contentOffset.y + geometry.contentInsets.top))
            } action: { _, value in
                overscroll = value
                feed()
            }
            .onScrollPhaseChange { _, phase in
                isInteracting = phase == .interacting
                feed()
            }
            .coordinateSpace(name: BrandRefreshConstants.space)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .overlay { indicator }
            .environment(coordinator)
            .sensoryFeedback(trigger: coordinator.state.isArmed) { _, armed in
                armed ? .impact(weight: .light) : nil
            }
    }

    private func feed() {
        guard let event = coordinator.feed(overscroll: overscroll, isInteracting: isInteracting) else { return }
        guard event == .started else { return }
        let action = action
        Task { await coordinator.run(action: action) }
    }

    private var indicator: some View {
        let state = coordinator.state
        let restCenterY = coordinator.restIconCenterY ?? BrandRefreshConstants.fallbackIconCenterY
        let top = restCenterY - BrandRefreshConstants.headerPadding
        return ZStack {
            if coordinator.showsPullIndicator {
                BrandLoader(size: .regular, progress: state.fraction)
                    .position(x: width / 2, y: max(restCenterY, top + state.pull / 2))
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: BrandRefreshConstants.fadeSeconds), value: coordinator.showsPullIndicator)
        .allowsHitTesting(false)
    }
}

extension View {
    func brandRefreshable(action: @escaping () async -> Bool) -> some View {
        modifier(BrandRefreshable(action: action))
    }
}
