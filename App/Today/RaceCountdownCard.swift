import SwiftUI

struct RaceCountdownCard: View {
    let model: TodayModel
    let days: Int
    @Environment(\.horizontalSizeClass) private var sizeClass

    private typealias C = TodayConstants

    var body: some View {
        let race = model.summary.race
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(title).padding(.top, 0).padding(.bottom, 0)
                Spacer()
                if !race.label.isEmpty {
                    Text(race.label).font(.caption).foregroundStyle(BrandColors.dim)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(days)")
                    .font(BrandFonts.number(sizeClass == .regular ? C.countdownFontSize : C.compactCountdownFontSize))
                    .foregroundStyle(BrandColors.race)
                Text(C.daysLabel).foregroundStyle(BrandColors.dim)
            }
            if let name = model.raceName {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(BrandColors.text)
                    .lineLimit(2)
            }
            weekStrip
            GoalBulletChart(today: race.today, raceDay: race.raceDay?.mid, goal: race.goalSeconds)
            if let form = model.summary.fitness.raceDayForm {
                HStack(spacing: 6) {
                    Text(C.raceDayFormLabel).foregroundStyle(BrandColors.dim)
                    Text(TodayText.signed(form)).font(BrandFonts.number(15)).foregroundStyle(BrandColors.accent)
                }
                .font(.caption)
            }
        }
        .brandCard(fillsHeight: true)
        .background(alignment: .topLeading) {
            RadialGradient(colors: [BrandColors.raceGlow, .clear], center: .topLeading, startRadius: 0, endRadius: 260)
                .clipShape(RoundedRectangle(cornerRadius: BrandConstants.cardCornerRadius, style: .continuous))
                .allowsHitTesting(false)
        }
    }

    private var title: String {
        guard let day = model.raceDay else { return C.sidebarRaceTitle }
        return "\(C.sidebarRaceTitle) · \(day.chartDate.formatted(.dateTime.day().month(.abbreviated).locale(WorkoutConstants.locale)))"
    }

    private var weekStrip: some View {
        let weeks = max(1, Int((Double(days) / TodayConstants.daysPerWeek).rounded(.up)))
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<weeks, id: \.self) { index in
                    Capsule()
                        .fill(index == 0 ? BrandColors.race : BrandColors.track)
                        .frame(height: C.weekStripHeight)
                }
            }
            Text(TodayText.weeksLeft(days: days))
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
        }
    }
}
