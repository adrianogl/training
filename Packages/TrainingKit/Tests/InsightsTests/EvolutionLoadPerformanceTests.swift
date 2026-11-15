import FITReader
import Foundation
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Insights

import Reports
import Sync

@Suite(.serialized) struct EvolutionLoadPerformanceTests {
    private struct Load {
        let overall: OverallState
        let series: [MetricKind: MetricSeries]
    }

    private func load(_ context: ModelContext, memo: ReportMemo?) throws -> Load {
        let overall = try memo.map { try overallState(context: context, today: fixtureToday, memo: $0) }
            ?? overallState(context: context, today: fixtureToday)
        var series: [MetricKind: MetricSeries] = [:]
        for kind in MetricKind.allCases {
            series[kind] = try memo.map { try metricSeries(kind, context: context, today: fixtureToday, period: .sixMonths, memo: $0) }
                ?? metricSeries(kind, context: context, today: fixtureToday, period: .sixMonths)
        }
        return Load(overall: overall, series: series)
    }

    private func makeLoadContext() throws -> ModelContext {
        try makeContext(syntheticActivities(count: 300) + [race(name: "Prova", inDays: 40, distance: 10_000, goal: 2_900)])
    }

    @Test func sharedMemoComputesEffortsOncePerActivitySet() throws {
        let context = try makeLoadContext()
        let memo = ReportMemo()

        _ = try load(context, memo: memo)

        #expect(memo.effortComputations == 1)
        #expect(memo.sessionComputations == 1)
    }

    @Test func sharedMemoKeepsResults() throws {
        let context = try makeLoadContext()

        let plain = try load(context, memo: nil)
        let shared = try load(context, memo: ReportMemo())

        #expect(plain.overall.indicators.map(\.today) == shared.overall.indicators.map(\.today))
        #expect(plain.overall.indicators.map(\.delta) == shared.overall.indicators.map(\.delta))
        #expect(plain.overall.facts == shared.overall.facts)
        for kind in MetricKind.allCases {
            let a = try #require(plain.series[kind])
            let b = try #require(shared.series[kind])
            #expect(a.points.map(\.0) == b.points.map(\.0), "\(kind)")
            #expect(a.points.map(\.1) == b.points.map(\.1), "\(kind)")
            #expect(a.stats == b.stats, "\(kind)")
            #expect(a.projection.map(\.mid) == b.projection.map(\.mid), "\(kind)")
        }
    }

    @Test func reportsLoadTimes() throws {
        let context = try makeLoadContext()
        let clock = ContinuousClock()
        _ = try load(context, memo: nil)
        let without = try clock.measure { _ = try load(context, memo: nil) }
        let with = try clock.measure { _ = try load(context, memo: ReportMemo()) }
        print("PERF sem memo \(without) | com memo \(with)")
    }
}

func syntheticActivities(count: Int) -> [ActivityRecord] {
    let samples = try! JSONEncoder().encode((0..<400).map { FITSample(t: Double($0) * 5, heartRate: 150, speed: 3.4) })
    return (0..<count).map { index in
        let offset = index * 2 / 3
        let isThreshold = index % 6 == 0
        let steps = (0..<8).map { PrescribedStep(index: $0, intensity: .active, duration: .distance(meters: 1_000), target: .heartRateZone(isThreshold ? 4 : 2)) }
        let laps = (0..<8).map { LapSummary(stepIndex: $0, intensity: .active, startOffset: Double($0) * 300, timerSeconds: 290, distance: 1_000) }
        let structure = WorkoutStructure(prescription: WorkoutPrescription(name: isThreshold ? "Limiar" : "Rodagem", steps: steps), laps: laps)
        let day = daysAgo(offset)
        let distance: Double = 6_000 + Double(index % 7) * 1_500
        let load: Double = 60 + Double(index % 11) * 8
        let split: Double = 1_500 + Double(offset) * 0.8 + Double(index % 5) * 6
        let vo2: Double = 48 + Double(index % 9) * 0.3
        let name = isThreshold ? "Limiar" : "Rodagem"
        let structureData = try! JSONEncoder().encode(structure)
        return ActivityRecord(
            activityId: Int64(index + 1), typeKey: "running", name: name, start: noon(day),
            distance: distance, duration: distance * 0.3, activityTrainingLoad: load,
            fastestSplit_5000: split, vo2max: vo2,
            samplesData: samples, localDay: day.iso, workoutName: name, structureData: structureData
        )
    }
}
