import Charts
import SwiftUI
import WorkoutAnalysis

struct ZoneWeeksCard: View {
    let weeks: [ZoneWeek]

    private typealias C = EvolutionExtrasConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DSCardLabel(C.zonesTitle)
            Chart {
                ForEach(weeks, id: \.start) { week in
                    ForEach(Array(week.seconds.enumerated()), id: \.offset) { zone, seconds in
                        BarMark(
                            x: .value("semana", week.start.chartDate, unit: .weekOfYear),
                            y: .value("horas", seconds / 3_600)
                        )
                        .foregroundStyle(BrandColors.zone(zone + 1))
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated).locale(WorkoutConstants.locale))
                }
            }
            .frame(height: 150)
            if let share = EvolutionExtras.easyShare(weeks) {
                Text(String(format: C.zonesFootFormat, Int((share * 100).rounded()), C.zoneWeeks))
                    .font(.caption).foregroundStyle(BrandColors.dim)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .brandCard()
    }
}

struct RecordsCard: View {
    let records: [PersonalRecord]
    let now: Date

    private typealias C = EvolutionExtrasConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSCardLabel(C.recordsTitle)
            if records.isEmpty {
                Text(C.recordsEmpty).font(.subheadline).foregroundStyle(BrandColors.dim)
            }
            ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                if index > 0 { Divider().overlay(BrandColors.line) }
                HStack(alignment: .firstTextBaseline) {
                    Text(record.label).font(.subheadline.weight(.semibold)).frame(width: 64, alignment: .leading)
                    Text(WorkoutFormat.clock(record.seconds)).font(BrandFonts.number(18))
                    if let meters = record.meters, meters > 0 {
                        Text(WorkoutListModel.paceText(secondsPerKilometer: record.seconds / (meters / WorkoutConstants.metersPerKilometer)))
                            .font(BrandFonts.number(13))
                            .foregroundStyle(BrandColors.dim)
                    }
                    if now.timeIntervalSince(record.date) <= Double(C.recentDays) * 86_400 {
                        DSChip(text: C.newRecord, tone: .accent, style: .solid)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(record.date.formatted(.dateTime.day().month(.abbreviated).year().locale(WorkoutConstants.locale)))
                            .font(.caption).foregroundStyle(BrandColors.dim)
                        Text(record.source).font(.caption2).foregroundStyle(BrandColors.dim).lineLimit(1)
                    }
                }
                .foregroundStyle(BrandColors.text)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .brandCard()
    }
}
