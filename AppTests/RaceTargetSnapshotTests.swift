import FITReader
import Foundation
import SwiftUI
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import trAIning

@MainActor
@Suite struct RaceTargetSnapshotTests {
    private static let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }

    @Test func targetWithWeatherRenders() throws {
        let effect = try #require(WeatherAdjustment.effect(RunWeather(temperature: 21, dewPoint: 20)))
        let weather = RaceWeatherReading(effect: effect, source: .forecast, startHour: 6, endHour: 7, predictionSeconds: 2_396)
        let target = RaceTargetData(
            id: UUID(), name: "Live! Run XP", dateText: "22/11", distanceText: "10 km", days: 1,
            predictionSeconds: 2_396, goalSeconds: 2_400, gapText: "−0:04 da meta"
        )
        guard let output = Self.output else { return }
        let content = RaceTargetCard(target: target, weather: weather) { CardLinkFooter(title: CardLinkConstants.race) }
            .padding(16)
            .frame(width: 440)
            .background(BrandColors.background)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        try image.pngData()?.write(to: output.appending(path: "race-target-weather.png"))
    }
}
