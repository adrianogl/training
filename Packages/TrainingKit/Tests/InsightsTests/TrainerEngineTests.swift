import Foundation
import Testing
import TrainingCore
@testable import Insights

@Suite struct TrainerEngineTests {
    private let monday = Day(year: 2026, month: 11, day: 9)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var raceDay: Day { monday.adding(days: 12 * 7 + 5) }

    private var halfMarathon: TrainerTarget {
        TrainerTarget(kind: .race, name: "Meia maratona", date: raceDay, distanceMeters: 21_097.5, goalSeconds: 5_700)
    }

    private func run(
        _ id: Int64, _ day: Day, km: Double, pace: Double, kind: RunKind, fadeKm: Int? = nil, pauses: Int? = nil,
        onTarget: Int? = nil, total: Int? = nil
    ) -> TrainerRun {
        TrainerRun(
            activityId: id, day: day, meters: km * 1_000, seconds: km * pace, kind: kind, fadeKm: fadeKm, pauses: pauses,
            activeOnTarget: onTarget, activeTotal: total
        )
    }

    private func baseHistory(extra: [TrainerRun] = [], readiness: [Day: Int] = [:]) -> TrainerHistory {
        var runs: [TrainerRun] = []
        for week in 1...4 {
            let start = monday.adding(days: -7 * week)
            let base = Int64(week * 10)
            runs.append(run(base + 1, start, km: 8, pace: 340, kind: .easy))
            runs.append(run(base + 2, start.adding(days: 1), km: 10, pace: 262, kind: .tempo, onTarget: 3, total: 3))
            runs.append(run(base + 3, start.adding(days: 2), km: 8, pace: 340, kind: .easy))
            runs.append(run(base + 4, start.adding(days: 5), km: Double(18 - week), pace: 335, kind: .long))
        }
        return TrainerHistory(runs: runs + extra, readiness: readiness, predictions: [10_000: 2_580, 5_000: 1_230])
    }

    private func createPlan(history: TrainerHistory? = nil, strength: [TrainerStrengthSession] = []) -> TrainerPlan {
        TrainerEngine.create(
            target: halfMarathon, structure: TrainerEngine.defaultStructure, strength: strength, history: history ?? baseHistory(), today: monday, now: now
        )
    }

    private func workout(_ plan: TrainerPlan, _ day: Day) throws -> TrainerWorkout {
        try #require(plan.workouts.first { $0.day == day })
    }

    @Test func pacesUseMedianAndPredictions() {
        let paces = TrainerEngine.paces(history: baseHistory(), today: monday)

        #expect(paces.easy == 340)
        #expect(paces.long == 335)
        #expect(paces.threshold == 266)
        #expect(paces.vo2max == 246)
        #expect(paces.easyRuns == 8)
        #expect(paces.thresholdRuns == 4)
    }

    @Test func pacesFallBackWithoutPredictions() {
        var history = baseHistory()
        history.predictions = [:]

        let paces = TrainerEngine.paces(history: history, today: monday)

        #expect(paces.threshold == 262)
        #expect(paces.vo2max == 247)
    }

    @Test func halfMarathonPlanHasThirteenWeeksWithPhases() {
        let plan = createPlan()
        let phases = plan.weeks.map(\.phase)

        #expect(plan.weeks.count == 13)
        #expect(phases.filter { $0 == .base }.count == 3)
        #expect(phases.filter { $0 == .build }.count == 4)
        #expect(phases.filter { $0 == .specific }.count == 4)
        #expect(phases.filter { $0 == .taper }.count == 2)
        #expect(plan.weeks[0].start == monday)
        #expect(plan.versions.first?.trigger == .created)
    }

    @Test func volumesGrowAndRecoverEveryFourthWeek() {
        let weeks = createPlan().weeks

        #expect(weeks[0].targetMeters == 42_000)
        #expect(weeks[1].targetMeters / weeks[0].targetMeters > 1)
        #expect(weeks[1].targetMeters / weeks[0].targetMeters <= 1.10)
        #expect(weeks[3].isRecovery && weeks[7].isRecovery)
        #expect(weeks[3].targetMeters == (weeks[2].targetMeters * 0.8 / 1_000).rounded() * 1_000)
        #expect(weeks[11].targetMeters < weeks[10].targetMeters)
        #expect(weeks[12].targetMeters < weeks[11].targetMeters)
    }

    @Test func longRunsStepUpWithinTheRaceCap() {
        let weeks = createPlan().weeks

        #expect(weeks[0].longMeters == 17_000)
        #expect(weeks[1].longMeters == 19_000)
        #expect(weeks[2].longMeters == 21_000)
        #expect(weeks[3].longMeters == (weeks[2].longMeters * 0.75 / 1_000).rounded() * 1_000)
        #expect(weeks.map(\.longMeters).max() == 22_000)
        #expect(weeks[12].longMeters < weeks[11].longMeters)
    }

