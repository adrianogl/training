import Charts
import Insights
import TrainingCore
import SwiftUI

struct VolumeHistoryCard: View {
    let week: WeekVolume

    private typealias C = TodayConstants

    var body: some View {
        let weeks = week.recentWeeks
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(C.volumeTitle).padding(.top, 0).padding(.bottom, 0)
            Chart {
                ForEach(Array(weeks.enumerated()), id: \.offset) { index, item in
                    let isCurrent = index == weeks.count - 1
                    BarMark(
                        x: .value("Semana", label(item.start)),
                        y: .value("km", item.kilometers)
                    )
                    .foregroundStyle(BrandColors.fitness.opacity(isCurrent ? C.volumeCurrentOpacity : 1))
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        Text(TodayText.decimal(item.kilometers, fractionDigits: 0))
                            .font(.caption2)
                            .foregroundStyle(isCurrent ? BrandColors.text : BrandColors.dim)
                    }
                }
                if week.average4Weeks > 0 {
                    RuleMark(y: .value(C.volumeAverageLabel, week.average4Weeks))
                        .foregroundStyle(BrandColors.marker)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(BrandColors.dim)
                }
            }
            .frame(height: C.volumeChartHeight)
            Text(String(format: C.volumeFooterFormat, TodayText.decimal(week.total, fractionDigits: 1), TodayText.decimal(week.average4Weeks, fractionDigits: 1)))
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
        }
        .brandCard(fillsHeight: true)
    }

    private func label(_ day: Day) -> String {
        let formatter = DateFormatter()
        formatter.locale = WorkoutConstants.locale
        formatter.dateFormat = C.volumeWeekFormat
        return formatter.string(from: day.chartDate).replacingOccurrences(of: ".", with: "")
    }
}
