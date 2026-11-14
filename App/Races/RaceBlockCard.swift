import Charts
import Metrics
import SwiftUI
import TrainingCore

struct RaceBlockCard: View {
    let block: [BlockWeek]
    let today: Day
    let reading: String
    var longest: [Day: Double] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(RacesConstants.blockTitle).padding(.top, 0).padding(.bottom, 0)
            Chart {
                ForEach(block, id: \.start) { week in
                    BarMark(x: .value("Semana", week.start.chartDate, unit: .weekOfYear), y: .value("km", week.km))
                        .foregroundStyle(week.projected ? BrandColors.accent.opacity(0.12) : BrandColors.accent)
                        .annotation(position: .overlay) {
                            if week.projected {
                                Rectangle()
                                    .strokeBorder(BrandColors.accent, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            }
                        }
                }
                ForEach(block.filter { longest[$0.start] != nil }, id: \.start) { week in
                    LineMark(x: .value("Semana", week.start.chartDate, unit: .weekOfYear), y: .value("Longão", longest[week.start] ?? 0))
                        .foregroundStyle(BrandColors.race)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("Semana", week.start.chartDate, unit: .weekOfYear), y: .value("Longão", longest[week.start] ?? 0))
                        .foregroundStyle(BrandColors.race)
                        .symbolSize(30)
                }
                RuleMark(x: .value("Hoje", today.weekStart.chartDate, unit: .weekOfYear))
                    .foregroundStyle(BrandColors.marker)
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisValueLabel().foregroundStyle(BrandColors.dim)
                }
            }
            .frame(height: RacesConstants.blockChartHeight)
            Text(longest.isEmpty ? RacesConstants.blockLegend : RacesConstants.blockLegendWithLong).font(.caption2).foregroundStyle(BrandColors.dim)
            Text(RacesConstants.readingTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandColors.text)
                .padding(.top, 4)
            Text(reading)
                .font(.footnote)
                .foregroundStyle(BrandColors.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .brandCard()
    }
}
