import Foundation
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import Insights

@Suite struct TrainerVolumeSuggestionTests {
    private let monday = Day(year: 2026, month: 11, day: 23)
    private let paces = TrainerPaces(easy: 320, long: 315, threshold: 255, vo2max: 238)
    private let structure: [Int: TrainerDayKind] = [1: .easy, 2: .threshold, 3: .easy, 4: .vo2max, 5: .easy, 6: .long, 7: .off]
    private let text = TrainerTarget(kind: .text, name: "Correr bem", text: "correr bem")

    private func history(_ kilometers: [Double]) -> TrainerHistory {
        var runs: [TrainerRun] = []
        for (index, km) in kilometers.reversed().enumerated() {
            let start = monday.adding(days: -7 * (index + 1))
            runs.append(TrainerRun(activityId: Int64(index * 10 + 1), day: start, meters: km * 600, seconds: km * 600 * 0.32, kind: .easy))
            runs.append(TrainerRun(activityId: Int64(index * 10 + 2), day: start.adding(days: 5), meters: km * 400, seconds: km * 400 * 0.32, kind: .long))
        }
        return TrainerHistory(runs: runs)
    }

    private func plan(recovery: Day) -> TrainerPlan {
        let week = TrainerWeek(
            index: 4, start: recovery, phase: .base, isRecovery: true, plannedMeters: 40_000, longMeters: 12_000, thresholdFocus: "", vo2Focus: ""
        )
        return TrainerPlan(target: text, structure: structure, paces: paces, weeks: [week], workouts: [], versions: [])
    }

    @Test func plannedLightWeekStaysOutOfTheBase() {
        let light = monday.adding(days: -14)
        let base = TrainerEngine.normalWeeklyMeters(history: history([55, 57, 58, 60, 30, 48]), today: monday, plan: plan(recovery: light))

        #expect(base.meters == 56_000)
        #expect(base.excluded == [TrainerExcludedWeek(start: light, reason: .light)])
        #expect(base.fromNormalWeeks)
    }

    @Test func unusuallyLowWeekStaysOutWithoutAPlan() {
        let base = TrainerEngine.normalWeeklyMeters(history: history([55, 57, 58, 60, 30, 48]), today: monday, plan: nil)

        #expect(base.excluded.map(\.reason) == [.low])
        #expect(base.meters == 56_000)
    }

    @Test func fallsBackToTheSimpleAverageWithoutNormalWeeks() {
        let base = TrainerEngine.normalWeeklyMeters(history: history([0, 0, 0, 0, 0, 20]), today: monday, plan: nil)

        #expect(!base.fromNormalWeeks)
        #expect(base.excluded.isEmpty)
    }

    @Test func peakGrowsAQuarterWhenNothingElseLimits() {
        let suggestion = TrainerEngine.volumeSuggestion(
            history: history([40, 42, 41, 40, 42, 41]), today: monday, plan: nil, review: nil, structure: structure, paces: paces, target: text
        )

        #expect(suggestion.startMeters == 41_000)
        #expect(suggestion.peakMeters == TrainerEngine.defaultPeak(from: 41_000))
        #expect(suggestion.limit == .growth)
    }

    @Test func fewRunsCapThePeakAtTheComfortableVolume() {
        let three: [Int: TrainerDayKind] = [2: .threshold, 4: .easy, 6: .long]
        let suggestion = TrainerEngine.volumeSuggestion(
            history: history([60, 62, 61, 60, 62, 61]), today: monday, plan: nil, review: nil, structure: three, paces: paces, target: text
        )

        let comfortable = TrainerEngine.volumeRange(structure: three, paces: paces, target: text).comfortable
        #expect(suggestion.limit == .comfortable(runs: 3))
        #expect(suggestion.peakMeters == max(TrainerEngine.floorKilometers(comfortable), suggestion.startMeters))
    }

    @Test func closeRaceCapsThePeakAtWhatFitsBeforeIt() {
        let race = TrainerTarget(kind: .race, name: "10 km", date: monday.adding(days: 19), distanceMeters: 10_000, goalSeconds: 2_400)
        let suggestion = TrainerEngine.volumeSuggestion(
            history: history([50, 52, 51, 50, 52, 51]), today: monday, plan: nil, review: nil, structure: structure, paces: paces, target: race
        )

        #expect(suggestion.limit == .deadline(weeks: 2))
        #expect(TrainerEngine.weeksToPeak(startMeters: suggestion.startMeters, peakMeters: suggestion.peakMeters) <= 2)
    }

    @Test func generalPhaseWeeksDoNotCountAsGrowth() {
        let race = TrainerTarget(kind: .race, name: "Maratona", date: monday.adding(days: 7 * 19 + 6), distanceMeters: 42_195, goalSeconds: 12_600)
        let plan = TrainerEngine.create(
            target: race, structure: structure, strength: [], history: history([60, 62, 61, 60, 62, 61]), today: monday,
            now: Date(timeIntervalSince1970: 1_800_000_000), startMeters: 61_000, peakMeters: 100_000
        )
        let suggestion = TrainerEngine.volumeSuggestion(
            history: history([60, 62, 61, 60, 62, 61]), today: monday, plan: nil, review: nil, structure: structure, paces: paces, target: race
        )
        let reached = plan.weeks.filter { !$0.isRecovery && $0.phase != .taper }.map(\.targetMeters).max() ?? 0

        #expect(plan.weeks.contains { $0.phase == .general })
        #expect(suggestion.peakMeters <= max(reached, suggestion.startMeters))
    }
}
