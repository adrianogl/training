import SwiftUI

struct WorkoutRow: View {
    let row: WorkoutRowData

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.dateText)
                    .font(.caption)
                    .foregroundStyle(BrandColors.dim)
                Text(row.title)
                    .font(.headline)
                    .foregroundStyle(BrandColors.text)
                    .lineLimit(2)
                if row.hasPrescription {
                    TreinusBadge()
                }
            }
            Spacer(minLength: 8)
            if let score = row.score {
                ScoreBadge(value: score, size: ScoreConstants.rowBadgeSize)
            }
            VStack(alignment: .trailing, spacing: 2) {
                if let distance = row.distanceText {
                    Text(distance)
                        .font(BrandFonts.number(24))
                        .foregroundStyle(BrandColors.text)
                }
                HStack(spacing: 8) {
                    if let pace = row.paceText {
                        Text(pace)
                    }
                    if let duration = row.durationText {
                        Text(duration)
                    }
                }
                .font(BrandFonts.number(15))
                .foregroundStyle(BrandColors.dim)
            }
        }
        .glassCard()
        .contentShape(Rectangle())
    }
}
