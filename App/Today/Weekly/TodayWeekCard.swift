import Charts
import SwiftUI
import TrainingCore

struct TodayWeekCard: View {
    let report: WeeklyReport
    let isClosed: Bool
    let series: VolumeSeries
    var strength: [Day: String] = [:]
    var warnings: [String] = []

    @Environment(\.horizontalSizeClass) private var sizeClass
    private typealias C = WeeklyReportConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title).padding(.top, 0).padding(.bottom, 0)
            HStack(alignment: .firstTextBaseline) {
                Text(bigText).font(BrandFonts.number(30)).foregroundStyle(BrandColors.text)
                Spacer()
                if let percent = report.percent {
                    Text(String(format: C.percentFormat, percent))
                        .font(BrandFonts.number(22))
                        .foregroundStyle((report.adherence ?? 0) >= TodayConstants.volumePercentGood ? BrandColors.accent : BrandColors.attention)
                }
            }
            WeeklyDaysRow(days: report.days, compact: sizeClass != .regular, strength: strength)
            ForEach(warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 8) {
                    Text("!").font(.footnote.weight(.bold)).foregroundStyle(BrandColors.attention)
                    Text(warning).font(.footnote).foregroundStyle(BrandColors.text)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            if series.points.count > 1 {
                sparkline
            }
            Text(footer).font(.caption).foregroundStyle(BrandColors.dim)
            NavigationLink(value: TodayRoute.week) { CardLinkFooter(title: CardLinkConstants.week) }
                .buttonStyle(.cardLink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private var title: String {
        let format = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(WorkoutConstants.locale)
        let range = String(format: C.rangeFormat, report.start.chartDate.formatted(format), report.start.adding(days: 6).chartDate.formatted(format))
        return isClosed ? String(format: C.closedTitleFormat, range) : String(format: C.openTitleFormat, range)
    }

    private var bigText: AttributedString {
        let done = TodayText.decimal(report.doneKm, fractionDigits: 1)
        guard let planned = report.plannedKm else { return AttributedString(String(format: C.bigNoPlanFormat, done)) }
        var text = AttributedString(done)
        var tail = AttributedString(String(format: C.bigTailFormat, TodayText.decimal(planned, fractionDigits: 1)))
        tail.font = BrandFonts.number(15)
        tail.foregroundColor = BrandColors.dim
        text.append(tail)
        return text
    }

    private var sparkline: some View {
        Chart {
            ForEach(series.points) { point in
                if let planned = point.plannedKm {
                    LineMark(x: .value("Semana", point.start.chartDate), y: .value("Planejado", planned), series: .value("Linha", "plan"))
                        .foregroundStyle(BrandColors.dim)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            ForEach(series.points) { point in
                LineMark(x: .value("Semana", point.start.chartDate), y: .value("km", point.kilometers), series: .value("Linha", "done"))
                    .foregroundStyle(BrandColors.accentFill)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                PointMark(x: .value("Semana", point.start.chartDate), y: .value("km", point.kilometers))
                    .foregroundStyle((point.ratio ?? 1) >= TodayConstants.volumePercentGood ? BrandColors.accentFill : BrandColors.attention)
                    .symbolSize(C.sparkPointSize)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: C.sparkHeight)
        .accessibilityHidden(true)
    }

    private var footer: String {
        var parts = [String(format: C.sparkWeeksFormat, series.points.count)]
        if let percent = series.adherencePercent { parts.append(String(format: C.sparkAdherenceFormat, percent)) }
        if series.average4Weeks > 0 { parts.append(String(format: C.sparkAverageFormat, TodayText.decimal(series.average4Weeks, fractionDigits: 0))) }
        return parts.joined(separator: " · ")
    }
}
