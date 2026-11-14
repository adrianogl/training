import FITReader
import Foundation
import Narrative
import Storage
@testable import Insights

struct SimilarSpec {
    let offset: Int
    let kilometers: Double
    let start: Double
    let fade: Int?
    let readiness: Int
}

struct DetailedScenario {
    var record: ActivityRecord
    var history: [ActivityRecord]
    var daily: [DailyRecord]

    func analysis(goals: [DetailedGoalNote] = []) -> DetailedAnalysis? {
        detailedAnalysis(record: record, history: history, daily: daily, goals: goals, longGoalKm: nil, raceGoalKms: [])
    }
}

let similarSpecs = [
    SimilarSpec(offset: 84, kilometers: 20, start: 270, fade: nil, readiness: 82),
    SimilarSpec(offset: 74, kilometers: 15, start: 273, fade: 9, readiness: 55),
    SimilarSpec(offset: 64, kilometers: 20, start: 280, fade: nil, readiness: 75),
    SimilarSpec(offset: 54, kilometers: 20, start: 272, fade: 8, readiness: 70),
    SimilarSpec(offset: 44, kilometers: 20, start: 282, fade: 13, readiness: 65),
    SimilarSpec(offset: 34, kilometers: 14, start: 271, fade: 9, readiness: 50),
    SimilarSpec(offset: 24, kilometers: 20, start: 285, fade: nil, readiness: 85),
    SimilarSpec(offset: 14, kilometers: 20, start: 270, fade: nil, readiness: 90),
]

let todayPaces: [Double] = [271, 271, 271, 271, 271, 271, 271, 271, 271, 283, 291, 299]

func todayHeartRates(count: Int = todayPaces.count) -> [Double] {
    (0..<count).map { 159 + Double($0) }
}

func encodedSamples(paces: [Double], heartRates: [Double], tail: Double = 0) -> Data {
    var rows = [FITSample(t: 0, heartRate: Int(heartRates[0].rounded()), distance: 0)]
    var time = 0.0
    var distance = 0.0
    for (index, pace) in paces.enumerated() {
        for _ in 0..<10 {
            time += pace / 10
            distance += 100
            rows.append(FITSample(t: time, heartRate: Int(heartRates[index].rounded()), distance: distance))
        }
    }
    for _ in 0..<Int(tail * 10) {
        time += (paces.last ?? 0) / 10
        distance += 100
        rows.append(FITSample(t: time, heartRate: Int((heartRates.last ?? 0).rounded()), distance: distance))
    }
    return try! JSONEncoder().encode(rows)
}

func plannedStructure(kilometers: Double) -> Data {
    let step = PrescribedStep(index: 0, intensity: .active, duration: .distance(meters: kilometers * 1_000), target: .open)
    return try! JSONEncoder().encode(WorkoutStructure(prescription: WorkoutPrescription(name: "Longão", steps: [step])))
}

func makeRun(
    id: Int64, offset: Int, name: String, kilometers: Double, paces: [Double]? = nil, heartRates: [Double]? = nil, plan: Double? = nil
) -> ActivityRecord {
    let day = daysAgo(offset)
    let record = ActivityRecord(
        activityId: id, typeKey: "running", name: name, start: noon(day), distance: kilometers * 1_000, duration: kilometers * 300,
        samplesData: paces.map { encodedSamples(paces: $0, heartRates: heartRates ?? Array(repeating: 150, count: $0.count), tail: kilometers - Double($0.count)) },
        localDay: day.iso, workoutName: name, structureData: plan.map(plannedStructure)
    )
    return record
}

func similarRun(_ spec: SimilarSpec, index: Int, name: String, plan: Double?) -> ActivityRecord {
    let count = Int(spec.kilometers)
    let paces = (1...count).map { km in spec.fade.map { km >= $0 ? spec.start + 12 : spec.start } ?? spec.start }
    let heartRate = 162 - Double(index + 1)
    return makeRun(
        id: Int64(index + 1), offset: spec.offset, name: name, kilometers: spec.kilometers,
        paces: paces, heartRates: Array(repeating: heartRate, count: count), plan: plan
    )
}

func detailedScenario(
    name: String = "Longão", plan: Double? = 20, todayFade: Bool = true, todayReadiness: Int? = 58, specs: [SimilarSpec] = similarSpecs,
    paces customPaces: [Double]? = nil
) -> DetailedScenario {
    let paces = customPaces ?? (todayFade ? todayPaces : Array(todayPaces.prefix(9)))
    let heartRates = todayHeartRates(count: paces.count)
    let record = makeRun(
        id: 100, offset: 0, name: name, kilometers: Double(paces.count) + 0.66, paces: paces, heartRates: heartRates, plan: plan
    )
    var history = specs.enumerated().map { similarRun($1, index: $0, name: name, plan: plan) }
    history += [
        makeRun(id: 201, offset: 9, name: "Ritmo", kilometers: 10),
        makeRun(id: 202, offset: 20, name: "Ritmo", kilometers: 10),
        makeRun(id: 203, offset: 30, name: "Ritmo", kilometers: 10),
        makeRun(id: 204, offset: 2, name: "Ritmo", kilometers: 10),
        makeRun(id: 205, offset: 4, name: "Tiros 6x1000", kilometers: 12),
        makeRun(id: 206, offset: 6, name: "Ritmo", kilometers: 12),
    ]
    var daily = specs.map { DailyRecord(day: daysAgo($0.offset).iso, readinessScore: $0.readiness) }
    if let todayReadiness { daily.append(DailyRecord(day: fixtureToday.iso, readinessScore: todayReadiness)) }
    return DetailedScenario(record: record, history: history, daily: daily)
}

struct FakeGenerator: FeedbackGenerator {
    let reply: String

    func generate(instructions: String, prompt: String) async throws -> String { reply }
}
