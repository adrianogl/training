import SwiftUI
import TrainingCore
import WorkoutAnalysis

enum RunWeatherText {
    private typealias C = RunWeatherBandConstants

    static func title(_ effect: WeatherEffect) -> String {
        if effect.isCold { return C.coldTitle }
        guard let dewPoint = effect.weather.dewPoint else { return C.mildTitle }
        let dew = String(format: C.dewPointFormat, Int(dewPoint.rounded()))
        return [dew, dewPoint >= C.muggyDewPoint ? C.muggy : nil, effect.isSunny ? C.sunny : nil].compactMap { $0 }.joined(separator: C.separator)
    }

    static func tint(_ effect: WeatherEffect) -> Color {
        effect.isCold ? BrandColors.fitness : effect.isHeat ? BrandColors.race : BrandColors.text
    }

    static func degrees(_ effect: WeatherEffect) -> String {
        String(format: C.degreeFormat, Int(effect.weather.temperature.rounded()))
    }

    static func caption(_ effect: WeatherEffect, pace: Double? = nil) -> String {
        guard effect.paceFactor > 0 else { return C.captionLabel }
        if let cost = cost(effect, pace: pace) {
            return String(format: C.captionCostFormat, Int(cost.rounded()), effect.isCold ? C.coldWord : C.heatWord)
        }
        return String(format: C.captionFormat, percent(effect.paceFactor))
    }

    static func cost(_ effect: WeatherEffect, pace: Double?, factor: Double? = nil) -> Double? {
        guard let pace, pace > 0 else { return nil }
        let value = pace - pace / (1 + (factor ?? effect.paceFactor))
        return value >= C.minimumCostSeconds ? value : nil
    }

    static func summary(_ effect: WeatherEffect, pace: Double? = nil) -> String {
        var sentences = [opening(effect, pace: pace)]
        if effect.adaptation > 0 {
            if effect.adaptation < 1, let raw = cost(effect, pace: pace, factor: effect.paceFactor / (1 - effect.adaptation)), cost(effect, pace: pace) != nil {
                sentences.append(String(format: C.adaptationCostFormat, effect.hotSessions, Int(raw.rounded())))
            } else {
                sentences.append(String(format: C.adaptationFormat, effect.hotSessions, Int((effect.adaptation * C.percentScale).rounded())))
            }
        }
        if let speed = effect.weather.windSpeed, let from = effect.weather.windFrom, speed * C.kmhPerMs >= C.windShownKmh {
            sentences.append(String(format: C.windFormat, Int((speed * C.kmhPerMs).rounded()), compass(from)))
        }
        return sentences.joined(separator: " ")
    }

    private static func opening(_ effect: WeatherEffect, pace: Double?) -> String {
        var text: String
        if effect.isCold {
            text = C.coldTitle
        } else if let dewPoint = effect.weather.dewPoint {
            text = String(format: dewPoint >= C.muggyDewPoint ? C.muggyOpeningFormat : C.dewOpeningFormat, Int(dewPoint.rounded()))
        } else {
            text = C.mildTitle
        }
        if effect.isSunny { text += C.sunnySuffix }
        guard effect.paceFactor > 0 else { return text + C.sentenceEnd }
        if let pace, let cost = cost(effect, pace: pace) {
            return text + String(format: C.costFormat, effect.isCold ? C.coldWord : C.heatWord, Int(cost.rounded()), WorkoutFormat.clock(pace - cost))
        }
        return text + String(format: effect.isCold ? C.coldCostFormat : C.heatCostFormat, percent(effect.paceFactor))
    }

    static func compass(_ degrees: Double) -> String {
        let index = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / C.compassSector).rounded()) % C.compass.count
        return C.compass[index]
    }

    static func percent(_ factor: Double) -> String {
        (factor * C.percentScale).formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "pt_BR"))) + "%"
    }
}
