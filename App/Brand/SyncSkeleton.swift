import SwiftUI

struct SyncSkeleton: ViewModifier {
    let active: Bool
    let height: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if active {
            SkeletonCards(heights: [height])
        } else {
            content
        }
    }
}

extension View {
    func syncSkeleton(_ active: Bool, height: CGFloat) -> some View {
        modifier(SyncSkeleton(active: active, height: height))
    }
}
