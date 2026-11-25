import SwiftUI
import WorkoutAnalysis

struct LastRunCompactCard: View {
    let lastRun: LastRunSummary
    var plannedKm: Double?

    private typealias C = TodayConstants
    private typealias L = LastRunConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                DSCardLabel(C.lastRunTitle)
                Spacer()
                Text(lastRun.dateText).font(.caption).foregroundStyle(BrandColors.dim)
            }
            HStack(alignment: .center, spacing: 12) {
                if lastRun.scorePending {
                    ScoreLoadingBadge()
                } else if let score = lastRun.score {
                    ScoreBadge(value: score, size: ScoreConstants.cardBadgeSize)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(LastRunBuilder.compactTitle(lastRun))
                        .font(.headline)
                        .foregroundStyle(BrandColors.text)
                        .lineLimit(1)
                    Text(LastRunBuilder.compactLine(lastRun, plannedKm: plannedKm))
                        .font(.caption)
                        .foregroundStyle(lastRun.heartRateHigh == true ? BrandColors.attention : BrandColors.dim)
                }
                Spacer(minLength: 0)
            }
            if let reading = lastRun.reading ?? lastRun.evolution {
                Text(reading)
                    .font(.footnote)
                    .foregroundStyle(BrandColors.text)
                    .lineLimit(L.compactReadingLines)
            }
            NavigationLink(value: TodayRoute.lastRun) { CardLinkFooter(title: CardLinkConstants.analysis) }
                .buttonStyle(.cardLink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
        .perfectScoreCard(score: lastRun.score, activityId: lastRun.activityId)
    }
}
