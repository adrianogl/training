import SwiftUI
import WorkoutAnalysis

struct RaceTargetCard<Footer: View>: View {
    let target: RaceTargetData
    var weather: RaceWeatherReading?
    @ViewBuilder var footer: Footer

    private typealias C = RacesConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                DSCardLabel(String(format: C.targetLabelFormat, target.dateText))
                Spacer()
                Text(RacesText.countdownText(days: target.days))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BrandColors.race)
            }
            Text(target.name)
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
                GoalPredictionBar(today: prediction, target: goal)
            }
            if let weather {
                weatherBox(weather)
            }
            Text([target.distanceText, target.gapText].compactMap { $0 }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
            footer.padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
        .contentShape(Rectangle())
    }

    private func weatherBox(_ weather: RaceWeatherReading) -> some View {
        let tint = RaceWeatherText.tint(weather)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: RunWeatherBandConstants.symbol).font(.caption.weight(.semibold))
                Text(String(format: RunWeatherBandConstants.degreeFormat, Int(weather.effect.weather.temperature.rounded())))
                    .font(BrandFonts.number(C.targetClockFontSize))
                Text(RaceWeatherText.cost(weather)).font(.footnote.weight(.semibold))
            }
            .foregroundStyle(tint)
            Text(RaceWeatherText.context(weather))
                .font(.caption)
                .foregroundStyle(BrandColors.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RunWeatherBandConstants.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(RunWeatherBandConstants.backgroundOpacity), in: .dsInner)
    }
}
