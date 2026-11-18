public struct RunWeather: Sendable, Equatable, Codable {
    public var temperature: Double
    public var dewPoint: Double?

    public init(temperature: Double, dewPoint: Double?) {
        self.temperature = temperature
        self.dewPoint = dewPoint
    }
}

public enum WeatherStress: String, Sendable, Codable {
    case mild, heat, cold
}

public struct WeatherEffect: Sendable, Equatable, Codable {
    public var weather: RunWeather
    public var stress: WeatherStress
    public var paceFactor: Double

    public init(weather: RunWeather, stress: WeatherStress, paceFactor: Double) {
        self.weather = weather
        self.stress = stress
        self.paceFactor = paceFactor
    }

    public var isHeat: Bool { stress == .heat && paceFactor > 0 }
    public var isCold: Bool { stress == .cold && paceFactor > 0 }
}
