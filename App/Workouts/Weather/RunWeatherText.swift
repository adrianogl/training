import SwiftUI
import TrainingCore

enum RunWeatherText {
    private typealias C = RunWeatherBandConstants

    static func title(_ effect: WeatherEffect) -> String {
        if effect.isCold { return C.coldTitle }
        guard let dewPoint = effect.weather.dewPoint else { return C.mildTitle }
        let dew = String(format: C.dewPointFormat, Int(dewPoint.rounded()))
        return [dew, dewPoint >= C.muggyDewPoint ? C.muggy : nil, effect.isSunny ? C.sunny : nil].compactMap { $0 }.joined(separator: C.separator)
    }

    static func degrees(_ effect: WeatherEffect) -> String {
        String(format: C.degreeFormat, Int(effect.weather.temperature.rounded()))
    }

    static func caption(_ effect: WeatherEffect) -> String {
        guard effect.paceFactor > 0 else { return C.captionLabel }
        return String(format: C.captionFormat, percent(effect.paceFactor))
    }

    static func summary(_ effect: WeatherEffect) -> String {
        var parts = [title(effect)]
        if effect.adaptation > 0 {
            parts.append(String(format: C.summaryAdaptedFormat, effect.hotSessions, Int((effect.adaptation * C.percentScale).rounded())))
        }
        if let speed = effect.weather.windSpeed, let from = effect.weather.windFrom, speed > 0 {
            parts.append(String(format: C.summaryWindFormat, Int((speed * C.kmhPerMs).rounded()), compass(from)))
        }
        return parts.joined(separator: C.separator)
    }

    static func compass(_ degrees: Double) -> String {
        let index = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / C.compassSector).rounded()) % C.compass.count
        return C.compass[index]
    }

    static func percent(_ factor: Double) -> String {
        (factor * C.percentScale).formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "pt_BR"))) + "%"
    }
}
