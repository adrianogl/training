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

    @Test func countsEveryRunTypeKey() throws {
        let report = try build([run(id: 1, daysAgo: 3, split5k: 1_400, split1k: 270, typeKey: "virtual_run")])

        #expect(report.predictions.first?.seconds != nil)
    }
}
