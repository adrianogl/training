import Testing
@testable import TrainingCore

@Test func mildDayHasNoEffect() {
    let effect = WeatherAdjustment.effect(RunWeather(temperature: 14, dewPoint: 6))
    #expect(effect?.stress == .mild)
    #expect(effect?.paceFactor == 0)
}

@Test func humidHeatSlowsPaceByTheTable() {
    let effect = WeatherAdjustment.effect(RunWeather(temperature: 28, dewPoint: 21))
    #expect(effect?.stress == .heat)
    #expect(abs((effect?.paceFactor ?? 0) - 0.0483) < 0.0005)
    #expect(abs(WeatherAdjustment.mildPace(336, effect: effect) - 320.5) < 0.2)
}

@Test func heatTableCapsAtTenPercent() {
    #expect(abs(WeatherAdjustment.heatFactor(temperature: 35, dewPoint: 30) - 0.1) < 0.0001)
    #expect(abs(WeatherAdjustment.heatFactor(temperature: 40, dewPoint: 32) - 0.1) < 0.0001)
}

@Test func coldSlowsPaceBelowFiveDegrees() {
    #expect(WeatherAdjustment.effect(RunWeather(temperature: 5, dewPoint: 0))?.stress == .mild)
    #expect(abs((WeatherAdjustment.effect(RunWeather(temperature: 0, dewPoint: -3))?.paceFactor ?? 0) - 0.005) < 0.0001)
    #expect(abs((WeatherAdjustment.effect(RunWeather(temperature: -5, dewPoint: nil))?.paceFactor ?? 0) - 0.01) < 0.0001)
    #expect(abs((WeatherAdjustment.effect(RunWeather(temperature: -20, dewPoint: nil))?.paceFactor ?? 0) - 0.02) < 0.0001)
    #expect(WeatherAdjustment.effect(RunWeather(temperature: -5, dewPoint: nil))?.stress == .cold)
}

@Test func heatNeedsDewPoint() {
    let effect = WeatherAdjustment.effect(RunWeather(temperature: 30, dewPoint: nil))
    #expect(effect?.paceFactor == 0)
    #expect(WeatherAdjustment.effect(nil) == nil)
}
