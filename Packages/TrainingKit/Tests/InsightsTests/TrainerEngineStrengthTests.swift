import Foundation
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import Insights

@Suite struct TrainerEngineStrengthTests {
    private let monday = Day(year: 2026, month: 11, day: 9)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var halfMarathon: TrainerTarget {
        TrainerTarget(kind: .race, name: "Meia maratona", date: monday.adding(days: 12 * 7 + 5), distanceMeters: 21_097.5, goalSeconds: 5_700)
    }

    private func run(
        _ id: Int64, _ day: Day, km: Double, pace: Double, kind: RunKind, onTarget: Int? = nil, total: Int? = nil
    ) -> TrainerRun {
        TrainerRun(
            activityId: id, day: day, meters: km * 1_000, seconds: km * pace, kind: kind, activeOnTarget: onTarget, activeTotal: total
        )
    }

    private func realStrength() -> [TrainerStrengthDone] {
        let names = [(0, "Superiores (segunda)"), (2, "MMII (quarta)"), (4, "Full Body (sexta)")]
        var id: Int64 = 500
        return (1...3).flatMap { week -> [TrainerStrengthDone] in
            names.map { offset, name in
                id += 1
                return TrainerStrengthDone(
                    activityId: id, day: monday.adding(days: -7 * week + offset), name: name, seconds: 2_700
                )
            }
        }
    }

    private func baseHistory(extra: [TrainerRun] = [], strength: [TrainerStrengthDone] = []) -> TrainerHistory {
        var runs: [TrainerRun] = []
        for week in 1...4 {
            let start = monday.adding(days: -7 * week)
            let base = Int64(week * 10)
            runs.append(run(base + 1, start, km: 8, pace: 340, kind: .easy))
            runs.append(run(base + 2, start.adding(days: 1), km: 10, pace: 262, kind: .tempo, onTarget: 3, total: 3))
            runs.append(run(base + 3, start.adding(days: 2), km: 8, pace: 340, kind: .easy))
            runs.append(run(base + 4, start.adding(days: 5), km: Double(18 - week), pace: 335, kind: .long))
        }
        return TrainerHistory(
            runs: runs + extra, predictions: [10_000: 2_580, 5_000: 1_230], strength: strength
        )
    }

    private let mmii = TrainerStrengthSession(weekday: 3, group: .lower, legLoad: .heavy, name: "MMII")
    private let fullBody = TrainerStrengthSession(weekday: 5, group: .fullBody, legLoad: .light, name: "Full body")

    private func createPlan(strength: [TrainerStrengthSession], history: TrainerHistory? = nil) -> TrainerPlan {
        TrainerEngine.create(
            target: halfMarathon, structure: TrainerEngine.defaultStructure, strength: strength,
            history: history ?? baseHistory(), today: monday, now: now
        )
    }

    private func workout(_ plan: TrainerPlan, _ offset: Int) throws -> TrainerWorkout {
        try #require(plan.workouts.first { $0.day == monday.adding(days: offset) })
    }

    @Test func detectsTheThreeRealSessions() {
        let sessions = TrainerEngine.detectStrength(history: baseHistory(strength: realStrength()), today: monday)

        #expect(sessions.map(\.weekday) == [1, 3, 5])
        #expect(sessions.map(\.name) == ["Superiores", "MMII", "Full body"])
        #expect(sessions.map(\.group) == [.upper, .lower, .fullBody])
        #expect(sessions.map(\.legLoad) == [.light, .heavy, .light])
    }

    @Test func detectionIgnoresDaysWithASingleOccurrenceAndUsesTheCommonNameForUnknownGroups() {
        var strength = realStrength().filter { $0.name.hasPrefix("MMII") }.prefix(1).map { $0 }
        let extra = [
            TrainerStrengthDone(activityId: 900, day: monday.adding(days: -6), name: "Treino do Pedro", seconds: 3_000),
            TrainerStrengthDone(activityId: 901, day: monday.adding(days: -13), name: "Treino do Pedro", seconds: 3_000),
        ]
        strength += extra

        let sessions = TrainerEngine.detectStrength(history: baseHistory(strength: strength), today: monday)

        #expect(sessions.count == 1)
        #expect(sessions.first?.weekday == 2)
        #expect(sessions.first?.name == "Treino do Pedro")
        #expect(sessions.first?.group == .fullBody)
    }

