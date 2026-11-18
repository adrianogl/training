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

    static func detail(_ effect: WeatherEffect) -> String? {
        guard effect.paceFactor > 0 else { return nil }
        let base = String(format: effect.isCold ? C.coldFormat : C.heatFormat, percent(effect.paceFactor))
        guard effect.adaptation > 0 else { return base }
        return base + C.separator + String(format: C.adaptedFormat, effect.hotSessions)
    }

    static func rows(_ effect: WeatherEffect) -> [(label: String, value: String)] {
        var rows: [(label: String, value: String)] = []
        let pace = effect.paceFactor > 0
            ? String(format: effect.isCold ? C.coldValueFormat : C.heatValueFormat, percent(effect.paceFactor))
            : C.noEffect
        rows.append((C.paceLabel, pace))
        if effect.adaptation > 0 {
            rows.append((C.adaptationLabel, String(format: C.adaptationValueFormat, effect.hotSessions, Int((effect.adaptation * C.percentScale).rounded()))))
        }
        if let speed = effect.weather.windSpeed, let from = effect.weather.windFrom, speed > 0 {
            rows.append((C.windLabel, String(format: C.windValueFormat, Int((speed * C.kmhPerMs).rounded()), compass(from))))
        }
        return rows
    }

    static func compass(_ degrees: Double) -> String {
        let index = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / C.compassSector).rounded()) % C.compass.count
        return C.compass[index]
    }

    static func percent(_ factor: Double) -> String {
        (factor * C.percentScale).formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "pt_BR"))) + "%"
    }
}
