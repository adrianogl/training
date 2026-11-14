import SwiftUI

struct WeeklyReportCard: View {
    let report: WeeklyReport

    private typealias C = WeeklyReportConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(report.isCurrentWeek ? C.titleCurrent : C.titlePrevious).padding(.top, 0).padding(.bottom, 0)
                Spacer()
                Text(range).font(.caption).foregroundStyle(BrandColors.dim)
            }
            Text(report.headline).font(.title3.bold()).foregroundStyle(BrandColors.text)
            HStack(spacing: 18) {
                stat(TodayText.decimal(report.doneKm, fractionDigits: 1), C.doneLabel)
                if let planned = report.plannedKm { stat(TodayText.decimal(planned, fractionDigits: 1), C.plannedLabel) }
                if let adherence = report.adherence { stat("\(Int((adherence * 100).rounded()))%", C.adherenceLabel) }
                stat("\(report.runs)", C.runsLabel)
            }
            if !report.text.isEmpty {
                Text(report.text).font(.subheadline).foregroundStyle(BrandColors.text).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private var range: String {
        let format = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(WorkoutConstants.locale)
        return String(format: C.rangeFormat, report.start.chartDate.formatted(format), report.start.adding(days: 6).chartDate.formatted(format))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(BrandFonts.number(22)).foregroundStyle(BrandColors.text)
            Text(label).font(.caption).foregroundStyle(BrandColors.dim)
        }
    }
}
