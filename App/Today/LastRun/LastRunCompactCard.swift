import SwiftUI
import WorkoutAnalysis

struct LastRunCompactCard: View {
    let lastRun: LastRunSummary
    var plannedKm: Double?

    private typealias C = TodayConstants
    private typealias L = LastRunConstants

    var body: some View {
        NavigationLink(value: TodayRoute.lastRun) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel("\(C.lastRunTitle) · \(lastRun.dateText)").padding(.top, 0).padding(.bottom, 0)
                    Spacer()
                    Text(L.viewAnalysis).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.accent)
                }
                HStack(alignment: .center, spacing: 12) {
                    if let score = lastRun.score {
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandCard()
            .perfectScoreCard(score: lastRun.score, activityId: lastRun.activityId)
        }
        .buttonStyle(.plain)
    }
}
