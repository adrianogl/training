import SwiftUI

struct BrandRefreshable: ViewModifier {
    let action: () async -> Bool
    @Environment(AppModel.self) private var app
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
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: coordinator.insetHeight)
                    .animation(reduceMotion ? nil : .smooth(duration: BrandRefreshConstants.insetSeconds), value: coordinator.insetHeight)
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
        let reduceMotion = reduceMotion
        let action = action
        Task { await coordinator.run(reduceMotion: reduceMotion, action: action) }
    }

    private var indicator: some View {
        let state = coordinator.state
        let restCenterY = coordinator.restIconCenterY ?? BrandRefreshConstants.fallbackIconCenterY
        let top = restCenterY - BrandRefreshConstants.headerPadding
        let landing = coordinator.isLanding
        let target = coordinator.landingTarget
        let glyphX = landing ? (target?.x ?? width / 2) : width / 2
        let glyphY: CGFloat = {
            if landing { return target?.y ?? top + BrandRefreshConstants.syncGlyphOffset }
            switch state.phase {
            case .idle, .pulling: return max(restCenterY, top + state.pull / 2)
            case .syncing, .done: return top + BrandRefreshConstants.syncGlyphOffset
            }
        }()
        let showsText = (state.phase == .syncing || state.phase == .done) && !landing
        let fades = landing && target == nil
        return ZStack {
            if state.isActive {
                glyph(landing: landing && target != nil, state: state)
                    .position(x: glyphX, y: glyphY)
                    .opacity(fades ? 0 : 1)
                Text(statusText(state))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(BrandColors.dim)
                    .position(x: width / 2, y: top + BrandRefreshConstants.syncTextOffset)
                    .opacity(showsText ? 1 : 0)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: BrandRefreshConstants.landSeconds), value: landing)
        .animation(reduceMotion ? nil : .smooth(duration: BrandRefreshConstants.settleSeconds), value: state.phase)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func glyph(landing: Bool, state: BrandRefreshState) -> some View {
        if landing {
            BrandIcon(size: BrandConstants.logoIconSize)
        } else {
            switch state.phase {
            case .idle, .pulling:
                BrandLoader(size: .regular, progress: state.fraction)
            case .syncing:
                BrandLoader(size: .regular)
            case .done:
                resultTile
            }
        }
    }

    private var resultTile: some View {
        let side = BrandRefreshConstants.checkSize
        let shape = RoundedRectangle(cornerRadius: side * BrandConstants.iconCornerRatio, style: .continuous)
        return shape
            .fill(BrandColors.loaderFill)
            .overlay(shape.strokeBorder(BrandColors.iconAccent, lineWidth: 1.5))
            .overlay(
                Image(systemName: coordinator.succeeded ? BrandRefreshConstants.successSymbol : BrandRefreshConstants.failureSymbol)
                    .font(.system(size: side * BrandLoaderConstants.fontRatio * 1.2, weight: .black))
                    .foregroundStyle(BrandColors.iconAccent)
            )
            .frame(width: side, height: side)
            .shadow(color: BrandColors.iconAccent.opacity(BrandRefreshConstants.checkGlowOpacity), radius: BrandRefreshConstants.checkGlowRadius)
    }

    private func statusText(_ state: BrandRefreshState) -> String {
        if state.phase == .done {
            return coordinator.succeeded ? SyncStatusPillConstants.updatedTitle : SyncStatusPillConstants.failedTitle
        }
        return SyncStatusPillText.content(for: app.syncStatus, showsFinished: false)?.text ?? SyncStatusPillConstants.syncingTitle
    }
}

extension View {
    func brandRefreshable(action: @escaping () async -> Bool) -> some View {
        modifier(BrandRefreshable(action: action))
    }
}
