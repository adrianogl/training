import SwiftUI

struct ScoreSummaryCard: View {
    let value: Int
    let rows: [ScoreRowData]
    var activityId: Int64?
    var perfectLine: String?
    var framed = true
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress = 1.0
    @State private var rippleTrigger = 0

    private typealias C = WorkoutDetailConstants

    private var isPerfect: Bool { value >= ScoreConstants.perfectScore }
    private var gaugeSize: Double { sizeClass == .regular ? C.scoreGaugeSize : C.compactScoreGaugeSize }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            HStack(alignment: .center, spacing: 18) {
                AnimatedScoreGauge(score: value, progress: progress, size: gaugeSize)
                    .background {
                        if isPerfect {
                            ripple(delay: 0)
                            ripple(delay: ScoreConstants.rippleSecondDelay)
                        }
                    }
                VStack(spacing: 10) {
                    ForEach(rows.filter(\.isIncluded)) { row in
                        HStack(spacing: 10) {
                            Text(row.name)
                                .font(.footnote)
                                .foregroundStyle(BrandColors.dim)
                                .frame(width: C.scorePartNameWidth, alignment: .leading)
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(color(row))
                                    .frame(width: max(4, proxy.size.width * row.points / row.maximum))
                            }
                            .frame(height: C.scorePartBarHeight)
                            .background(BrandColors.track, in: Capsule())
                            Text(row.pointsText ?? "")
                                .font(BrandFonts.number(14))
                                .foregroundStyle(BrandColors.text)
                                .fixedSize()
                        }
                    }
                }
            }
            let reasons = rows.compactMap { row in row.reasonText.map { (text: $0, full: row.points >= row.maximum) } }
            if !reasons.isEmpty {
                FlowChips(items: reasons.map { ($0.text, $0.full ? DSTone.accent : DSTone.attention) })
            }
        }
        .brandCard(framed: framed, fillsHeight: true)
        .onAppear(perform: celebrate)
    }

    @ViewBuilder private var header: some View {
        if isPerfect {
            VStack(alignment: .leading, spacing: 4) {
                Label(ScoreConstants.perfectTitle, systemImage: ScoreConstants.perfectSymbol)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(BrandColors.accent)
                if let perfectLine {
                    Text(perfectLine)
                        .font(.footnote)
                        .foregroundStyle(BrandColors.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            DSCardLabel(ScoreConstants.breakdownTitle)
        }
    }

    private func ripple(delay: Double) -> some View {
        Circle()
            .strokeBorder(BrandColors.accentFill, lineWidth: ScoreConstants.rippleLineWidth)
            .frame(width: gaugeSize, height: gaugeSize)
            .keyframeAnimator(initialValue: RippleFrame(), trigger: rippleTrigger) { content, frame in
                content.scaleEffect(frame.scale).opacity(frame.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0, duration: ScoreConstants.fillDuration + delay)
                    LinearKeyframe(ScoreConstants.rippleOpacity, duration: 0.01)
                    LinearKeyframe(0, duration: ScoreConstants.rippleDuration, timingCurve: .easeOut)
                }
                KeyframeTrack(\.scale) {
                    LinearKeyframe(1, duration: ScoreConstants.fillDuration + delay)
                    LinearKeyframe(ScoreConstants.rippleScale, duration: ScoreConstants.rippleDuration, timingCurve: .easeOut)
                }
            }
            .allowsHitTesting(false)
    }

    private func celebrate() {
        guard !reduceMotion, let activityId, ScoreCelebration.claimFirstTime(.detail, activityId: activityId) else { return }
        progress = 0
        withAnimation(.timingCurve(0.3, 0.7, 0.3, 1, duration: ScoreConstants.fillDuration)) {
            progress = 1
        }
        if isPerfect { rippleTrigger += 1 }
    }

    private func color(_ row: ScoreRowData) -> Color {
        row.points < row.maximum ? BrandColors.attention : BrandColors.accentFill
    }
}

struct FlowChips: View {
    let items: [(String, DSTone)]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { chips }
            VStack(alignment: .leading, spacing: 6) { chips }
        }
    }

    private var chips: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            DSChip(text: item.0, tone: item.1)
        }
    }
}
