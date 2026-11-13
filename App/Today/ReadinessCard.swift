import Insights
import SwiftUI

struct ReadinessCard: View {
    let model: TodayModel

    var body: some View {
        let summary = model.summary
        NavigationLink(value: TodayRoute.readiness) {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(TodayConstants.readinessTitle)
                    .padding(.top, 0)
                    .padding(.bottom, 0)
                if let breakdown = summary.readiness {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(breakdown.score)")
                            .font(BrandFonts.number(56))
                            .foregroundStyle(ReadinessRuler.color(for: breakdown.score))
                        Text(summary.verdict.flatMap { TodayConstants.verdictPhrases[$0] } ?? "")
                            .font(.headline)
                            .foregroundStyle(BrandColors.text)
                    }
                    ReadinessRuler(score: breakdown.score)
                } else {
                    Text(TodayConstants.readinessEmpty)
                        .font(.subheadline)
                        .foregroundStyle(BrandColors.dim)
                }
                HStack {
                    support(TodayConstants.supportHRV, summary.supporting.hrvVsBaseline.map { TodayText.signed($0) })
                    Spacer()
                    support(TodayConstants.supportSleep, summary.supporting.sleepScore.map { "\($0)" })
                    Spacer()
                    support(TodayConstants.supportLoad, summary.supporting.acuteChronic.map { TodayText.decimal($0, fractionDigits: 2) })
                    Spacer()
                    support(TodayConstants.supportStress, summary.supporting.stress.map { "\($0)" })
                }
                .font(.footnote)
            }
            .brandCard()
        }
        .buttonStyle(.plain)
    }

    private func support(_ name: String, _ value: String?) -> some View {
        HStack(spacing: 4) {
            Text(name).foregroundStyle(BrandColors.dim)
            Text(value ?? "—").font(BrandFonts.number(14)).foregroundStyle(BrandColors.text)
        }
    }
}
