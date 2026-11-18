public struct RunWeather: Sendable, Equatable, Codable {
    public var temperature: Double
    public var dewPoint: Double?
    public var windSpeed: Double?
    public var windFrom: Double?
    public var radiation: Double?

    public init(temperature: Double, dewPoint: Double?, windSpeed: Double? = nil, windFrom: Double? = nil, radiation: Double? = nil) {
        self.temperature = temperature
        self.dewPoint = dewPoint
        self.windSpeed = windSpeed
        self.windFrom = windFrom
        self.radiation = radiation
    }
}

public enum WeatherStress: String, Sendable, Codable {
    case mild, heat, cold
}

public struct WeatherEffect: Sendable, Equatable, Codable {
    public var weather: RunWeather
    public var stress: WeatherStress
    public var paceFactor: Double
    public var sunBoost: Double
    public var hotSessions: Int
    public var adaptation: Double

    public init(weather: RunWeather, stress: WeatherStress, paceFactor: Double, sunBoost: Double = 0, hotSessions: Int = 0, adaptation: Double = 0) {
        self.weather = weather
        self.stress = stress
        self.paceFactor = paceFactor
        self.sunBoost = sunBoost
        self.hotSessions = hotSessions
        self.adaptation = adaptation
    }

    public var isSunny: Bool { sunBoost >= RunWeatherConstants.sunnyBoost }

    public var isHeat: Bool { stress == .heat && paceFactor > 0 }
    public var isCold: Bool { stress == .cold && paceFactor > 0 }
}
