import SwiftUI
import TrainingCore

struct WeekCalendarCard: View {
    let runs: [Day: [WeekRun]]
    let today: Day
    var goal = 0
    @Environment(\.horizontalSizeClass) private var sizeClass

    private typealias C = TodayConstants

    var body: some View {
        let days = (0..<Int(C.daysPerWeek)).map { today.weekStart.adding(days: $0) }
        let all = runs.values.flatMap { $0 }
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(C.calendarTitle).padding(.top, 0).padding(.bottom, 0)
                Spacer()
                Text(String(format: C.calendarSummaryFormat, TodayText.decimal(all.reduce(0) { $0 + $1.kilometers }, fractionDigits: 1), all.count) + (goal > 0 ? String(format: C.calendarGoalFormat, goal) : ""))
                    .font(.caption)
                    .foregroundStyle(BrandColors.dim)
            }
            if sizeClass == .regular {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(days, id: \.self) { day in cell(day).frame(maxWidth: .infinity) }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(days, id: \.self) { day in cell(day).frame(width: C.calendarCompactCellWidth) }
                    }
                }
            }
        }
        .brandCard()
    }

    private func cell(_ day: Day) -> some View {
        let dayRuns = runs[day] ?? []
        let isToday = day == today
        let isFuture = today < day
        let shape = RoundedRectangle(cornerRadius: C.calendarCornerRadius, style: .continuous)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dayLabel(day)).font(.caption2).foregroundStyle(BrandColors.dim)
                Spacer()
                if !dayRuns.isEmpty {
                    Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(BrandColors.accent)
                }
            }
            if dayRuns.isEmpty {
                Text(isFuture || isToday ? C.calendarFuture : C.calendarRest)
                    .font(.footnote)
                    .foregroundStyle(BrandColors.dim)
            }
            ForEach(dayRuns) { run in
                VStack(alignment: .leading, spacing: 4) {
                    Text(run.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BrandColors.text)
                        .lineLimit(2)
                    ZoneStrip(shares: run.zoneShares)
                    Text("\(TodayText.decimal(run.kilometers, fractionDigits: 1)) km")
                        .font(BrandFonts.number(18))
                        .foregroundStyle(BrandColors.text)
                    if let score = run.score {
                        Text(String(format: C.calendarScoreFormat, score))
                            .font(.caption2)
                            .foregroundStyle(BrandColors.dim)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: C.calendarCellMinHeight, alignment: .topLeading)
        .background(dayRuns.isEmpty ? Color.clear : BrandColors.accentFill.opacity(C.calendarDoneTintOpacity), in: shape)
        .overlay {
            if isToday {
                shape.strokeBorder(BrandColors.accentFill, lineWidth: 2)
            } else if isFuture {
                shape.strokeBorder(BrandColors.line, style: StrokeStyle(lineWidth: 1, dash: C.calendarDash))
            } else if dayRuns.isEmpty {
                shape.strokeBorder(BrandColors.line, lineWidth: 1)
            }
        }
    }

    private func dayLabel(_ day: Day) -> String {
        let formatter = DateFormatter()
        formatter.locale = WorkoutConstants.locale
        formatter.dateFormat = C.calendarDayFormat
        return formatter.string(from: day.chartDate).replacingOccurrences(of: ".", with: "")
    }
}

struct ZoneStrip: View {
    let shares: [Double]

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 1) {
                ForEach(Array(shares.enumerated()), id: \.offset) { index, share in
                    if share > 0 {
                        Rectangle()
                            .fill(BrandColors.zone(index + 1))
                            .frame(width: max(1, proxy.size.width * share - 1))
                    }
                }
            }
        }
        .frame(height: TodayConstants.zoneStripHeight)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}
