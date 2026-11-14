import SwiftUI

struct RaceTaperCard: View {
    let plan: TaperPlan

    private typealias C = RaceTaperConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(C.title).padding(.top, 0).padding(.bottom, 0)
                Spacer()
                Text(String(format: C.weekFormat, plan.daysLeft > C.daysPerWeek ? 1 : 2, 2))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BrandColors.fitness)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(BrandColors.fitness.opacity(0.14), in: Capsule())
            }
            let scale = max(plan.weeks.map { max($0.doneKm, $0.targetKm ?? 0) }.max() ?? 1, 1)
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(Array(plan.weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 4) {
                        Text(week.targetKm.map { "\(C.targetLabel) \(TodayText.decimal($0, fractionDigits: 0))" } ?? " ")
                            .font(.caption2).foregroundStyle(BrandColors.dim)
                        ZStack(alignment: .bottom) {
                            Color.clear
                            if let target = week.targetKm {
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(BrandColors.accentFill, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                    .frame(height: C.chartHeight * target / scale)
                            }
                            RoundedRectangle(cornerRadius: 5)
                                .fill(week.isRaceWeek ? BrandColors.race.opacity(0.7) : BrandColors.accentFill)
                                .frame(height: max(2, C.chartHeight * week.doneKm / scale))
                        }
                        .frame(height: C.chartHeight)
                        Text("\(TodayText.decimal(week.doneKm, fractionDigits: 0)) km").font(BrandFonts.number(13)).foregroundStyle(BrandColors.text)
                        Text(week.isRaceWeek ? C.race : week.start.chartDate.formatted(.dateTime.day().month(.abbreviated).locale(WorkoutConstants.locale)))
                            .font(.caption2).foregroundStyle(BrandColors.dim)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text(plan.advice).font(.subheadline).foregroundStyle(BrandColors.text).fixedSize(horizontal: false, vertical: true)
            Text(String(format: C.baseFormat, TodayText.decimal(plan.baseKm, fractionDigits: 0))).font(.caption).foregroundStyle(BrandColors.dim)
            if let best = plan.best {
                let delta = RacesText.signedClock(best.deltaToGoal, minus: 0) ?? ""
                Text(best.reduction < C.keptThreshold
                    ? String(format: C.bestKeptFormat, best.name, delta)
                    : String(format: C.bestFormat, best.name, Int((best.reduction * 100).rounded()), delta))
                    .font(.caption).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}
