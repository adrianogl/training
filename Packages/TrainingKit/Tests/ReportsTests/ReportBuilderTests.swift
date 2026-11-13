import FITReader
import Foundation
import Metrics
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import Reports

private let today = Day(iso: "2026-11-08")!

private func noon(_ day: Day) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12))!
}

private func run(id: Int64, daysAgo: Int, split5k: Double, split1k: Double, typeKey: String = "running") -> ActivityRecord {
    ActivityRecord(
        activityId: id,
        typeKey: typeKey,
        start: noon(today.adding(days: -daysAgo)),
        distance: 10_000,
        duration: 3_600,
        activityTrainingLoad: 80,
        fastestSplit_1000: split1k,
        fastestSplit_5000: split5k
    )
}

private func build(_ records: [ActivityRecord]) throws -> TrainingReport {
    let container = try TrainingSchema.container(inMemory: true)
    let context = ModelContext(container)
    records.forEach(context.insert)
    try context.save()
    return try ReportBuilder(context: context, today: today).build()
}

@Suite struct ReportBuilderTests {
    @Test func emptyStoreGivesNoMetrics() throws {
        let report = try build([])

        #expect(report.days == 0 && report.activities == 0)
        #expect(report.readinessScore == nil && !report.readinessPartial)
        #expect(report.vo2max == nil)
        #expect(report.fitness == nil && report.fatigue == nil && report.form == nil)
        #expect(report.acuteChronic == nil)
        #expect(report.predictions.count == 4 && report.predictions.allSatisfy { $0.seconds == nil })
        #expect(report.durability == nil && report.hillStrength == nil)
    }

    @Test func predictionUsesBestEffortAmongRuns() throws {
        var records = (1...20).map { run(id: Int64($0), daysAgo: $0, split5k: 1_680, split1k: 315) }
        records.append(run(id: 100, daysAgo: 6, split5k: 1_320, split1k: 250))

        let report = try build(records)

        let w5k = 0.7 * (1 - 6.0 / 90)
        let w1k = 0.3 * (1 - 6.0 / 90)
        let expected = (w5k * 1_320 + w1k * riegel(seconds: 250, from: 1_000, to: 5_000)) / (w5k + w1k)
        let fiveK = try #require(report.predictions.first?.seconds)
        #expect(report.predictions.first?.label == "5 km")
        #expect(abs(fiveK - expected) < 1)
    }

    @Test func predictionCarriesYearAgoFromOlderEfforts() throws {
        let records = [
            run(id: 1, daysAgo: 370, split5k: 1_500, split1k: 290),
            run(id: 2, daysAgo: 5, split5k: 1_300, split1k: 250),
        ]
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        records.forEach(context.insert)
        try context.save()
        let builder = ReportBuilder(context: context, today: today)

        let fiveK = try #require(builder.predictions(builder.efforts(from: records)).first)

        let now = try #require(fiveK.seconds)
        let yearAgo = try #require(fiveK.yearAgoSeconds)
        #expect(now < yearAgo)
        #expect(abs(now - 1_300) < 60)
        #expect(abs(yearAgo - 1_500) < 60)
    }

    @Test func raceEffortUsesActivityDistance() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(ActivityRecord(activityId: 7, typeKey: "running", start: noon(today.adding(days: -10)), distance: 9_700, duration: 2_700))
        context.insert(RaceRecord(name: "Prova", day: today.adding(days: -10).iso, distance: 10_000, resultActivityId: 7))
        try context.save()

        let efforts = try ReportBuilder(context: context, today: today).efforts()

        let race = try #require(efforts.first { $0.kind == .race })
        #expect(race.distance == 9_700)
        #expect(race.seconds == 2_700)
    }

    @Test func tombstonedRaceIsNotAnEffort() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(ActivityRecord(activityId: 7, typeKey: "running", start: noon(today.adding(days: -10)), distance: 9_700, duration: 2_700))
        context.insert(RaceRecord(name: "Prova", day: today.adding(days: -10).iso, distance: 10_000, resultActivityId: 7, deletedAt: .now))
        try context.save()

        let efforts = try ReportBuilder(context: context, today: today).efforts()

        #expect(!efforts.contains { $0.kind == .race })
    }

    @Test func countsEveryRunTypeKey() throws {
        let report = try build([run(id: 1, daysAgo: 3, split5k: 1_400, split1k: 270, typeKey: "virtual_run")])

        #expect(report.predictions.first?.seconds != nil)
    }

    @Test func activityWithoutStartDoesNotMoveLoadSeries() throws {
        let dated = run(id: 1, daysAgo: 10, split5k: 1_400, split1k: 270)
        let undated = ActivityRecord(activityId: 2, typeKey: "cycling", activityTrainingLoad: 500)
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        [dated, undated].forEach(context.insert)
        try context.save()
        let builder = ReportBuilder(context: context, today: today)

        let load = builder.dailyLoad(try context.fetch(FetchDescriptor<ActivityRecord>()))
        let report = try builder.build()

        #expect(load == [today.adding(days: -10): 80])
        let expected = try #require(fitnessFatigueForm(dailyLoad: load, from: today.adding(days: -10), to: today).last)
        #expect(report.fitness == expected.fitness && report.fatigue == expected.fatigue)
    }

    @Test func durabilityIsMedianOfDatedEligibleRuns() throws {
        func samples(secondHalfHeartRate: Int) -> Data {
            let points = stride(from: 0.0, through: 4_000, by: 5).map { t in
                FITSample(t: t, heartRate: t < 2_300 ? 140 : secondHalfHeartRate, speed: 3)
            }
            return try! JSONEncoder().encode(points)
        }
        let heartRates = [150, 160, 141]
        let records = heartRates.enumerated().map { index, heartRate in
            let record = run(id: Int64(index + 1), daysAgo: index + 1, split5k: 1_400, split1k: 270)
            record.samplesData = samples(secondHalfHeartRate: heartRate)
            return record
        }
        let undated = ActivityRecord(activityId: 99, typeKey: "running", vo2max: 70, samplesData: samples(secondHalfHeartRate: 300))

        let report = try build(records + [undated])

        let values = heartRates.compactMap { heartRate in
            decoupling(try! JSONDecoder().decode([FITSample].self, from: samples(secondHalfHeartRate: heartRate)))
        }.sorted()
        let durability = try #require(report.durability)
        #expect(abs(durability.value - values[1]) < 1e-9)
        #expect(durability.day == today.adding(days: -1))
        #expect(report.vo2max == nil)
    }
}
