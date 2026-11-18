import FITReader
import Foundation
import SwiftUI
import Testing
import TrainingCore
@testable import trAIning

@Suite struct RunWeatherTests {
    private let body = Data("""
    {"hourly":{"time":["2026-11-17T09:00","2026-11-17T10:00","2026-11-17T11:00"],
    "temperature_2m":[24.0,28.0,30.0],"dew_point_2m":[19.0,21.0,null]}}
    """.utf8)

    @Test func averagesTheHoursTheRunCovers() throws {
        let hours = try #require(ActivityWeather.parse(body))
        #expect(hours.count == 3)
        let start = hours[0].start.addingTimeInterval(30 * 60)
        let weather = try #require(ActivityWeather.average(hours, start: start, end: start.addingTimeInterval(3600)))
        #expect(abs(weather.temperature - 26) < 0.001)
        #expect(abs((weather.dewPoint ?? 0) - 20) < 0.001)
        #expect(ActivityWeather.average(hours, start: start.addingTimeInterval(-86_400), end: start.addingTimeInterval(-82_800)) == nil)
    }

    @Test func oldRunsUseTheArchive() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let coordinate = Coordinate(lat: -23.5612, lon: -46.6559)
        let recent = ActivityWeather.request(coordinate: coordinate, start: now.addingTimeInterval(-10 * 86_400), end: now.addingTimeInterval(-10 * 86_400 + 3600), now: now)
        let old = ActivityWeather.request(coordinate: coordinate, start: now.addingTimeInterval(-100 * 86_400), end: now.addingTimeInterval(-100 * 86_400 + 3600), now: now)
        #expect(!recent.archive)
        #expect(old.archive)
        #expect(recent.latitude == "-23.6")
        #expect(ActivityWeather.url(old)?.host() == "archive-api.open-meteo.com")
    }

    @Test func raceStartTimeParses() {
        #expect(RaceWeatherLookup.minutes("07:00") == 420)
        #expect(RaceWeatherLookup.minutes("6:30") == 390)
        #expect(RaceWeatherLookup.minutes(nil) == nil)
        #expect(RaceWeatherLookup.minutes("25:00") == nil)
    }

    @Test func raceWeatherTexts() throws {
        let effect = try #require(WeatherAdjustment.effect(RunWeather(temperature: 27, dewPoint: 20)))
        let reading = RaceWeatherReading(effect: effect, source: .forecast, startHour: 7, endHour: 9, predictionSeconds: 6130)
        #expect(RaceWeatherText.lead(reading) == "No clima previsto: 1:46:33")
        #expect(RaceWeatherText.detail(reading) == "Orvalho 20 °C · 7h–9h · ritmo +4,3% · previsão do tempo")
        #expect(RaceWeatherText.goal(reading, goalSeconds: 6300) == "Meta 1:45:00: 1:33 acima no clima previsto.")
        #expect(RaceWeatherText.list(reading) == "27 °C · 1:46:33")
    }

    @Test func runWeatherTexts() throws {
        let humid = try #require(WeatherAdjustment.effect(RunWeather(temperature: 28, dewPoint: 21)))
        #expect(RunWeatherText.title(humid) == "Orvalho 21 °C · abafado")
        #expect(RunWeatherText.detail(humid) == "Calor deixa o ritmo 4,8% mais lento")
        let mild = try #require(WeatherAdjustment.effect(RunWeather(temperature: 12, dewPoint: 5)))
        #expect(RunWeatherText.title(mild) == "Orvalho 5 °C")
        #expect(RunWeatherText.detail(mild) == nil)
        let cold = try #require(WeatherAdjustment.effect(RunWeather(temperature: -2, dewPoint: -6)))
        #expect(RunWeatherText.title(cold) == "Frio")
        #expect(RunWeatherText.detail(cold) == "Frio deixa o ritmo 0,7% mais lento")
    }

    @MainActor
    @Test func weatherBandsRender() throws {
        let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        let humid = try #require(WeatherAdjustment.effect(RunWeather(temperature: 28, dewPoint: 21)))
        let race = try #require(WeatherAdjustment.effect(RunWeather(temperature: 27, dewPoint: 20)))
        let reading = RaceWeatherReading(effect: race, source: .forecast, startHour: 7, endHour: 9, predictionSeconds: 6130)
        let content = VStack(alignment: .leading, spacing: 14) {
            RunWeatherBand(effect: humid)
            RaceWeatherLine(reading: reading, goalSeconds: 6300)
        }
        for scheme in [ColorScheme.light, .dark] {
            let renderer = ImageRenderer(content: content.padding(16).frame(width: 390).background(BrandColors.background).environment(\.colorScheme, scheme))
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            if let output, FileManager.default.fileExists(atPath: output.path()), let data = image.pngData() {
                try data.write(to: output.appending(path: "weather-bands-\(scheme).png"))
            }
        }
    }
}