    @Test func qualityStagesProgressAndDropOnRecovery() {
        let weeks = createPlan().weeks

        #expect(weeks[0].thresholdFocus == "3 × 2 km")
        #expect(weeks[0].vo2Focus == "5 × 1000 m")
        #expect(weeks[2].thresholdFocus == "4 × 2 km")
        #expect(weeks[3].thresholdFocus == "3 × 2 km")
    }

    @Test func detailCoversFifteenDaysAllByDistance() throws {
        let plan = createPlan()

        #expect(plan.workouts.count == 15)
        #expect(plan.workouts.first?.day == monday)
        let threshold = try workout(plan, monday.adding(days: 1))
        #expect(threshold.title == "Limiar 3 × 2 km")
        #expect(threshold.steps.first?.kind == .warmup && threshold.steps.first?.meters == 3_000)
        #expect(threshold.steps.last?.kind == .cooldown && threshold.steps.last?.meters == 2_000)
        #expect(threshold.steps.first { $0.kind == .recovery }?.meters == 400)
        #expect(try workout(plan, monday.adding(days: 3)).title == "VO2 máx 5 × 1000 m")
        #expect(try workout(plan, monday.adding(days: 5)).title == "Longão 17 km")
        #expect(try workout(plan, monday.adding(days: 4)).note == "só se a prontidão ≥ 60")
        #expect(try workout(plan, monday.adding(days: 6)).kind == .off)
        for item in plan.workouts where item.kind != .off {
            #expect(item.steps.allSatisfy { $0.meters > 0 })
            #expect(!item.title.contains("min"))
            #expect(!item.rationale.isEmpty)
            #expect(abs(item.totalMeters - item.steps.reduce(0) { $0 + Double(max($1.repeats, 0)) * $1.meters }) < 1)
        }
    }

    @Test func raceWeekPutsTheRaceOnItsDay() throws {
        let history = baseHistory()
        let plan = createPlan(history: history)
        let later = TrainerEngine.create(
            target: halfMarathon, structure: plan.structure, strength: [], history: history, today: raceDay.adding(days: -3), now: now
        )

        let race = try workout(later, raceDay)
        #expect(race.kind == .race)
        #expect(race.totalMeters == 21_097.5)
        #expect(race.paceLow == 267 && race.paceHigh == 273)
        #expect(try workout(later, raceDay.adding(days: 1)).kind == .off)
    }

    @Test func longRunBelowEightyFivePercentDelaysTheSkeleton() throws {
        let plan = createPlan()
        let saturday = monday.adding(days: 5)
        let history = baseHistory(
            extra: [run(99, saturday, km: 12.7, pace: 345, kind: .long, fadeKm: 11)], readiness: [saturday: 58]
        )

        let triggers = TrainerEngine.pendingTriggers(plan, history: history, today: saturday)
        #expect(triggers == [.workout(activityId: 99, day: saturday)])

        let adjusted = TrainerEngine.adjust(plan, history: history, today: saturday, now: now, trigger: triggers[0])

        #expect(adjusted.weeks[1].longMeters < plan.weeks[1].longMeters)
        #expect(adjusted.weeks[2].targetMeters == plan.weeks[1].targetMeters)
        #expect(adjusted.weeks[0] == plan.weeks[0])
        #expect(adjusted.processedActivityIds.contains(99))
        let nextLong = try #require(adjusted.workouts.first { $0.kind == .long && $0.day > saturday })
        #expect(nextLong.totalMeters == 17_000)
        #expect(nextLong.note == "gel no km 9")
        let version = try #require(adjusted.versions.last)
        #expect(version.number == 2)
        #expect(version.summary.contains("12,7 km"))
        let change = try #require(version.changes.first { $0.kind == .changed && $0.title.hasPrefix("Longão") })
        #expect(change.before?.hasPrefix("19 km") == true)
        #expect(change.after?.hasPrefix("17 km") == true)
        #expect(change.reason.contains("12,7 km"))
        #expect(version.changes.contains { $0.kind == .skeleton })
        #expect(TrainerEngine.pendingTriggers(adjusted, history: history, today: saturday).isEmpty)
    }

    @Test func veryShortLongRunReducesTwoKilometers() {
        let plan = createPlan()
        let saturday = monday.adding(days: 5)
        let history = baseHistory(extra: [run(98, saturday, km: 10, pace: 345, kind: .long)])

        let adjusted = TrainerEngine.adjust(
            plan, history: history, today: saturday, now: now, trigger: .workout(activityId: 98, day: saturday)
        )

        #expect(adjusted.weeks[1].longMeters == 15_000)
    }