    @Test func warmupStaysAtThreeKilometersAfterHeavyLegs() throws {
        let plan = createPlan(strength: [mmii])

        let vo2 = try workout(plan, 3)
        #expect(vo2.steps.first?.kind == .warmup && vo2.steps.first?.meters == 3_000)
        #expect(vo2.totalMeters == 9_000)
        #expect(vo2.note == "pernas de ontem (MMII)")
        #expect(vo2.rationale.contains("MMII"))
        #expect(vo2.rationale.contains("aquecimento continua em 3 km"))
        let threshold = try workout(plan, 1)
        #expect(threshold.steps.first?.meters == 3_000)
        #expect(threshold.note == nil)
    }

    @Test func strengthOnTheSameDayDoesNotChangeTheRun() throws {
        let thursdayStrength = TrainerStrengthSession(weekday: 4, group: .lower, legLoad: .heavy, name: "MMII")
        let plan = createPlan(strength: [thursdayStrength])
        let plain = createPlan(strength: [])

        let vo2 = try workout(plan, 3)
        #expect(vo2.steps == (try workout(plain, 3)).steps)
        #expect(vo2.note == nil)
    }

    @Test func longRunAfterFullBodyStartsSlower() throws {
        let plan = createPlan(strength: [fullBody])

        let long = try workout(plan, 5)
        #expect(long.steps.count == 2)
        #expect(long.steps[0].kind == .steady && long.steps[0].meters == 5_000)
        #expect(long.steps[1].meters == 12_000)
        #expect(long.steps[0].paceLow == 338 && long.steps[0].paceHigh == 352)
        #expect(long.steps[1].paceLow == 328 && long.steps[1].paceHigh == 342)
        #expect(long.totalMeters == 17_000)
        #expect(long.note?.contains("começa mais lento: força ontem") == true)
        #expect(createPlan(strength: []).workouts.first { $0.day == monday.adding(days: 5) }?.steps.count == 1)
    }

    @Test func offTargetQualityAfterLegsCitesTheStrength() throws {
        let plan = createPlan(strength: [mmii])
        let thursday = monday.adding(days: 3)
        let friday = monday.adding(days: 4)
        let history = baseHistory(extra: [run(97, thursday, km: 12.6, pace: 250, kind: .intervals, onTarget: 3, total: 5)])

        let adjusted = TrainerEngine.adjust(
            plan, history: history, today: friday, now: now, trigger: .workout(activityId: 97, day: thursday)
        )

        let version = try #require(adjusted.versions.last)
        #expect(version.summary.contains("MMII"))
        #expect(version.changes.contains { $0.reason.contains("força de pernas") })
        #expect(!version.summary.contains("Pense em fazer"))
    }

    @Test func twoWeeksInARowSuggestMovingTheLegsToTheThresholdDay() throws {
        let plan = createPlan(strength: [mmii])
        let firstThursday = monday.adding(days: 3)
        let secondThursday = monday.adding(days: 10)
        let history = baseHistory(extra: [
            run(97, firstThursday, km: 12.6, pace: 250, kind: .intervals, onTarget: 3, total: 5),
            run(98, secondThursday, km: 12.6, pace: 250, kind: .intervals, onTarget: 2, total: 5),
        ])

        let adjusted = TrainerEngine.adjust(
            plan, history: history, today: secondThursday.adding(days: 1), now: now,
            trigger: .workout(activityId: 98, day: secondThursday)
        )

        let summary = try #require(adjusted.versions.last?.summary)
        #expect(summary.contains("Pense em fazer o MMII no dia do vo2 máx, depois da corrida. O plano não muda a musculação sozinho."))
    }

