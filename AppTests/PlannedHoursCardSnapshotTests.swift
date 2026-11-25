import Foundation
import GarminAPI
import SwiftUI
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct PlannedHoursCardSnapshotTests {
    @Test func cardShowsHeatPerHourAndPaces() throws {
        let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        let temperatures: [Int: Double] = [12: 29, 13: 25, 14: 27, 15: 25, 16: 23, 17: 23, 18: 23, 19: 23, 20: 23, 21: 22]
        let weather = temperatures.keys.sorted().map { HourlyWeather(hour: $0, temperature: temperatures[$0]!, dewPoint: $0 == 12 ? 20 : 19) }
        let plan = PlannedWorkout(id: 9, day: "2026-11-25", title: "Rodagem 10 km", estimatedSeconds: 2_900, estimatedMeters: 10_000, steps: [
            PlannedStep(kind: .active, meters: 10_000, target: .pace(fastest: 280, slowest: 290)),
        ])
        var input = BriefingInput(
            plan: plan, today: Day(iso: "2026-11-25")!, similar: [], readiness: 70, weekDoneKm: 0, weekPlannedKm: 0,
            weekGoalKm: nil, daysSinceHard: nil, race: nil, weather: weather, course: nil, completed: nil
        )
        input.startHour = 12
        let briefing = PlannedBriefingBuilder.briefing(input)
        #expect(!briefing.hourPaces.isEmpty)
        for scheme in [ColorScheme.light, .dark] {
            let view = PlannedHoursCard(briefing: briefing).padding(16).frame(width: 402).background(BrandColors.background).environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3
            let image = try #require(renderer.uiImage)
            if let output, let data = image.pngData() {
                try data.write(to: output.appending(path: "melhor-horario-\(scheme == .dark ? "escuro" : "claro").png"))
            }
        }
    }
}