    @Test func offTargetQualityDropsAStageWithLongerRecovery() throws {
        let plan = createPlan()
        let tuesday = monday.adding(days: 1)
        let wednesday = monday.adding(days: 2)
        let history = baseHistory(extra: [run(97, tuesday, km: 11.8, pace: 270, kind: .tempo, onTarget: 2, total: 3)])
        #expect(TrainerEngine.status(of: try workout(plan, tuesday), history: history, today: wednesday).status == .offTarget)

        let adjusted = TrainerEngine.adjust(
            plan, history: history, today: wednesday, now: now, trigger: .workout(activityId: 97, day: tuesday)
        )

        let next = try #require(adjusted.workouts.first { $0.kind == .vo2max && $0.day > wednesday })
        #expect(next.title == "VO2 máx 5 × 1000 m")
        let following = try #require(adjusted.workouts.first { $0.kind == .threshold && $0.day > wednesday })
        #expect(following.title == "Limiar 3 × 2 km")
        #expect(following.steps.first { $0.kind == .recovery }?.meters == 600)
        let lowered = try #require(
            adjusted.versions.last?.changes.first { $0.reason.contains("fora do alvo") }
        )
        #expect(lowered.reason.contains("1 de 3"))
    }

    @Test func lowReadinessWeekCutsTheNextWeekVolume() {
        let plan = createPlan()
        let days = (0..<7).map { monday.adding(days: $0) }
        let history = baseHistory(readiness: Dictionary(uniqueKeysWithValues: days.map { ($0, 50) }))
        let nextMonday = monday.adding(days: 7)

        let adjusted = TrainerEngine.adjust(plan, history: history, today: nextMonday, now: now, trigger: .weekEnded(1))

        #expect(adjusted.weeks[1].targetMeters == (plan.weeks[0].targetMeters * 0.9 / 1_000).rounded() * 1_000)
        #expect(adjusted.versions.last?.summary.contains("prontidão") == true)
    }

    @Test func goodWeekKeepsTheSkeleton() {
        let plan = createPlan()
        let nextMonday = monday.adding(days: 7)

        let triggers = TrainerEngine.pendingTriggers(plan, history: baseHistory(), today: nextMonday)
        #expect(triggers == [.weekEnded(1)])

        let adjusted = TrainerEngine.adjust(plan, history: baseHistory(), today: nextMonday, now: now, trigger: .weekEnded(1))

        #expect(adjusted.weeks == plan.weeks)
        #expect(adjusted.versions.last?.summary.contains("segue o esqueleto") == true)
        #expect(adjusted.versions.last?.changes.contains { $0.kind == .newWeek } == true)
        #expect(TrainerEngine.pendingTriggers(adjusted, history: baseHistory(), today: nextMonday).isEmpty)
    }

    @Test func travelMovesQualityBeforeAndTurnsTheLongRunIntoAnEasyRun() throws {
        let plan = createPlan()
        let thursday = monday.adding(days: 3)
        let saturday = monday.adding(days: 5)
        let request = TrainerRequest(category: .travel, text: "viagem a trabalho", from: thursday, until: saturday)

        let adjusted = TrainerEngine.adjust(plan, history: baseHistory(), today: monday, now: now, trigger: .request(request))

        let wednesday = try workout(adjusted, monday.adding(days: 2))
        #expect(wednesday.kind == .vo2max)
        #expect(wednesday.title == "VO2 máx 5 × 1000 m")
        #expect(try workout(adjusted, thursday).kind == .off)
        let travelRun = try workout(adjusted, saturday)
        #expect(travelRun.kind == .easy && travelRun.totalMeters == 6_000)
        let back = try workout(adjusted, monday.adding(days: 6))
        #expect(back.kind == .long && back.title == "Longão 17 km")
        let version = try #require(adjusted.versions.last)
        #expect(version.changes.filter { $0.kind == .moved }.count == 2)
        #expect(version.changes.allSatisfy { !$0.reason.isEmpty })
        let later = TrainerEngine.adjust(
            adjusted, history: baseHistory(), today: monday.adding(days: 1), now: now, trigger: .weekEnded(1)
        )
        #expect(try workout(later, wednesday.day).kind == .vo2max)
    }

    @Test func painTurnsQualityIntoEasyRunsAndAddsTheWarning() throws {
        let plan = createPlan()
        let request = TrainerRequest(
            category: .pain, text: "dor no joelho", from: monday.adding(days: 1), until: monday.adding(days: 4)
        )

        let adjusted = TrainerEngine.adjust(plan, history: baseHistory(), today: monday, now: now, trigger: .request(request))

        for offset in 1...4 {
            let item = try workout(adjusted, monday.adding(days: offset))
            #expect(item.kind != .threshold && item.kind != .vo2max)
        }
        let original = try workout(plan, monday.adding(days: 2))
        #expect(try workout(adjusted, monday.adding(days: 2)).totalMeters < original.totalMeters)
        let version = try #require(adjusted.versions.last)
        #expect(version.summary.contains("Dor que persiste é caso para médico ou fisioterapeuta."))
        #expect(version.changes.contains { $0.kind == .changed && $0.reason.contains("Dor relatada") })
    }

    @Test func moreTimeTurnsOptionalRunMandatory() throws {
        let plan = createPlan()
        let friday = monday.adding(days: 4)
        let request = TrainerRequest(category: .moreTime, text: "tenho mais tempo", from: friday, until: friday)

        let adjusted = TrainerEngine.adjust(plan, history: baseHistory(), today: monday, now: now, trigger: .request(request))

        #expect(try workout(adjusted, friday).kind == .easy)
        #expect(try workout(adjusted, friday).note == nil)
    }

    @Test func otherRequestsRecreateKeepingThePast() throws {
        let plan = createPlan()
        let thursday = monday.adding(days: 3)
        let request = TrainerRequest(category: .goalChanged, text: "nova meta", from: thursday)

        let adjusted = TrainerEngine.adjust(plan, history: baseHistory(), today: thursday, now: now, trigger: .request(request))

        #expect(adjusted.workouts.filter { $0.day < thursday } == plan.workouts.filter { $0.day < thursday })
        #expect(adjusted.workouts.first?.day == monday)
        #expect(adjusted.weeks.first?.start == monday)
        #expect(adjusted.versions.count == 2)
    }

    @Test func statusFollowsTheRunOfTheSameDay() throws {
        let plan = createPlan()
        let tuesday = monday.adding(days: 1)
        let threshold = try workout(plan, tuesday)
        let wednesday = monday.adding(days: 2)

        func status(_ runs: [TrainerRun], today: Day) -> TrainerDayStatus {
            TrainerEngine.status(of: threshold, history: TrainerHistory(runs: runs), today: today).status
        }

        let full = run(1, tuesday, km: 11.8, pace: 270, kind: .tempo, onTarget: 3, total: 3)
        let short = run(2, tuesday, km: 9, pace: 270, kind: .tempo, onTarget: 3, total: 3)
        let off = run(3, tuesday, km: 11.8, pace: 270, kind: .tempo, onTarget: 1, total: 3)
        #expect(status([full], today: wednesday) == .done)
        #expect(status([short], today: wednesday) == .partial)
        #expect(status([off], today: wednesday) == .offTarget)
        #expect(status([], today: wednesday) == .missed)
        #expect(status([], today: tuesday) == .today)
        #expect(status([], today: monday) == .planned)
        let optional = try workout(plan, monday.adding(days: 4))
        let rest = try workout(plan, monday.adding(days: 6))
        let later = monday.adding(days: 8)
        #expect(TrainerEngine.status(of: optional, history: TrainerHistory(runs: []), today: later).status == .skipped)
        #expect(TrainerEngine.status(of: rest, history: TrainerHistory(runs: []), today: later).status == .skipped)
        let result = TrainerEngine.status(of: threshold, history: TrainerHistory(runs: [full]), today: wednesday)
        #expect(result.run?.activityId == 1)
    }

    @Test func classifiesRequestsByKeyword() {
        #expect(TrainerEngine.classify(requestText: "Vou viajar na quinta") == .travel)
        #expect(TrainerEngine.classify(requestText: "Fico no hotel até sábado") == .travel)
        #expect(TrainerEngine.classify(requestText: "Estou com dor no joelho") == .pain)
        #expect(TrainerEngine.classify(requestText: "Tive uma lesão") == .pain)
        #expect(TrainerEngine.classify(requestText: "Um incômodo na panturrilha") == .pain)
        #expect(TrainerEngine.classify(requestText: "Estou muito cansado") == .fatigue)
        #expect(TrainerEngine.classify(requestText: "Dormi pouco, muito sono") == .fatigue)
        #expect(TrainerEngine.classify(requestText: "Esta semana tenho mais tempo livre") == .moreTime)
        #expect(TrainerEngine.classify(requestText: "Quero mudar a meta") == .goalChanged)
        #expect(TrainerEngine.classify(requestText: "Fiz uma prova nova") == .goalChanged)
        #expect(TrainerEngine.classify(requestText: "Trocar o dia do longão") == .other)
        #expect(TrainerEngine.classify(requestText: "O corredor chegou") == .other)
    }

    @Test func planWithoutDateUsesTwelveWeekCycles() {
        let target = TrainerTarget(kind: .text, name: "Ficar mais forte", text: "ficar mais forte")
        let plan = TrainerEngine.create(
            target: target, structure: TrainerEngine.defaultStructure, strength: [], history: baseHistory(), today: monday, now: now
        )

        #expect(plan.weeks.count == 12)
        #expect(plan.weeks.allSatisfy { $0.phase != .taper })
        #expect(plan.weeks.map(\.longMeters).max() == 20_000)
    }
}
