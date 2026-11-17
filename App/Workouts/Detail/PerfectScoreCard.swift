import SwiftUI

struct PerfectScoreCard: ViewModifier {
    let isPerfect: Bool
    let activityId: Int64
    @State private var shineTrigger = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: BrandConstants.cardCornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPerfect {
                    LinearGradient(colors: [BrandColors.accentGlow, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: ScoreConstants.perfectGlowHeight))
                        .clipShape(shape)
                        .allowsHitTesting(false)
                    shine
                    shape.strokeBorder(BrandColors.accentFill, lineWidth: ScoreConstants.perfectBorderWidth)
                }
            }
            .onAppear {
                guard isPerfect, !reduceMotion, ScoreCelebration.claimFirstTime(.row, activityId: activityId) else { return }
                shineTrigger += 1
            }
    }

    private var shine: some View {
        GeometryReader { proxy in
            LinearGradient(colors: [.clear, .white.opacity(ScoreConstants.shineOpacity), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: proxy.size.width * ScoreConstants.shineWidth)
                .rotationEffect(.degrees(ScoreConstants.shineAngle))
                .keyframeAnimator(initialValue: -1.0, trigger: shineTrigger) { content, position in
                    content.offset(x: position * proxy.size.width)
                } keyframes: { _ in
                    LinearKeyframe(1.2, duration: ScoreConstants.shineDuration, timingCurve: .easeOut)
                }
        }
        .clipShape(shape)
        .allowsHitTesting(false)
    }
}

extension View {
    func perfectScoreCard(score: Int?, activityId: Int64) -> some View {
        modifier(PerfectScoreCard(isPerfect: (score ?? 0) >= ScoreConstants.perfectScore, activityId: activityId))
    }
}
