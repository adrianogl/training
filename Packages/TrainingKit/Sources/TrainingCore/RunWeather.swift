import Foundation

public enum WeatherAdjustment {
    private typealias C = RunWeatherConstants

    public static func effect(_ weather: RunWeather?, hotSessions: Int = 0) -> WeatherEffect? {
        guard let weather else { return nil }
        if weather.temperature <= C.coldStart {
            let factor = interpolate(weather.temperature, bands: C.coldBands.map { (-$0.temperature, $0.factor) }, negated: true)
            return WeatherEffect(weather: weather, stress: factor > 0 ? .cold : .mild, paceFactor: factor)
        }
        guard let dewPoint = weather.dewPoint else { return WeatherEffect(weather: weather, stress: .mild, paceFactor: 0) }
        let boost = sunBoost(weather.radiation)
        let raw = heatFactor(temperature: weather.temperature + boost, dewPoint: dewPoint)
        let adaptation = raw > 0 ? adaptation(hotSessions: hotSessions) : 0
        let factor = raw * (1 - adaptation)
        return WeatherEffect(
            weather: weather, stress: factor > 0 ? .heat : .mild, paceFactor: factor,
            sunBoost: boost, hotSessions: raw > 0 ? hotSessions : 0, adaptation: adaptation
        )
    }

    public static func isHotSession(_ weather: RunWeather?) -> Bool {
        (effect(weather)?.paceFactor ?? 0) >= C.hotSessionFactor && effect(weather)?.stress == .heat
    }

    public static func sunBoost(_ radiation: Double?) -> Double {
        guard let radiation, radiation > 0 else { return 0 }
        return min(radiation / C.fullSunRadiation, 1) * C.fullSunBoost
    }

    public static func adaptation(hotSessions: Int) -> Double {
        min(Double(max(hotSessions, 0)) * C.adaptationPerSession, C.maxAdaptation)
    }

    public static func windCost(headwind: Double) -> Double {
        headwind >= 0 ? C.headwindCost * headwind * headwind : -C.headwindCost * C.tailwindShare * headwind * headwind
    }

    public static func headwind(windSpeed: Double, windFrom: Double, heading: Double) -> Double {
        windSpeed * C.windHeightFactor * cos((windFrom - heading) * .pi / 180)
    }

    public static func heatFactor(temperature: Double, dewPoint: Double) -> Double {
        interpolate(fahrenheit(temperature) + fahrenheit(dewPoint), bands: C.heatBands.map { ($0.sumFahrenheit, $0.factor) }, negated: false)
    }

    public static func mildPace(_ pace: Double, effect: WeatherEffect?) -> Double {
        pace / (1 + (effect?.paceFactor ?? 0))
    }

    public static func mildSpeed(_ speed: Double, factor: Double?) -> Double {
        speed * (1 + (factor ?? 0))
    }

    public static func weatherSeconds(_ seconds: Double, effect: WeatherEffect?) -> Double {
        seconds * (1 + (effect?.paceFactor ?? 0))
    }

    public static func fahrenheit(_ celsius: Double) -> Double {
        celsius * 9 / 5 + 32
    }

    private static func interpolate(_ value: Double, bands: [(Double, Double)], negated: Bool) -> Double {
        let input = negated ? -value : value
        guard let first = bands.first, input > first.0 else { return 0 }
        for index in bands.indices.dropFirst() {
            let (upper, top) = bands[index]
            let (lower, base) = bands[index - 1]
            if input <= upper { return base + (top - base) * (input - lower) / (upper - lower) }
        }
        return bands.last?.1 ?? 0
    }
}
