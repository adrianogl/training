import FITReader
import Foundation
import Metrics
import Storage
import SwiftData
import Sync
import Testing
import TrainingCore
@testable import Insights

private func watchZones(threshold: Int? = nil) -> HeartRateZonesRecord {
    HeartRateZonesRecord(
        sport: "running",
        zone1Floor: 100,
        zone2Floor: 120,
        zone3Floor: 140,
        zone4Floor: 160,
        zone5Floor: 175,
        lactateThresholdHeartRate: threshold
    )
}

private func thresholdRun(id: Int64, daysAgo offset: Int, seconds: [Double], threshold: Int = 160) -> ActivityRecord {
    let activity = run(id: id, daysAgo: offset)
    activity.thresholdZoneSeconds = seconds
    activity.thresholdUsed = threshold
    return activity
}

@Suite struct ThresholdZonesInsightsTests {
    @Test func zone2RangeComesFromThreshold() throws {
        let context = try makeContext([watchZones(threshold: 150), ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: daysAgo(30).iso, heartRate: 160)])

        let zones = try runningZones(on: fixtureToday, context)

        #expect(zones == thresholdZones(thresholdHeartRate: 160))
        #expect(zone2Range(zones) == 136...143)
    }

    @Test func zoneRangeFollowsTheThresholdOfEachDay() throws {
        let context = try makeContext([
            watchZones(),
            ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: daysAgo(100).iso, heartRate: 150),
            ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: daysAgo(10).iso, heartRate: 160),
        ])

        #expect(zone2Range(try runningZones(on: daysAgo(50), context)) == 128...134)
        #expect(zone2Range(try runningZones(on: fixtureToday, context)) == 136...143)
    }

    @Test func withoutThresholdFallsBackToWatchZones() throws {
        let context = try makeContext([watchZones()])

        let zones = try runningZones(on: fixtureToday, context)

        #expect(zones?.floors == [100, 120, 140, 160, 175])
        #expect(zone2Range(zones) == 120...139)
    }

    @Test func withoutAnyZonesReturnsNil() throws {
        let context = try makeContext()

        #expect(try runningZones(on: fixtureToday, context) == nil)
    }

    @Test func loadFocusUsesThresholdZoneSeconds() throws {
        let watchOnly = run(id: 1, daysAgo: 0)
        watchOnly.zoneSeconds = [0, 0, 0, 0, 3_600]
        watchOnly.thresholdZoneSeconds = [3_000, 600, 0, 0, 0]
        watchOnly.thresholdUsed = 160
        let context = try makeContext([watchZones(threshold: 160), watchOnly])

        let series = try metricSeries(.loadFocus, context: context, today: fixtureToday, period: .sixMonths)

        #expect(series.points.last?.1 == 100)
    }

    @Test func weeklyZoneMinutesSkipRunsWithoutThresholdSeconds() throws {
        let noHeartRate = run(id: 2, daysAgo: 1)
        noHeartRate.zoneSeconds = [3_600, 0, 0, 0, 0]
        noHeartRate.thresholdUsed = 160
        let context = try makeContext([
            watchZones(threshold: 160),
            thresholdRun(id: 1, daysAgo: 0, seconds: [0, 0, 0, 0, 3_600]),
            noHeartRate,
        ])

        let series = try metricSeries(.zoneDistribution, context: context, today: fixtureToday, period: .sixMonths)

        #expect(series.points.map(\.1) == [0])
    }

    @Test func zoneDistributionFallsBackToWatchSecondsWithoutThreshold() throws {
        let activity = run(id: 1, daysAgo: 0)
        activity.zoneSeconds = [3_600, 0, 0, 0, 0]
        let context = try makeContext([watchZones(), activity])

        let series = try metricSeries(.zoneDistribution, context: context, today: fixtureToday, period: .sixMonths)

        #expect(series.points.last?.1 == 100)
    }

    @Test func zone2PaceUsesZonesOfTheRunDay() throws {
        let samples = (0..<400).map { FITSample(t: Double($0) * 5, heartRate: 140, speed: 3, distance: Double($0) * 15) }
        let data = try JSONEncoder().encode(samples)
        let early = run(id: 1, daysAgo: 50)
        early.samplesData = data
        let recent = run(id: 2, daysAgo: 0)
        recent.samplesData = data
        let context = try makeContext([
            watchZones(),
            ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: daysAgo(100).iso, heartRate: 150),
            ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: daysAgo(10).iso, heartRate: 160),
            early,
            recent,
        ])

        let series = try metricSeries(.zone2Pace, context: context, today: fixtureToday, period: .sixMonths)

        #expect(series.points.contains { $0.0 == daysAgo(50) } == false)
        #expect(series.points.contains { $0.0 == fixtureToday })
    }

    @Test func overallZone2PaceUsesTodayThreshold() throws {
        let samples = (0..<400).map { FITSample(t: Double($0) * 5, heartRate: 140, speed: 3, distance: Double($0) * 15) }
        let data = try JSONEncoder().encode(samples)
        let recent = run(id: 1, daysAgo: 0)
        recent.samplesData = data
        let context = try makeContext([watchZones(), ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: daysAgo(10).iso, heartRate: 160), recent])

        let state = try overallState(context: context, today: fixtureToday)

        let indicator = try #require(state.indicators.first { $0.kind == .zone2Pace })
        #expect(indicator.today != nil)
    }
}
