import Insights
import SwiftUI

struct TrainerCompareView: View {
    let weeks: [TrainerComparisonWeek]
    let weekIndex: (TrainerComparisonWeek) -> Int?

    var body: some View {
        ForEach(weeks, id: \.start) { week in
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(TrainerText.weekTitle(index: weekIndex(week), start: week.start))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandColors.text)
                    Spacer()
                    Text(TrainerText.compareColumns).font(.caption2).foregroundStyle(BrandColors.dim)
                }
                HStack {
                    Text(TrainerText.compareSummaryKilometers(week))
                    Spacer()
                    Text(TrainerText.compareSummaryQuality(week))
                    Spacer()
                    Text(TrainerText.compareSummarySame(week))
                }
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
                .monospacedDigit()
            }
            .brandCard()
            ForEach(week.days) { day in
                dayCard(day)
            }
        }
    }

    private func dayCard(_ day: TrainerComparisonDay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(TrainerText.compareDayTitle(day))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color(day.match))
            line(TrainerText.externalLabel, day.externalSummary)
            betaLine(day)
            if let done = TrainerText.compareDone(day) {
                Text(done).font(.footnote).foregroundStyle(BrandColors.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func betaLine(_ day: TrainerComparisonDay) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(TrainerText.betaLabel).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.dim).frame(width: 92, alignment: .leading)
            if let beta = day.beta, beta.kind != .off {
                VStack(alignment: .leading, spacing: 2) {
                    TrainerDayLineView(line: TrainerText.dayLine(beta), titleFont: .footnote)
                }
            } else {
                Text(TrainerText.noWorkoutLabel).font(.footnote).foregroundStyle(BrandColors.text)
            }
        }
    }

    private func line(_ label: String, _ text: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.dim).frame(width: 92, alignment: .leading)
            Text(text ?? TrainerText.noWorkoutLabel).font(.footnote).foregroundStyle(BrandColors.text)
        }
    }

    private func color(_ match: TrainerComparisonMatch) -> Color {
        switch match {
        case .same: BrandColors.accent
        case .similar: BrandColors.attention
        case .different: BrandColors.danger
        }
    }
}

struct TrainerTabPicker: View {
    @Binding var tab: TrainerTab

    var body: some View {
        Picker("", selection: $tab) {
            Text(TrainerText.planTab).tag(TrainerTab.plan)
            Text(TrainerText.compareTab).tag(TrainerTab.compare)
        }
        .pickerStyle(.segmented)
    }
}
