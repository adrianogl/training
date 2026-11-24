import Charts
import GarminAPI
import WorkoutAnalysis
import SwiftUI

struct RacePlanCard: View {
    let comparison: RacePlanComparison
    let resultSeconds: Double?
    let eveSeconds: Double?
    let onChange: () -> Void

    private typealias C = RacePlanConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                stat(resultSeconds.map(WorkoutFormat.clock) ?? "—", C.yourTime)
                stat(comparison.planSeconds.map(WorkoutFormat.clock) ?? "—", comparison.sourceName == nil ? C.appStrategyLabel : C.paceProLabel)
                stat(eveSeconds.map(WorkoutFormat.clock) ?? "—", C.eveLabel)
            }
            Text(comparison.verdict).font(.subheadline).foregroundStyle(BrandColors.text)
            Button(action: onChange) {
                HStack {
                    Text(C.planPrefix).foregroundStyle(BrandColors.dim)
                    + Text(comparison.sourceName ?? C.useAppStrategy).foregroundStyle(BrandColors.text).bold()
                    Spacer()
                    Text(C.change).foregroundStyle(BrandColors.accent).fontWeight(.semibold)
                }
                .font(.caption)
                .padding(10)
                .background(BrandColors.track, in: .dsInner)
            }
            .buttonStyle(.plain)
        }
        .brandCard()
        VStack(alignment: .leading, spacing: 10) {
            DSCardLabel(C.cumulativeTitle)
            chart
        }
        .brandCard()
        VStack(alignment: .leading, spacing: 10) {
            DSCardLabel(C.tableTitle)
            table
        }
        .brandCard()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        DSStat(value: value, label: label, size: .large)
    }

    private var chart: some View {
        Chart(comparison.rows) { row in
            BarMark(x: .value("Km", "\(row.index + 1)"), y: .value("Diferença", row.cumulative))
                .foregroundStyle(row.cumulative > 0 ? BrandColors.attention : BrandColors.accentFill)
                .cornerRadius(3)
            RuleMark(y: .value("Plano", 0)).foregroundStyle(BrandColors.marker)
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let seconds = value.as(Double.self) { Text(RacePlanComparisonBuilder.signedGap(seconds)).font(.caption2).foregroundStyle(BrandColors.dim) }
                }
            }
        }
        .chartXAxis {
            AxisMarks { _ in AxisValueLabel().foregroundStyle(BrandColors.dim) }
        }
        .frame(height: C.chartHeight)
    }

    private var table: some View {
        Grid(alignment: .trailing, horizontalSpacing: 8, verticalSpacing: 6) {
            GridRow {
                ForEach(Array(C.columns.enumerated()), id: \.offset) { index, title in
                    Text(title).font(.caption2.weight(.semibold)).textCase(.uppercase).foregroundStyle(BrandColors.dim)
                        .frame(maxWidth: .infinity, alignment: index == 0 ? .leading : .trailing)
                        .gridColumnAlignment(index == 0 ? .leading : .trailing)
                }
            }
            ForEach(comparison.rows) { row in
                GridRow {
                    HStack(spacing: 4) {
                        Text("\(row.index + 1)").foregroundStyle(BrandColors.text)
                        if row.hasWater {
                            Text(C.waterTag)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(C.waterColor)
                                .padding(.horizontal, 5)
                                .background(C.waterColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                    }
                    Text(WorkoutFormat.clock(row.planned)).foregroundStyle(BrandColors.dim)
                    Text(WorkoutFormat.clock(row.done)).foregroundStyle(BrandColors.text)
                    Text(RacePlanComparisonBuilder.signedGap(row.delta)).foregroundStyle(color(row.delta))
                    Text(RacePlanComparisonBuilder.signedGap(row.cumulative)).foregroundStyle(row.cumulative > 0 ? BrandColors.attention : BrandColors.accent)
                }
                .font(BrandFonts.number(13))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func color(_ delta: Double) -> Color {
        delta > C.evenTolerance ? BrandColors.attention : delta < -C.evenTolerance ? BrandColors.accent : BrandColors.dim
    }
}

struct RacePlanPickerSheet: View {
    let summaries: [PaceProSummary]
    let selected: Int64?
    let onPick: (Int64?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button { onPick(0); dismiss() } label: {
                    row(RacePlanConstants.useAppStrategy, detail: nil, isOn: selected == nil)
                }
                ForEach(summaries) { summary in
                    Button { onPick(summary.id); dismiss() } label: {
                        row(summary.name, detail: [RacesText.distanceText(summary.distance), summary.goalSeconds.map(WorkoutFormat.clock)].compactMap { $0 }.joined(separator: " · "), isOn: selected == summary.id)
                    }
                }
            }
            .navigationTitle(RacePlanConstants.pickerTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private func row(_ title: String, detail: String?, isOn: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(BrandColors.text)
                if let detail { Text(detail).font(.caption).foregroundStyle(BrandColors.dim) }
            }
            Spacer()
            if isOn { Image(systemName: "checkmark").foregroundStyle(BrandColors.accent) }
        }
    }
}
