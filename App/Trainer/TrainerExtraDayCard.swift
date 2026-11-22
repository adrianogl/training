import Insights
import SwiftUI

struct TrainerExtraDayCard: View {
    let suggestion: TrainerExtraDay
    let currentRuns: Int
    let keep: () -> Void
    let review: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(TrainerDaysText.extraDayTitle).font(.headline).foregroundStyle(BrandColors.text)
            DSNotice(tone: .attention, text: TrainerDaysText.extraDayReason(suggestion))
            HStack(spacing: 8) {
                column(
                    TrainerDaysText.extraDayCurrent(currentRuns), easy: suggestion.currentEasyMeters, long: suggestion.currentLongMeters, week: suggestion.currentWeekMeters,
                    highlighted: false
                )
                column(
                    TrainerDaysText.extraDayNext(suggestion.preference.runs), easy: suggestion.nextEasyMeters, long: suggestion.nextLongMeters, week: suggestion.nextWeekMeters,
                    highlighted: true
                )
            }
            Text(TrainerDaysText.extraDayHint(suggestion)).font(.caption).foregroundStyle(BrandColors.dim)
            HStack(spacing: 8) {
                Button(TrainerDaysText.extraDayKeep(currentRuns), action: keep).buttonStyle(.ds(.secondary))
                Button(TrainerDaysText.extraDayReview(suggestion.preference.runs), action: review).buttonStyle(.ds(.primary))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func column(_ title: String, easy: Double, long: Double, week: Double, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2.weight(.bold)).foregroundStyle(highlighted ? BrandColors.accent : BrandColors.dim)
            Text(TrainerDaysText.extraDayEasy(easy)).font(.footnote.monospacedDigit())
            Text(TrainerDaysText.extraDayLong(long)).font(.footnote.monospacedDigit())
            Text(TrainerDaysText.extraDayWeek(week)).font(.footnote.monospacedDigit()).foregroundStyle(BrandColors.dim)
        }
        .foregroundStyle(BrandColors.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            highlighted ? BrandColors.accentFill.opacity(TrainerExtraDayConstants.highlightOpacity) : BrandColors.line,
            in: ConcentricRectangle.dsInner
        )
    }
}
