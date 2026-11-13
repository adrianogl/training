import Charts
import Insights
import SwiftUI
import TrainingCore

struct VolumeHistoryCard: View {
    let week: WeekVolume
    var goal = 0
    var planned: [Day: Double] = [:]

    private typealias C = TodayConstants

    var body: some View {
        let weeks = week.recentWeeks
        let current = weeks.last?.start
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(planned.isEmpty ? C.volumeTitle : C.volumeTitlePlanned).padding(.top, 0).padding(.bottom, 0)
            Chart {
                ForEach(weeks, id: \.start) { item in
                    let label = label(item.start)
                    if let plan = planned[item.start] {
                        BarMark(x: .value("Semana", label), y: .value("Planejado", plan), width: .ratio(C.volumePlannedWidth), stacking: .unstacked)
                            .foregroundStyle(BrandColors.fitness.opacity(C.volumePlannedOpacity))
                            .cornerRadius(4)
                    }
                    BarMark(x: .value("Semana", label), y: .value("km", item.kilometers), width: .ratio(planned.isEmpty ? 0.6 : C.volumeDoneWidth), stacking: .unstacked)
                        .foregroundStyle(BrandColors.fitness.opacity(item.start == current ? C.volumeCurrentOpacity : 1))
                        .cornerRadius(4)
                        .annotation(position: .top) {
                            Text(annotation(item))
                                .font(.caption2)
                                .foregroundStyle(color(item))
                        }
                }
                if goal > 0 {
                    RuleMark(y: .value(C.volumeGoalLabel, Double(goal)))
                        .foregroundStyle(BrandColors.accent)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("\(C.volumeGoalLabel) \(goal) km").font(.caption2.weight(.bold)).foregroundStyle(BrandColors.accent)
                        }
                }
                if week.average4Weeks > 0 && planned.isEmpty {
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
            Text(footer)
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
        }
        .brandCard(fillsHeight: true)
    }

    private var closedAdherence: Double? {
        let closed = week.recentWeeks.dropLast().compactMap { item in planned[item.start].map { (done: item.kilometers, plan: $0) } }
        let plan = closed.reduce(0) { $0 + $1.plan }
        return plan > 0 ? closed.reduce(0) { $0 + $1.done } / plan : nil
    }

    private var footer: String {
        var parts = [String(format: C.volumeFooterFormat, TodayText.decimal(week.total, fractionDigits: 1), TodayText.decimal(week.average4Weeks, fractionDigits: 1))]
        if let adherence = closedAdherence {
            parts.append(String(format: C.adherenceSummaryFormat, Int((adherence * 100).rounded())))
            if let current = week.recentWeeks.last, let plan = planned[current.start], plan > current.kilometers {
                let projected = current.kilometers + (plan - current.kilometers) * min(adherence, 1)
                parts.append(String(format: C.projectionFormat, TodayText.decimal(projected, fractionDigits: 0)))
            }
        }
        return parts.joined(separator: " · ")
    }

    private func ratio(_ item: WeekTotal) -> Double? {
        guard item.start != week.recentWeeks.last?.start, let plan = planned[item.start], plan > 0 else { return nil }
        return item.kilometers / plan
    }

    private func annotation(_ item: WeekTotal) -> String {
        if let ratio = ratio(item) { return String(format: C.adherenceFormat, Int((ratio * 100).rounded())) }
        return TodayText.decimal(item.kilometers, fractionDigits: 0)
    }

    private func color(_ item: WeekTotal) -> Color {
        guard let ratio = ratio(item) else { return item.start == week.recentWeeks.last?.start ? BrandColors.text : BrandColors.dim }
        return ratio >= C.adherenceGood ? BrandColors.accent : BrandColors.attention
    }

    private func label(_ day: Day) -> String {
        let formatter = DateFormatter()
        formatter.locale = WorkoutConstants.locale
        formatter.dateFormat = C.volumeWeekFormat
        return formatter.string(from: day.chartDate).replacingOccurrences(of: ".", with: "")
    }
}
