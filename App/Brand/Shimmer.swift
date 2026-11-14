import SwiftUI

struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay {
                    LinearGradient(
                        colors: [.clear, BrandColors.text.opacity(SkeletonConstants.shimmerOpacity), .clear],
                        startPoint: UnitPoint(x: phase, y: 0.5),
                        endPoint: UnitPoint(x: phase + 1, y: 0.5)
                    )
                    .allowsHitTesting(false)
                }
                .onAppear {
                    withAnimation(.linear(duration: SkeletonConstants.shimmerSeconds).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(Shimmer())
    }
}
