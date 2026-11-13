import SwiftUI

struct LastRunCard: View {
    let lastRun: LastRunSummary

    var body: some View {
        NavigationLink(value: TodayRoute.workout(lastRun.activityId)) {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel("\(TodayConstants.lastRunTitle) · \(lastRun.dateText)")
                    .padding(.top, 0)
                HStack(alignment: .center) {
                    Text(lastRun.title)
                        .font(.headline)
                        .foregroundStyle(BrandColors.text)
                    Spacer()
                    if let score = lastRun.score {
                        ScoreBadge(value: score, size: ScoreConstants.cardBadgeSize)
                    }
                }
                .padding(.bottom, 8)
                .padding(.horizontal, 2)
                if !lastRun.rows.isEmpty {
                    ComparisonSection(
                        title: lastRun.comparisonTitle,
                        rows: lastRun.rows,
                        evolution: lastRun.evolution,
                        evolutionOnDevice: lastRun.evolutionOnDevice,
                        notice: lastRun.notice,
                        showsTarget: lastRun.showsTarget
                    )
                } else {
                    Text(TodayConstants.lastRunNoComparison)
                        .font(.footnote)
                        .foregroundStyle(BrandColors.dim)
                        .brandCard()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
