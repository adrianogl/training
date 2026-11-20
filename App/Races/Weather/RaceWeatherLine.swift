import SwiftUI
import TrainingCore
import WorkoutAnalysis

struct RaceWeatherLine: View {
    private typealias B = RunWeatherBandConstants
    let reading: RaceWeatherReading
    let goalSeconds: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: B.symbol).font(.subheadline.weight(.semibold))
                    Text(String(format: B.degreeFormat, Int(reading.effect.weather.temperature.rounded())))
                        .font(BrandFonts.number(B.degreeFontSize))
                    Text(RaceWeatherText.cost(reading)).font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(tint)
                Text(RaceWeatherText.context(reading))
                    .font(.footnote)
                    .foregroundStyle(BrandColors.text.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(B.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(B.backgroundOpacity), in: RoundedRectangle(cornerRadius: B.cornerRadius, style: .continuous))
            if let goal = RaceWeatherText.goal(reading, goalSeconds: goalSeconds) {
                Text(goal)
                    .font(.footnote)
                    .foregroundStyle(BrandColors.dim)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var tint: Color { RaceWeatherText.tint(reading) }
}

enum RaceWeatherText {
    private typealias C = RaceWeatherConstants

    static func lead(_ reading: RaceWeatherReading) -> String {
        let format = reading.source == .forecast ? C.forecastLeadFormat : C.typicalLeadFormat
        return String(format: format, WorkoutFormat.clock(reading.adjustedSeconds))
    }

    static func detail(_ reading: RaceWeatherReading) -> String {
        let dew = reading.effect.isCold ? nil : reading.effect.weather.dewPoint.map { String(format: C.dewPointFormat, Int($0.rounded())) }
        let pace = reading.effect.paceFactor > 0 ? String(format: C.paceFormat, RunWeatherText.percent(reading.effect.paceFactor)) : nil
        return [
            dew,
            String(format: C.hoursFormat, reading.startHour, reading.endHour),
            pace,
            reading.source == .forecast ? C.forecastLabel : C.typicalLabel,
        ].compactMap { $0 }.joined(separator: C.separator)
    }

    static func goal(_ reading: RaceWeatherReading, goalSeconds: Double?) -> String? {
        guard let goalSeconds, goalSeconds > 0, reading.effect.paceFactor > 0 else { return nil }
        let gap = reading.adjustedSeconds - goalSeconds
        let word = reading.source == .forecast ? C.forecastWord : C.typicalWord
        let format = gap > 0 ? C.goalAboveFormat : C.goalBelowFormat
        return String(format: format, WorkoutFormat.clock(goalSeconds), WorkoutFormat.clock(abs(gap)), word)
    }

    static func tint(_ reading: RaceWeatherReading) -> Color {
        reading.effect.isCold ? BrandColors.fitness : reading.effect.isHeat ? BrandColors.race : BrandColors.dim
    }

    static func cost(_ reading: RaceWeatherReading) -> String {
        let seconds = reading.adjustedSeconds - reading.predictionSeconds
        guard reading.effect.paceFactor > 0, seconds >= 1 else { return C.neutralCaption }
        return String(format: C.costFormat, WorkoutFormat.clock(seconds), reading.effect.isCold ? C.coldWord : C.heatWord)
    }

    static func context(_ reading: RaceWeatherReading) -> String {
        let dew = reading.effect.isCold ? nil : reading.effect.weather.dewPoint.map { String(format: C.dewPointFormat, Int($0.rounded())) }
        return [
            lead(reading),
            dew,
            String(format: C.hoursFormat, reading.startHour, reading.endHour),
            reading.source == .forecast ? C.forecastLabel : C.typicalLabel,
        ].compactMap { $0 }.joined(separator: C.separator)
    }

    static func list(_ reading: RaceWeatherReading) -> String {
        String(format: C.listFormat, Int(reading.effect.weather.temperature.rounded()), WorkoutFormat.clock(reading.adjustedSeconds))
    }
}
