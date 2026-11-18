import SwiftUI
import WorkoutAnalysis

struct RaceTargetCard: View {
    let target: RaceTargetData
    var weather: RaceWeatherReading?

    private typealias C = RacesConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(C.targetTitle)
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(BrandColors.race)
                Spacer()
                Text("\(target.days)").font(BrandFonts.number(C.targetDaysFontSize)).foregroundStyle(BrandColors.race)
                Text(C.daysLabel).font(.caption).foregroundStyle(BrandColors.dim)
            }
            Text("\(target.name) · \(target.dateText)")
                .font(.headline)
                .foregroundStyle(BrandColors.text)
                .lineLimit(2)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(C.predictionLabel).foregroundStyle(BrandColors.dim)
                Text(target.predictionSeconds.map(WorkoutFormat.clock) ?? "—").font(BrandFonts.number(C.targetClockFontSize)).foregroundStyle(BrandColors.text)
                Spacer()
                Text(C.goalLabel).foregroundStyle(BrandColors.dim)
                Text(target.goalSeconds.map(WorkoutFormat.clock) ?? "—").font(BrandFonts.number(C.targetClockFontSize)).foregroundStyle(BrandColors.accent)
            }
            .font(.caption)
            if let prediction = target.predictionSeconds, let goal = target.goalSeconds {
                GoalPredictionBar(today: prediction, target: goal).frame(height: GoalsConstants.barHeight)
            }
            if let weather {
                Text(RaceWeatherText.list(weather) + RaceWeatherConstants.separator + RaceWeatherText.detail(weather))
                    .font(.caption)
                    .foregroundStyle(weather.effect.isHeat ? BrandColors.race : BrandColors.dim)
            }
            Text([target.distanceText, target.gapText].compactMap { $0 }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
        .contentShape(Rectangle())
    }
}
