import SwiftUI
import TrainingCore
import WorkoutAnalysis

struct RaceWeatherLine: View {
    private typealias B = RunWeatherBandConstants
    let reading: RaceWeatherReading
    let goalSeconds: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: B.padding) {
                Text(String(format: B.degreeFormat, Int(reading.effect.weather.temperature.rounded())))
                    .font(BrandFonts.number(B.degreeFontSize))
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(RaceWeatherText.lead(reading))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandColors.text)
                    Text(RaceWeatherText.detail(reading))
                        .font(.caption)
                        .foregroundStyle(BrandColors.dim)
                }
                Spacer(minLength: 0)
            }
            .padding(B.padding)
            .background(tint.opacity(B.backgroundOpacity), in: RoundedRectangle(cornerRadius: B.cornerRadius))
            if let goal = RaceWeatherText.goal(reading, goalSeconds: goalSeconds) {
                Text(goal)
                    .font(.footnote)
                    .foregroundStyle(BrandColors.dim)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        reading.effect.isCold ? BrandColors.fitness : reading.effect.isHeat ? BrandColors.race : BrandColors.dim
    }
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

    static func list(_ reading: RaceWeatherReading) -> String {
        String(format: C.listFormat, Int(reading.effect.weather.temperature.rounded()), WorkoutFormat.clock(reading.adjustedSeconds))
    }
}
