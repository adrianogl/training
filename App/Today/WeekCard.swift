import SwiftUI
import TrainingCore

struct WeekCard: View {
    let model: TodayModel

    var body: some View {
        let week = model.summary.week
        let start = model.today.weekStart
        let values = (0..<7).map { week.perDay[start.adding(days: $0)] }
        let peak = max(values.compactMap { $0 }.max() ?? 0, 1)
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("\(TodayConstants.weekTitle) · \(TodayText.decimal(week.total, fractionDigits: 0)) km")
                .padding(.top, 0)
                .padding(.bottom, 0)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    let km = values[index] ?? 0
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(km > 0 ? BrandColors.accent : BrandColors.track)
                        .frame(height: max(TodayConstants.weekBarMinimum, TodayConstants.weekBarHeight * km / peak))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: TodayConstants.weekBarHeight, alignment: .bottom)
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    Text(TodayConstants.weekdayLetters[index])
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.caption2)
            .foregroundStyle(BrandColors.dim)
            Text(String(
                format: TodayConstants.weekFooter,
                TodayText.decimal(week.lastWeek, fractionDigits: 0),
                TodayText.decimal(week.average4Weeks, fractionDigits: 0)
            ))
            .font(.caption)
            .foregroundStyle(BrandColors.dim)
        }
        .glassCard()
    }
}
