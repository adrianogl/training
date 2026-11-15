import FITReader
import Foundation
import Storage
import SwiftData
import Sync
import Testing
import TrainingCore
@testable import Insights

private func thresholdSession(id: Int64, daysAgo offset: Int, pace: Double, km: Double = 6) -> ActivityRecord {
    let step = PrescribedStep(index: 0, intensity: .active, duration: .distance(meters: km * 1_000), target: .heartRateZone(4))
    let lap = LapSummary(stepIndex: 0, intensity: .active, startOffset: 0, timerSeconds: pace * km, distance: km * 1_000)
    let structure = WorkoutStructure(prescription: WorkoutPrescription(name: "Limiar", steps: [step]), laps: [lap])
    let day = daysAgo(offset)
    return ActivityRecord(
        activityId: id, typeKey: "running", name: "Limiar", start: noon(day), distance: (km + 3) * 1_000, duration: (km + 3) * pace,
        localDay: day.iso, workoutName: "Limiar", structureData: try! JSONEncoder().encode(structure)
    )
}

private func steadyRun(id: Int64, daysAgo offset: Int, name: String, pace: Double, heartRate: Int) -> ActivityRecord {
    let samples = (0..<400).map { FITSample(t: Double($0) * 5, heartRate: heartRate, speed: 1_000 / pace) }
    let day = daysAgo(offset)
    return ActivityRecord(
        activityId: id, typeKey: "running", name: name, start: noon(day), distance: 12_000, duration: 12 * pace,
        samplesData: try! JSONEncoder().encode(samples), localDay: day.iso, workoutName: name
    )
}

private func lthr() -> ThresholdHistoryRecord {
    ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: daysAgo(200).iso, heartRate: 165)
}

@Suite struct ThresholdPaceSeriesTests {
    @Test func thresholdPaceIsTheMedianOfTheWorkBlocksAndIgnoresHighHeartRateLongRuns() throws {
        let context = try makeContext([
            lthr(),
            thresholdSession(id: 1, daysAgo: 24, pace: 246),
            thresholdSession(id: 2, daysAgo: 17, pace: 244),
            thresholdSession(id: 3, daysAgo: 10, pace: 248),
            thresholdSession(id: 4, daysAgo: 3, pace: 246),
            steadyRun(id: 5, daysAgo: 1, name: "Longão", pace: 276, heartRate: 165),
        ])

        let series = try metricSeries(.thresholdPace, context: context, today: fixtureToday, period: .sixMonths)

        #expect(series.stats.current == 246)
        #expect(series.points.map(\.1) == [246, 245, 246, 246])
    }

    @Test func thresholdPaceFallsBackToHeartRateWithoutSessions() throws {
        let context = try makeContext([lthr(), steadyRun(id: 1, daysAgo: 2, name: "Longão", pace: 276, heartRate: 165)])

        let series = try metricSeries(.thresholdPace, context: context, today: fixtureToday, period: .sixMonths)

        let current = try #require(series.stats.current)
        #expect(abs(current - 276) < 0.001)
    }
}
