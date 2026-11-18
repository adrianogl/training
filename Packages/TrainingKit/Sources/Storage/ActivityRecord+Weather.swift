import TrainingCore

extension ActivityRecord {
    public var runWeather: RunWeather? {
        weatherTemperature.map { RunWeather(temperature: $0, dewPoint: weatherDewPoint) }
    }

    public var weatherEffect: WeatherEffect? {
        WeatherAdjustment.effect(runWeather)
    }
}
