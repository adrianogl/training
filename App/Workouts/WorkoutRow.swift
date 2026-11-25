import SwiftUI
import TrainingCore

struct WorkoutRow: View {
    let row: WorkoutRowData
    var isSelected = false
    var hasChat = false
    var isFromPlan = false
    var isNew = false

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
                } else if row.scorePending {
                    ScoreLoadingInline()
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(PlanText.title(row.title))
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
            ViewThatFits(in: .horizontal) {
                badgeLine(showsKind: true)
                badgeLine(showsKind: false)
            }
            if !row.zoneShares.isEmpty {
                ZoneStrip(shares: row.zoneShares)
                    .padding(.top, 2)
            }
            CardLinkFooter(title: CardLinkConstants.details)
                .padding(.top, 4)
        }
        .brandCard()
        .perfectScoreCard(score: row.score, activityId: row.activityId)
        .recordCard(row.recordPill != nil && (row.score ?? 0) < ScoreConstants.perfectScore)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: BrandConstants.cardCornerRadius, style: .continuous)
                    .strokeBorder(BrandColors.accentFill, lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
    }

    private func badgeLine(showsKind: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            badges(showsKind: showsKind)
            Spacer(minLength: 8)
            if let metrics = metricsText {
                Text(metrics)
                    .font(BrandFonts.number(14))
                    .foregroundStyle(BrandColors.dim)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    private func badges(showsKind: Bool) -> some View {
        HStack(spacing: 6) {
            if isNew {
                NewBadge()
            }
            if let record = row.recordPill {
                DSChip(text: RecordTextConstants.recordSymbol + record, tone: .record, style: .solid).fixedSize()
            }
            if let goal = row.goalPill {
                DSChip(text: RecordTextConstants.goalSymbol + goal, tone: .accent, style: .solid).fixedSize()
            }
            if showsKind, isFromPlan {
                DSChip(text: WorkoutConstants.fromPlan, tone: .accent).fixedSize()
            } else if showsKind, row.hasPrescription {
                DSChip(text: WorkoutConstants.structured, tone: .neutral).fixedSize()
            }
            if StravaActivityId.isStrava(row.activityId) {
                DSChip(text: WorkoutConstants.stravaTag, tone: .neutral).fixedSize()
            }
            if row.isStrength {
                DSChip(text: WorkoutConstants.strengthTag, tone: .strength).fixedSize()
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
