import Foundation
import Storage
import Testing
@testable import trAIning

@Suite struct LastRunBuilderTests {
    private static let now = Date(timeIntervalSince1970: 1_793_000_000)

    private static func run(_ id: Int64, daysAgo: Double, name: String, km: Double, heartRate: Double = 150) -> ActivityRecord {
        ActivityRecord(
            activityId: id, typeKey: "running", name: name, start: now.addingTimeInterval(-daysAgo * 86_400),
            distance: km * 1_000, duration: km * 280, averageHR: heartRate, workoutName: name
        )
    }

    @Test func findsSameKindWithoutRequiringSimilarDistance() {
        let current = Self.run(1, daysAgo: 0, name: "Corrida Longo sáb 14/11", km: 12.7, heartRate: 165)
        let history = [
            current,
            Self.run(2, daysAgo: 6, name: "Corrida Longo dom 8/11", km: 16.4, heartRate: 155),
            Self.run(3, daysAgo: 20, name: "Corrida Longo dom 25/10", km: 22, heartRate: 155),
            Self.run(4, daysAgo: 27, name: "Corrida Longo dom 18/10", km: 18.6, heartRate: 152),
            Self.run(5, daysAgo: 34, name: "Corrida Longo dom 11/10", km: 20, heartRate: 150),
            Self.run(6, daysAgo: 3, name: "Rodagem leve", km: 10),
            Self.run(7, daysAgo: 90, name: "Corrida Longo antigo", km: 20),
        ]

        let similar = LastRunBuilder.similar(to: current, among: history)

        #expect(similar.map(\.activityId) == [2, 3, 4])
    }

    @Test func similarIgnoresRunsAfterTheCurrentOne() {
        let current = Self.run(1, daysAgo: 5, name: "Corrida Longo", km: 12)
        let history = [current, Self.run(2, daysAgo: 0, name: "Corrida Longo", km: 16)]

        #expect(LastRunBuilder.similar(to: current, among: history).isEmpty)
    }

    @Test func heartRateIsHighWhenEightBeatsAboveSimilarAverage() {
        #expect(LastRunBuilder.isHeartRateHigh(current: 165, similar: [155, 155, 152]))
        #expect(!LastRunBuilder.isHeartRateHigh(current: 158, similar: [155, 155, 152]))
        #expect(!LastRunBuilder.isHeartRateHigh(current: 165, similar: []))
    }

    @Test func readingComparesWithMostRecentAndMentionsLowReadiness() {
        let reference = LastRunReference(dateText: "8/11", paceSeconds: 275, averageHeartRate: 155)

        let text = LastRunBuilder.reading(kind: .long, paceSeconds: 275, averageHeartRate: 165, fadeKm: 11, readiness: 42, reference: reference)

        #expect(text == "Mesmo pace do longão de 8/11, com a FC 10 bpm mais alta e queda a partir do km 11. A prontidão do dia era 42.")
        #expect(LastRunBuilder.reading(kind: .long, paceSeconds: 275, averageHeartRate: 165, fadeKm: nil, readiness: 80, reference: nil) == nil)
        #expect(LastRunBuilder.reading(kind: .easy, paceSeconds: 270, averageHeartRate: 150, fadeKm: nil, readiness: 70, reference: reference)?.hasPrefix("Pace 5 s/km") == false)
    }

    @Test func chartNormalizesPaceInvertedAndHeartRate() {
        let splits = [
            LastRunSplit(km: 1, paceSeconds: 270, heartRate: 140),
            LastRunSplit(km: 2, paceSeconds: 300, heartRate: 160),
        ]

        let data = LastRunBuilder.chart(splits)

        #expect(data.pace.map(\.value) == [1, 0])
        #expect(data.heartRate.map(\.value) == [0, 1])
    }
}
