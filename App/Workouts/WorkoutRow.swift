import SwiftUI

struct WorkoutRow: View {
    let row: WorkoutRowData
    var isSelected = false
    var chatCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.dateText)
                        .font(.caption)
                        .foregroundStyle(BrandColors.dim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(row.title)
                        .font(.headline)
                        .foregroundStyle(BrandColors.text)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        if row.hasPrescription {
                            TreinusBadge()
                        }
                        if chatCount > 0 {
                            Label("\(chatCount)", systemImage: "bubble.left.and.text.bubble.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(BrandColors.fitness)
                        }
                    }
                }
                Spacer(minLength: 8)
                if let score = row.score {
                    ScoreBadge(value: score, size: ScoreConstants.rowBadgeSize)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    if let distance = row.distanceText {
                        Text(distance)
                            .font(BrandFonts.number(22))
                            .foregroundStyle(BrandColors.text)
                    }
                    HStack(spacing: 8) {
                        if let pace = row.paceText { Text(pace) }
                        if let duration = row.durationText { Text(duration) }
                    }
                    .font(BrandFonts.number(14))
                    .foregroundStyle(BrandColors.dim)
                }
            }
            if !row.zoneShares.isEmpty {
                ZoneStrip(shares: row.zoneShares)
            }
        }
        .brandCard()
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: BrandConstants.cardCornerRadius, style: .continuous)
                    .strokeBorder(BrandColors.accentFill, lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
    }
}
