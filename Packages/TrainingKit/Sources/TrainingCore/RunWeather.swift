public enum WeatherAdjustment {
    private typealias C = RunWeatherConstants

    public static func effect(_ weather: RunWeather?) -> WeatherEffect? {
        guard let weather else { return nil }
        if weather.temperature <= C.coldStart {
            let factor = interpolate(weather.temperature, bands: C.coldBands.map { (-$0.temperature, $0.factor) }, negated: true)
            return WeatherEffect(weather: weather, stress: factor > 0 ? .cold : .mild, paceFactor: factor)
        }
        guard let dewPoint = weather.dewPoint else { return WeatherEffect(weather: weather, stress: .mild, paceFactor: 0) }
        let factor = heatFactor(temperature: weather.temperature, dewPoint: dewPoint)
        return WeatherEffect(weather: weather, stress: factor > 0 ? .heat : .mild, paceFactor: factor)
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
