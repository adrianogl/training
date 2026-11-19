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
            HStack(spacing: DSSpacing.s3) {
                ForEach(Array(C.zoneLabels.enumerated()), id: \.offset) { index, label in
                    DSLegendItem(text: label, color: BrandColors.zone(index + 1), mark: .square)
                }
            }
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
            ForEach(Array(C.records.enumerated()), id: \.offset) { index, target in
                if index > 0 { Divider().overlay(BrandColors.line) }
                row(target.label, record: records.first { $0.label == target.label })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .brandCard()
    }

    private func row(_ label: String, record: PersonalRecord?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: C.recordLabelWidth, alignment: .leading)
            if let record {
                Text(WorkoutFormat.clock(record.seconds)).font(BrandFonts.number(18)).lineLimit(1).fixedSize()
                if let meters = record.meters, meters > 0 {
                    Text(WorkoutListModel.paceText(secondsPerKilometer: record.seconds / (meters / WorkoutConstants.metersPerKilometer)))
                        .font(BrandFonts.number(13))
                        .foregroundStyle(BrandColors.dim)
                        .lineLimit(1)
                        .fixedSize()
                }
                if now.timeIntervalSince(record.date) <= Double(C.recentDays) * 86_400 {
                    DSChip(text: C.newRecord, tone: .accent, style: .solid)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(dateText(record.date)).font(.caption).foregroundStyle(BrandColors.dim)
                    Text(record.source).font(.caption2).foregroundStyle(BrandColors.dim).lineLimit(1)
                }
            } else {
                Text(C.recordMissing).font(.footnote).foregroundStyle(BrandColors.dim)
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(BrandColors.text)
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = WorkoutConstants.locale
        formatter.dateFormat = C.recordDateFormat
        return formatter.string(from: date)
    }
}
