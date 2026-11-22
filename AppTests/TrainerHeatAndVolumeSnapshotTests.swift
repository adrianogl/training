import Foundation
import Insights
import SwiftUI
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct TrainerHeatAndVolumeSnapshotTests {
    private static let hotSaturday = [(5, 21.0, 19.0), (6, 22, 19), (7, 24, 20), (8, 26, 20), (9, 28, 21), (10, 29, 21), (11, 30, 21), (12, 31, 21),
                                      (13, 32, 21), (14, 32, 21), (15, 31, 21), (16, 30, 21), (17, 29, 21), (18, 27, 21), (19, 26, 20), (20, 25, 20), (21, 24, 20)]
        .map { HourlyWeather(hour: $0.0, temperature: $0.1, dewPoint: $0.2) }

    @Test func heatCardAtTheUsualHourAndAtACoolerOne() throws {
        let day = try #require(TrainerHeatDayBuilder.make(weather: Self.hotSaturday, longPace: 310, usualHour: 8, hotSessions: 6))
        try TrainerDaysVolumeSnapshotTests.save(TrainerHeatCard(day: day, selected: .constant(nil), hasBlocks: false), name: "trainer-heat-usual")
        try TrainerDaysVolumeSnapshotTests.save(TrainerHeatCard(day: day, selected: .constant(6), hasBlocks: false), name: "trainer-heat-selected")
    }

    @Test func volumeSuggestionBox() throws {
        let light = Day(year: 2026, month: 11, day: 16)
        let base = TrainerNormalVolume(meters: 55_000, excluded: [TrainerExcludedWeek(start: light, reason: .light)], fromNormalWeeks: true)
        let suggestion = TrainerVolumeSuggestion(startMeters: 55_000, peakMeters: 68_000, limit: .growth, base: base)
        let card = VStack(alignment: .leading, spacing: 8) {
            TrainerVolumeSuggestionBox(suggestion: suggestion, inUse: false) {}
            DSCardLabel(TrainerText.startTitle)
            Stepper(TrainerText.weeklyValue(60), value: .constant(60), in: 0...200)
            Text(TrainerText.normalAverage(base)).font(.footnote).foregroundStyle(BrandColors.dim)
        }
        .brandCard()
        try TrainerDaysVolumeSnapshotTests.save(card, name: "trainer-volume-suggestion")
    }
}
