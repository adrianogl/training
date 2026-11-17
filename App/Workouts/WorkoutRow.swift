import SwiftUI

struct WorkoutRow: View {
    let row: WorkoutRowData
    var isSelected = false
    var hasChat = false
    var isFromPlan = false
    var isNew = false
    @State private var shineTrigger = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(row.dateText)
                    .font(.caption)
                    .foregroundStyle(BrandColors.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 8)
                if let score = row.score {
                    ScoreInline(value: score)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(row.title)
                    .font(.headline)
                    .foregroundStyle(BrandColors.text)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if let distance = row.distanceText {
                    Text(distance)
                        .font(BrandFonts.number(22))
                        .foregroundStyle(BrandColors.text)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            HStack(alignment: .center, spacing: 12) {
                badges
                Spacer(minLength: 8)
                if let metrics = metricsText {
                    Text(metrics)
                        .font(BrandFonts.number(14))
                        .foregroundStyle(BrandColors.dim)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            if !row.zoneShares.isEmpty {
                ZoneStrip(shares: row.zoneShares)
                    .padding(.top, 2)
            }
        }
        .brandCard()
        .overlay {
            if isPerfect {
                LinearGradient(colors: [BrandColors.accentGlow, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: ScoreConstants.perfectGlowHeight))
                    .clipShape(cardShape)
                    .allowsHitTesting(false)
                shine
            }
        }
        .overlay {
            if isSelected || isPerfect {
                cardShape.strokeBorder(BrandColors.accentFill, lineWidth: isSelected ? 2 : ScoreConstants.perfectBorderWidth)
            }
        }
        .contentShape(Rectangle())
        .onAppear {
            guard isPerfect, !reduceMotion, ScoreCelebration.claimFirstTime(.row, activityId: row.activityId) else { return }
            shineTrigger += 1
        }
    }

    private var isPerfect: Bool { (row.score ?? 0) >= ScoreConstants.perfectScore }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: BrandConstants.cardCornerRadius, style: .continuous)
    }

    private var shine: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [.clear, .white.opacity(ScoreConstants.shineOpacity), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: proxy.size.width * ScoreConstants.shineWidth)
            .rotationEffect(.degrees(ScoreConstants.shineAngle))
            .keyframeAnimator(initialValue: -1.0, trigger: shineTrigger) { content, position in
                content.offset(x: position * proxy.size.width)
            } keyframes: { _ in
                LinearKeyframe(1.2, duration: ScoreConstants.shineDuration, timingCurve: .easeOut)
            }
        }
        .clipShape(cardShape)
        .allowsHitTesting(false)
    }

    private var badges: some View {
        HStack(spacing: 6) {
            if isNew {
                NewBadge()
            }
            if row.hasPrescription {
                PlannedBadge()
            }
            if isFromPlan {
                Text(WorkoutConstants.fromPlan)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(BrandColors.dim)
            }
            if hasChat {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BrandColors.fitness)
                    .accessibilityLabel(WorkoutChatConstants.hasChat)
            }
        }
    }

    private var metricsText: String? {
        let parts = [row.paceText, row.durationText].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: WorkoutConstants.metricsSeparator)
    }
}
