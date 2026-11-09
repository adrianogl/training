import Foundation
import Storage
import SwiftData
import TrainingCore

let fixtureToday = Day(iso: "2026-11-12")!

func noon(_ day: Day) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12))!
}

func daysAgo(_ offset: Int) -> Day {
    fixtureToday.adding(days: -offset)
}

func makeContext(_ models: [any PersistentModel] = []) throws -> ModelContext {
    let container = try TrainingSchema.container(inMemory: true)
    let context = ModelContext(container)
    models.forEach { context.insert($0) }
    try context.save()
    return context
}

func run(
    id: Int64,
    daysAgo offset: Int,
    distance: Double = 10_000,
    split5k: Double? = nil,
    vo2max: Double? = nil,
    load: Double? = 80,
    typeKey: String = "running"
) -> ActivityRecord {
    let day = daysAgo(offset)
    return ActivityRecord(
        activityId: id,
        typeKey: typeKey,
        start: noon(day),
        distance: distance,
        duration: 3_600,
        activityTrainingLoad: load,
        fastestSplit_5000: split5k,
        vo2max: vo2max,
        localDay: day.iso
    )
}

func everyOtherDay(over days: Int, startingId: Int64 = 1, make: (Int64, Int) -> ActivityRecord) -> [ActivityRecord] {
    stride(from: days, through: 0, by: -2).enumerated().map { index, offset in
        make(startingId + Int64(index), offset)
    }
}

func improvingRuns(over days: Int = 120, todaySplit: Double = 1_500, slopePerDay: Double = 2) -> [ActivityRecord] {
    everyOtherDay(over: days) { id, offset in
        run(id: id, daysAgo: offset, split5k: todaySplit + slopePerDay * Double(offset))
    }
}

func daily(
    daysAgo offset: Int,
    hrv: Double? = nil,
    balanced: ClosedRange<Double>? = nil,
    sleepScore: Int? = nil,
    bodyBattery: Int? = nil,
    stress: Int? = nil,
    restingHR: Int? = nil
) -> DailyRecord {
    DailyRecord(
        day: daysAgo(offset).iso,
        restingHR: restingHR,
        stressAvg: stress,
        bodyBatteryMorningMax: bodyBattery,
        hrvLastNight: hrv,
        hrvLowUpper: balanced.map { $0.lowerBound - 10 },
        hrvBalancedLow: balanced?.lowerBound,
        hrvBalancedUpper: balanced?.upperBound,
        sleepScore: sleepScore
    )
}

func race(name: String, inDays offset: Int, distance: Double = 5_000, goal: Double? = nil, priority: RacePriority = .a) -> RaceRecord {
    RaceRecord(name: name, day: fixtureToday.adding(days: offset).iso, distance: distance, goalSeconds: goal, priority: priority)
}
