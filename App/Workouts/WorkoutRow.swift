import SwiftUI

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
        .perfectScoreCard(score: row.score, activityId: row.activityId)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: BrandConstants.cardCornerRadius, style: .continuous)
                    .strokeBorder(BrandColors.accentFill, lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
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
