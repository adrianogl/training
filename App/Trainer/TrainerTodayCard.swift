import Insights
import SwiftUI

struct TrainerTodayCard: View {
    let model: TrainerModel

    var body: some View {
        NavigationLink(value: TodayRoute.trainer) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    SectionLabel(TrainerText.cardTitle).padding(.vertical, 0)
                    TrainerBetaBadge()
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(BrandColors.dim)
                }
                if model.plan == nil {
                    Text(TrainerText.cardInvite).font(.footnote).foregroundStyle(BrandColors.text)
                    Text(TrainerText.cardCreate).font(.footnote.weight(.bold)).foregroundStyle(BrandColors.accent)
                } else {
                    line(label: TrainerText.cardToday, row: model.todayRow, empty: TrainerText.cardRestToday)
                    line(label: TrainerText.cardNext, row: model.nextRow, empty: TrainerText.cardEmptyNext)
                }
            }
            .brandCard()
        }
        .buttonStyle(.plain)
    }

    private func line(label: String, row: TrainerDayRow?, empty: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).font(.caption).foregroundStyle(BrandColors.dim).frame(width: 52, alignment: .leading)
            if let row, row.workout.kind != .off {
                RoundedRectangle(cornerRadius: 2)
                    .fill(TrainerConstants.color(for: row.workout.kind))
                    .frame(width: 4, height: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.workout.title).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                    Text(subtitle(row)).font(.caption).foregroundStyle(BrandColors.dim)
                }
            } else {
                Text(empty).font(.footnote).foregroundStyle(BrandColors.dim)
            }
            Spacer(minLength: 0)
        }
    }

    private func subtitle(_ row: TrainerDayRow) -> String {
        let summary = TrainerText.summaryLine(row.workout)
        let day = row.workout.day == model.currentDay ? TrainerText.todayStatus : TrainerText.longDate(row.workout.day)
        return summary.isEmpty ? day : "\(day) · \(summary)"
    }
}
