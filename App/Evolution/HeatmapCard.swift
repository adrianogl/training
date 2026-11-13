import SwiftUI

struct HeatmapCard: View {
    let columns: [[HeatmapCell]]

    private typealias C = EvolutionConstants

    var body: some View {
        let total = columns.flatMap { $0 }.reduce(0) { $0 + $1.kilometers }
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(C.heatmapTitle).padding(.top, 0).padding(.bottom, 0)
            HStack(alignment: .top, spacing: 6) {
                VStack(spacing: C.heatmapCellSpacing) {
                    Color.clear.frame(height: 12)
                    ForEach(Array(C.heatmapWeekdayLabels.enumerated()), id: \.offset) { _, label in
                        Text(label)
                            .font(.system(size: 9))
                            .foregroundStyle(BrandColors.dim)
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(width: C.heatmapLabelWidth)
                HStack(alignment: .top, spacing: C.heatmapCellSpacing) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { index, week in
                        VStack(spacing: C.heatmapCellSpacing) {
                            Text(monthLabel(index))
                                .font(.system(size: 9))
                                .foregroundStyle(BrandColors.dim)
                                .fixedSize()
                                .frame(height: 12, alignment: .leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(week) { cell in
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(color(cell))
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
            }
            HStack {
                Text(String(format: C.heatmapTotalFormat, TodayText.decimal(total, fractionDigits: 0)))
                Spacer()
                Text(C.heatmapLess)
                ForEach(C.heatmapScaleSteps, id: \.self) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(step == 0 ? BrandColors.track : BrandColors.accentFill.opacity(C.heatmapMinimumOpacity + (1 - C.heatmapMinimumOpacity) * step))
                        .frame(width: C.heatmapScaleCell, height: C.heatmapScaleCell)
                }
                Text(C.heatmapMore)
            }
            .font(.caption2)
            .foregroundStyle(BrandColors.dim)
        }
        .brandCard()
    }

    private func monthLabel(_ index: Int) -> String {
        guard let first = columns[index].first else { return "" }
        if index > 0, let previous = columns[index - 1].first, previous.day.month == first.day.month { return "" }
        let formatter = DateFormatter()
        formatter.locale = WorkoutConstants.locale
        formatter.dateFormat = C.heatmapMonthFormat
        return formatter.string(from: first.day.chartDate).replacingOccurrences(of: ".", with: "")
    }

    private func color(_ cell: HeatmapCell) -> Color {
        if cell.isFuture { return .clear }
        if cell.kilometers <= 0 { return BrandColors.track }
        return BrandColors.accentFill.opacity(C.heatmapMinimumOpacity + (1 - C.heatmapMinimumOpacity) * cell.level)
    }
}