    @Test func strengthChangedRecalculatesTheDetail() throws {
        let plan = createPlan(strength: [])
        var edited = plan
        edited.strength = [mmii]

        let adjusted = TrainerEngine.adjust(edited, history: baseHistory(), today: monday, now: now, trigger: .strengthChanged)

        let version = try #require(adjusted.versions.last)
        #expect(version.trigger == .strengthChanged)
        let change = try #require(version.changes.first { $0.kind == .changed && $0.title.hasPrefix("VO2") })
        #expect(change.before == "sem observação")
        #expect(change.after == "pernas de ontem (MMII)")
        #expect(change.reason.contains("MMII"))
        #expect(try workout(adjusted, 3).steps.first?.meters == 3_000)
        #expect(adjusted.strength == [mmii])
        #expect(adjusted.weeks.map(\.targetMeters) == plan.weeks.map(\.targetMeters))
    }

    @Test func removingTheStrengthRemovesTheLegsNote() throws {
        let plan = createPlan(strength: [mmii])
        var edited = plan
        edited.strength = []

        let adjusted = TrainerEngine.adjust(edited, history: baseHistory(), today: monday, now: now, trigger: .strengthChanged)

        let change = try #require(adjusted.versions.last?.changes.first { $0.title.hasPrefix("VO2") })
        #expect(change.before == "pernas de ontem (MMII)")
        #expect(change.after == "sem observação")
        #expect(!change.reason.isEmpty)
    }

    @Test func oldJsonWithoutStrengthStillDecodes() throws {
        let plan = createPlan(strength: [mmii])
        let data = try JSONEncoder().encode(plan)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["strength"] = nil
        object["weeks"] = (object["weeks"] as? [[String: Any]])?.map { week in
            var copy = week
            copy["targetMeters"] = nil
            return copy
        }
        let old = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(TrainerPlan.self, from: old)

        #expect(decoded.strength.isEmpty)
        #expect(decoded.weeks.allSatisfy { $0.targetMeters == $0.plannedMeters })
        #expect(decoded.workouts == plan.workouts)
    }

    @Test func plannedMetersIsTheSumOfAllWorkoutsWithTheOptionalOne() throws {
        let plan = createPlan(strength: [mmii, fullBody])
        let pain = TrainerRequest(category: .pain, text: "dor no joelho", from: monday.adding(days: 1), until: monday.adding(days: 4))
        let adjusted = TrainerEngine.adjust(plan, history: baseHistory(), today: monday, now: now, trigger: .request(pain))

        for candidate in [plan, adjusted] {
            for week in candidate.weeks.prefix(2) {
                let items = candidate.workouts.filter { $0.day.weekStart == week.start }
                #expect(items.count == 7)
                let sum = items.reduce(0.0) { $0 + $1.totalMeters }
                #expect(week.plannedMeters == sum)
            }
        }
        #expect(plan.weeks[0].plannedMeters >= plan.weeks[0].targetMeters - 1_500)
        #expect(plan.weeks[0].targetMeters == 42_000)
    }

    @Test func skeletonOnlyWeeksUseTheSameFormula() throws {
        let plan = createPlan(strength: [])
        let week = plan.weeks[4]

        let share = TrainerEngine.easyShare(
            week: week, weeks: plan.weeks, target: plan.target, structure: plan.structure, history: baseHistory(), today: monday
        )
        func session(_ kind: TrainerDayKind) -> TrainerQualitySession {
            TrainerEngine.qualitySession(kind, week: week, weeks: plan.weeks, target: plan.target, lowered: false)
        }
        let quality = TrainerEngine.qualityMeters(session(.threshold)) + TrainerEngine.qualityMeters(session(.vo2max))
        #expect(week.plannedMeters == week.longMeters + quality + 2 * share.meters + share.optional)
    }

    @Test func strengthStatusMarksTheDoneSession() {
        var plan = createPlan(strength: [mmii])
        plan.strength = [mmii, fullBody]
        let wednesday = monday.adding(days: 2)
        let done = TrainerStrengthDone(activityId: 7, day: wednesday, name: "MMII (quarta)", seconds: 2_700)
        let history = baseHistory(strength: [done])

        let status = TrainerEngine.strengthStatus(day: wednesday, plan: plan, history: history)

        #expect(status.count == 1)
        #expect(status.first?.session == mmii)
        #expect(status.first?.done == done)
        #expect(TrainerEngine.strengthStatus(day: monday.adding(days: 4), plan: plan, history: history).first?.done == nil)
        #expect(TrainerEngine.strengthStatus(day: monday, plan: plan, history: history).isEmpty)
    }
}
