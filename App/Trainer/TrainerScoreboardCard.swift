import Insights
import SwiftUI

struct TrainerScoreboardCard: View {
    let boards: [TrainerScoreboard]

    var body: some View {
        if let latest = boards.first {
            VStack(alignment: .leading, spacing: 8) {
                Text(TrainerText.scoreboardTitle(latest.weekIndex))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.text)
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(TrainerText.scoreboardKilometers(latest)).font(BrandFonts.number(18)).foregroundStyle(BrandColors.text)
                    if let quality = TrainerText.scoreboardQuality(latest) {
                        Text(quality).font(.footnote).foregroundStyle(BrandColors.dim)
                    }
                    if let prediction = TrainerText.scoreboardPrediction(latest) {
                        Text(prediction).font(.footnote).foregroundStyle(BrandColors.dim)
                    }
                }
                if let long = TrainerText.scoreboardLong(latest) {
                    Text(long).font(.footnote).foregroundStyle(latest.longClosed == true ? BrandColors.accent : BrandColors.attention)
                }
                if boards.count > 1 {
                    Divider()
                    SectionLabel(TrainerText.scoreboardWeeks).padding(.vertical, 0)
                    ForEach(boards) { board in
                        Text(TrainerText.scoreboardRow(board)).font(.caption).foregroundStyle(BrandColors.dim).monospacedDigit()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandCard()
        }
    }
}
