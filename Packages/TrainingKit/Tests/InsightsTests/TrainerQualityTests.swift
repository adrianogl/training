import Foundation
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import Insights

@Suite struct TrainerQualityTests {
    private let monday = Day(year: 2026, month: 11, day: 9)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let paces = TrainerPaces(easy: 340, long: 335, threshold: 245, vo2max: 228, race: 255)

    private func target(weeks: Int, meters: Double = 21_097.5) -> TrainerTarget {
        TrainerTarget(kind: .race, name: "Prova", date: monday.adding(days: weeks * 7 + 5), distanceMeters: meters, goalSeconds: 5_700)
    }

    private var goalTarget: TrainerTarget {
        TrainerTarget(
            kind: .paceDistance, name: "4:00/km até 21 km", date: monday.adding(days: 13 * 7 + 5), distanceMeters: 21_000, goalPace: 240
        )
    }

    private func run(_ id: Int64, _ day: Day, km: Double, pace: Double, kind: RunKind, onTarget: Int? = nil, total: Int? = nil) -> TrainerRun {
        TrainerRun(
            activityId: id, day: day, meters: km * 1_000, seconds: km * pace, kind: kind, activeOnTarget: onTarget, activeTotal: total
        )
    }

    private func history(extra: [TrainerRun] = []) -> TrainerHistory {
        var runs: [TrainerRun] = []
        for week in 1...4 {
            let start = monday.adding(days: -7 * week)
            let base = Int64(week * 10)
            runs.append(run(base + 1, start, km: 8, pace: 340, kind: .easy))
            runs.append(run(base + 2, start.adding(days: 1), km: 10, pace: 262, kind: .tempo, onTarget: 3, total: 3))
            runs.append(run(base + 3, start.adding(days: 2), km: 8, pace: 340, kind: .easy))
            runs.append(run(base + 4, start.adding(days: 5), km: Double(18 - week), pace: 335, kind: .long))
        }
        return TrainerHistory(runs: runs + extra, predictions: [10_000: 2_580, 5_000: 1_230])
    }

    private func create(_ target: TrainerTarget, extra: [TrainerRun] = []) -> TrainerPlan {
        TrainerEngine.create(
            target: target, structure: TrainerEngine.defaultStructure, strength: [], history: history(extra: extra),
            today: monday, now: now
        )
    }

    private func openWeeks(total: Int = 24) -> [TrainerWeek] {
        let context = TrainerSkeletonContext(total: total, taperWeeks: 0, openEnded: true, longCap: 22_000, peakVolume: 72_000)
        let state = TrainerSkeletonState(volume: 70_000, long: 16_000, stage: 0, weeksAtStage: 0, started: false)
        return TrainerEngine.buildWeeks(
            context: context, firstIndex: 1, firstStart: monday, state: state, adjustment: TrainerSkeletonAdjustment()
        )
    }

    private func total(_ session: TrainerQualitySession) -> Double {
        session.blocks.reduce(0) { $0 + Double($1.repeats) * $1.meters }
    }

    @Test func thresholdBlocksClimbTheLadderAndRestart() {
        let weeks = openWeeks()
        var sizes: [Double] = []
        for week in weeks where !week.isRecovery {
            let session = TrainerEngine.thresholdSession(week: week, lowered: false)
            let size = session.method == .tempo ? 0 : session.blocks[0].meters
            if sizes.last != size { sizes.append(size) }
        }

        #expect(Array(sizes.prefix(6)) == [1_000, 2_000, 3_000, 4_000, 0, 1_000])
    }

    @Test func thresholdVolumeFollowsThePhase() {
        let plan = TrainerEngine.create(
            target: target(weeks: 16), structure: TrainerEngine.defaultStructure, strength: [], history: history(), today: monday, now: now
        )
        for week in plan.weeks {
            let volume = total(TrainerEngine.thresholdSession(week: week, lowered: false))
            if week.phase == .taper {
                #expect(volume <= 6_000)
            } else if week.isRecovery {
                #expect(volume == 6_000)
            } else if week.phase == .base {
                #expect((8_000...9_000).contains(volume))
            } else {
                #expect((8_000...12_000).contains(volume))
            }
        }
        let first = TrainerEngine.thresholdSession(week: plan.weeks[0], lowered: false)
        #expect(first.blocks == [TrainerQualityBlock(repeats: 8, meters: 1_000)])
        let recovery = TrainerEngine.thresholdSession(week: plan.weeks[3], lowered: false)
        #expect(recovery.blocks.map(\.meters) == [3_000, 2_000, 1_000])
    }

    @Test func continuousThresholdUsesSixPlusThreeOrTwoFives() {
        var week = openWeeks()[0]
        week.thresholdFocus = TrainerEngineText.stageLabel(TrainerEngineConstants.thresholdBlocks[4])
        week.phase = .build
        let six = TrainerEngine.thresholdSession(week: week, lowered: false)
        #expect(six.method == .tempo && six.blocks.map(\.meters) == [6_000, 3_000])
        week.phase = .specific
        let two = TrainerEngine.thresholdSession(week: week, lowered: false)
        #expect(two.method == .tempo && two.blocks == [TrainerQualityBlock(repeats: 2, meters: 5_000)])
    }

    @Test func thresholdRestIsSixtySecondsPerKilometerWithCap() {
        func rest(_ meters: Double, lowered: Bool = false) -> Double {
            let session = TrainerQualitySession(
                kind: .threshold, method: .cruiseIntervals, blocks: [TrainerQualityBlock(repeats: 2, meters: meters)], closing: false
            )
            return TrainerEngine.restSeconds(session: session, block: session.blocks[0], paces: paces, lowered: lowered)
        }

        #expect(rest(1_000) == 60)
        #expect(rest(2_000) == 120)
        #expect(rest(3_000) == 180)
        #expect(rest(4_000) == 240)
        #expect(rest(6_000) == 240)
        #expect(rest(500) == 60)
        #expect(rest(2_000, lowered: true) == 180)
    }

    private func week(_ index: Int, phase: TrainerPhase = .build, recovery: Bool = false) -> TrainerWeek {
        TrainerWeek(
            index: index, start: monday.adding(days: (index - 1) * 7), phase: phase, isRecovery: recovery, plannedMeters: 70_000,
            longMeters: 20_000, thresholdFocus: TrainerEngineText.stageLabel(1_000), vo2Focus: ""
        )
    }

    @Test func vo2RotatesFormatsAndShortensOnRecovery() {
        func labels(_ weeks: [TrainerWeek]) -> [String] {
            weeks.map { TrainerEngineText.sessionLabel(TrainerEngine.vo2Session(week: $0, weeks: weeks, lowered: false).blocks) }
        }
        let build = (1...6).map { week($0) }
        let base = (1...4).map { week($0, phase: .base) }
        let withRecovery = [week(1), week(2), week(3), week(4, recovery: true), week(5)]

        #expect(labels(build) == ["5 × 1 km", "6 × 800 m", "4 × 1,5 km", "12 × 400 m", "2 × 1,5 km + 2 × 1 km", "5 × 1 km"])
        #expect(labels(base) == ["8 × 200 m", "5 × 1 km", "8 × 200 m", "6 × 800 m"])
        #expect(labels(withRecovery) == ["5 × 1 km", "6 × 800 m", "4 × 1,5 km", "8 × 400 m", "2 × 1,5 km + 2 × 1 km"])
        #expect(TrainerEngine.vo2Session(week: base[0], weeks: base, lowered: false).variant == .hills)
        #expect(labels([week(12, phase: .taper)]) == ["3 × 1 km"])
        for item in build {
            let volume = total(TrainerEngine.vo2Session(week: item, weeks: build, lowered: false))
            #expect((4_000...6_000).contains(volume))
        }
    }

    @Test func hillsJogDownWithoutClosingRepetitions() {
        let base = [week(1, phase: .base)]
        let session = TrainerEngine.vo2Session(week: base[0], weeks: base, lowered: false)
        let workout = TrainerEngine.qualityWorkout(day: monday, session: session, paces: paces, lowered: false, rationale: "x")

        #expect(workout.title.hasPrefix("Subidas ") && TrainerEngine.describe(workout).hasPrefix("8 × 200 m"))
        #expect(workout.variant == .hills)
        #expect(!workout.steps.contains { $0.method == .repetition })
        #expect(workout.steps.last == TrainerStep(kind: .recovery, repeats: 7, meters: 200))
        #expect(workout.totalMeters == 3_000 + 1_600 + 1_400)
    }

    @Test func vo2RestIsSeventyPercentRoundedWithMinimums() {
        func rest(_ meters: Double) -> Double {
            let session = TrainerQualitySession(
                kind: .vo2max, method: .intervals, blocks: [TrainerQualityBlock(repeats: 4, meters: meters)], closing: true
            )
            return TrainerEngine.restSeconds(session: session, block: session.blocks[0], paces: paces, lowered: false)
        }

        #expect(rest(1_000) == 150)
        #expect(rest(1_500) == 240)
        #expect(rest(400) == 60)
        #expect(rest(1_200) == 180)
    }

    @Test func vo2ClosesWithThreeRepetitionsAndMeterJogs() throws {
        let session = TrainerEngine.vo2Session(week: week(1), weeks: [week(1)], lowered: false)
        let workout = TrainerEngine.qualityWorkout(day: monday, session: session, paces: paces, lowered: false, rationale: "x")
        let closing = try #require(workout.steps.last { $0.kind == .work })
        let jog = try #require(workout.steps.last)

        #expect(workout.method == .intervals)
        #expect(workout.steps.filter { $0.kind == .work }.first?.method == .intervals)
        #expect(closing.method == .repetition && closing.repeats == 3 && closing.meters == 200)
        #expect(closing.paceLow == 219 && closing.paceHigh == 225)
        #expect(jog.kind == .recovery && jog.meters == 200 && jog.repeats == 2 && jog.restSeconds == nil)
        #expect(workout.totalMeters == 3_000 + 5_000 + 600 + 400)
        #expect(abs(workout.totalMeters - workout.steps.reduce(0) { $0 + Double($1.repeats) * $1.meters }) < 1)
    }

    @Test func pyramidVo2KeepsTheRestBetweenGroups() {
        let weeks = (1...5).map { week($0) }
        let session = TrainerEngine.vo2Session(week: weeks[4], weeks: weeks, lowered: false)
        let steps = TrainerEngine.qualitySteps(session: session, paces: paces, lowered: false)
        let rests = steps.filter { $0.kind == .recovery && $0.restSeconds != nil }

        #expect(steps.filter { $0.kind == .work && $0.method == .intervals }.map(\.meters) == [1_500, 1_000])
        #expect(rests.map(\.restSeconds) == [240, 240, 150, 150])
    }

    @Test func racePaceAlternatesWithThresholdOnlyInTheSpecificPhase() throws {
        let plan = TrainerEngine.create(
            target: target(weeks: 12), structure: TrainerEngine.defaultStructure, strength: [], history: history(), today: monday, now: now
        )
        let specific = plan.weeks.filter { $0.phase == .specific && !$0.isRecovery }
        let sessions = specific.map { TrainerEngine.racePaceSession(week: $0, weeks: plan.weeks, target: plan.target) }

        #expect(specific.count == 3)
        #expect(sessions.map { $0 != nil } == [true, false, true])
        #expect(sessions[0]?.blocks == [TrainerQualityBlock(repeats: 2, meters: 4_000)])
        #expect(sessions[2]?.blocks == [TrainerQualityBlock(repeats: 3, meters: 4_000)])
        #expect(sessions[0]?.method == .racePace)
        for week in plan.weeks where week.phase != .specific {
            #expect(TrainerEngine.racePaceSession(week: week, weeks: plan.weeks, target: plan.target) == nil)
        }
        let workout = TrainerEngine.qualityWorkout(
            day: monday, session: try #require(sessions[0]), paces: paces, lowered: false, rationale: "x"
        )
        #expect(workout.title.hasPrefix("Ritmo de prova ") && TrainerEngine.describe(workout).hasPrefix("2 × 4 km"))
        #expect(workout.method == .racePace)
        #expect(workout.steps.first { $0.kind == .recovery }?.restSeconds == 90)
        #expect(workout.paceLow == 252 && workout.paceHigh == 258)
    }

    @Test func racePaceGrowsUpToSeventyPercentInOneBlock() {
        func totals(_ meters: Double) -> [Double] {
            let weeks = (1...40).map {
                TrainerWeek(
                    index: $0, start: monday.adding(days: ($0 - 1) * 7), phase: .specific, isRecovery: false, plannedMeters: 50_000,
                    longMeters: 20_000, thresholdFocus: "", vo2Focus: ""
                )
            }
            let goal = target(weeks: 40, meters: meters)
            return weeks.compactMap { TrainerEngine.racePaceSession(week: $0, weeks: weeks, target: goal) }.map(total)
        }
        let half = totals(21_097.5)
        let marathon = totals(42_195)

        #expect(half.first == 8_000)
        #expect(half == half.sorted())
        #expect(half.max() == 15_000)
        #expect(half.last == 15_000)
        #expect(marathon.max() == 20_000)
    }

    @Test func tenKilometerRaceNeverGetsRacePace() {
        let plan = TrainerEngine.create(
            target: target(weeks: 16, meters: 10_000), structure: TrainerEngine.defaultStructure, strength: [], history: history(),
            today: monday, now: now
        )

        #expect(plan.weeks.allSatisfy { TrainerEngine.racePaceSession(week: $0, weeks: plan.weeks, target: plan.target) == nil })
    }

    @Test func workoutsCarryTheMethodAndRationaleCitesIt() throws {
        let plan = create(target(weeks: 12))
        let threshold = try #require(plan.workouts.first { $0.kind == .threshold })
        let vo2 = try #require(plan.workouts.first { $0.kind == .vo2max })

        #expect(threshold.method == .cruiseIntervals)
        #expect(vo2.method == .intervals)
        #expect(plan.workouts.filter { $0.kind == .easy || $0.kind == .off }.allSatisfy { $0.method == nil })
        #expect(TrainerMethod.cruiseIntervals.label == "Cruise intervals (Daniels) com volume de limiar do método norueguês")
        #expect(TrainerMethod.tempo.label == "Tempo run (Daniels)")
        #expect(TrainerMethod.intervals.label == "Intervalado em pace I (Daniels)")
        #expect(TrainerMethod.repetition.label == "Repetições em pace R (Daniels)")
        #expect(TrainerMethod.racePace.label == "Ritmo específico (Canova, Pfitzinger)")
        #expect(TrainerMethod.goalPace.label == "Extensão do ritmo específico (Canova)")
        #expect("\(TrainerMethod.cruiseIntervals.title) (\(TrainerMethod.cruiseIntervals.source))" == "Cruise intervals (Daniels)")
    }

    @Test func oldWorkoutWithoutMethodStillDecodes() throws {
        let workout = TrainerWorkout(
            day: monday, kind: .threshold, title: "Limiar 3 × 2 km", totalMeters: 9_000,
            steps: [TrainerStep(kind: .work, repeats: 3, meters: 2_000)], rationale: "x", method: .tempo
        )
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(workout)) as? [String: Any])
        object["method"] = nil

        let decoded = try JSONDecoder().decode(TrainerWorkout.self, from: JSONSerialization.data(withJSONObject: object))

        #expect(decoded.method == nil)
    }

    private func thursday(_ plan: TrainerPlan, week: Int) throws -> TrainerWorkout {
        try #require(plan.workouts.first { $0.day == monday.adding(days: 7 * (week - 1) + 3) })
    }

    @Test func goalPaceReplacesVo2EveryOtherWeekAndThresholdStays() throws {
        let plan = create(goalTarget)
        let first = try thursday(plan, week: 1)
        let second = try thursday(plan, week: 2)

        #expect(first.kind == .vo2max && first.method == .goalPace)
        #expect(first.title.hasPrefix("Pace-alvo ") && TrainerEngine.describe(first).hasPrefix("4 × 2 km"))
        #expect(first.paceLow == 237 && first.paceHigh == 243)
        #expect(first.steps.first { $0.kind == .recovery }?.restSeconds == 90)
        #expect(second.method == .intervals)
        #expect(plan.workouts.filter { $0.kind == .threshold && $0.day < monday.adding(days: 15) }.allSatisfy { $0.method != .goalPace })
        #expect(first.rationale.contains("Pace-alvo 4 × 2 km a 4:00, 1:30 parado."))
    }

    @Test func goalPaceGrowsOnlyWhenThePreviousClosedOnTarget() throws {
        let plan = create(goalTarget)
        let session = try thursday(plan, week: 1)
        let friday = monday.adding(days: 4)
        func adjusted(onTarget: Int) throws -> TrainerWorkout {
            let done = run(90, session.day, km: session.totalMeters / 1_000, pace: 245, kind: .intervals, onTarget: onTarget, total: 4)
            let result = TrainerEngine.adjust(
                plan, history: history(extra: [done]), today: friday, now: now, trigger: .strengthChanged
            )
            return try thursday(result, week: 3)
        }

        let grown = try adjusted(onTarget: 4)
        #expect(grown.title.hasPrefix("Pace-alvo ") && TrainerEngine.describe(grown).hasPrefix("3 × 3 km"))
        #expect(grown.rationale.contains("Pace-alvo 3 × 3 km a 4:00, 1:30 parado. O anterior fechou no alvo, então o bloco cresce."))
        let repeated = try adjusted(onTarget: 2)
        #expect(repeated.title.hasPrefix("Pace-alvo ") && TrainerEngine.describe(repeated).hasPrefix("4 × 2 km"))
        #expect(repeated.rationale.contains("O anterior não fechou no alvo, então a sessão repete."))
    }

    @Test func goalPaceLadderEndsOnTheTargetDistance() {
        let steps = (0..<14).map { TrainerEngine.goalPaceBlock(step: $0, distance: 21_000) }

        #expect(steps.prefix(8).map { "\($0.repeats)x\(Int($0.meters))" } == [
            "4x2000", "3x3000", "2x5000", "2x6000", "1x8000", "1x10000", "1x12000", "1x15000",
        ])
        #expect(steps[8].meters == 18_000 && steps[9].meters == 21_000)
        #expect(steps[13].meters == 21_000 && steps[13].repeats == 1)
        #expect(TrainerEngine.goalPaceBlock(step: 3, distance: 10_000) == TrainerQualityBlock(repeats: 1, meters: 10_000))
    }

    @Test func goalPaceBlocksStayWithinTwentyPercentOfTheWeek() {
        var week = openWeeks()[0]
        week.targetMeters = 40_000
        let capped = TrainerEngine.goalPaceSession(step: 3, week: week, distance: 21_000)
        #expect(capped.blocks == [TrainerQualityBlock(repeats: 1, meters: 6_000)])

        week.targetMeters = 20_000
        let small = TrainerEngine.goalPaceSession(step: 0, week: week, distance: 21_000)
        #expect(small.blocks == [TrainerQualityBlock(repeats: 2, meters: 2_000)])
    }

    @Test func goalPaceRestDependsOnTheBlock() {
        func rest(_ repeats: Int, _ meters: Double) -> Double {
            let session = TrainerQualitySession(
                kind: .vo2max, method: .goalPace, blocks: [TrainerQualityBlock(repeats: repeats, meters: meters)], closing: false
            )
            return TrainerEngine.restSeconds(session: session, block: session.blocks[0], paces: paces, lowered: false)
        }

        #expect(rest(4, 2_000) == 90)
        #expect(rest(3, 3_000) == 90)
        #expect(rest(2, 5_000) == 120)
        #expect(rest(2, 6_000) == 120)
    }

    @Test func goalPaceLongRunEndsProgressive() throws {
        let plan = create(goalTarget)
        let long = try #require(plan.workouts.first { $0.kind == .long })
        let progressive = long.steps.dropFirst()

        #expect(progressive.count == 3)
        #expect(progressive.allSatisfy { $0.meters == 1_000 })
        let paces = progressive.compactMap { $0.paceLow }
        #expect(paces == paces.sorted(by: >))
        #expect(progressive.last?.paceLow == 255 && progressive.last?.paceHigh == 261)
        #expect(long.rationale.contains("Últimos 3 km progressivos"))
        #expect(abs(long.totalMeters - long.steps.reduce(0) { $0 + Double($1.repeats) * $1.meters }) < 1)
    }

    @Test func goalPaceWarnsWhenTheDeadlineIsTooShort() throws {
        let short = TrainerTarget(
            kind: .paceDistance, name: "meta", date: monday.adding(days: 6 * 7 + 5), distanceMeters: 21_000, goalPace: 240
        )
        let warned = try thursday(create(short), week: 1)
        #expect(warned.rationale.contains("abaixo dos 21 km da meta"))

        let comfortable = TrainerTarget(
            kind: .paceDistance, name: "meta", date: monday.adding(days: 30 * 7 + 5), distanceMeters: 21_000, goalPace: 240
        )
        #expect(!(try thursday(create(comfortable), week: 1)).rationale.contains("abaixo dos"))
    }

    @Test func goalPaceExplainsTheThresholdItAsks() {
        let plan = create(goalTarget)
        let summary = TrainerEngine.goalPaceSummary(target: goalTarget, paces: plan.paces)

        #expect(summary == "Hoje seu limiar é 4:26; 4:00 por 21 km pede ~3:57.")
        #expect(plan.versions.first?.summary.contains("Hoje seu limiar é 4:26; 4:00 por 21 km pede ~3:57.") == true)
        #expect(TrainerEngine.goalPaceSummary(target: target(weeks: 12), paces: plan.paces) == nil)
    }

    @Test func goalPaceTargetsAndPlansStillDecodeFromOldJson() throws {
        let plan = create(target(weeks: 12))
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        object["lightWeeks"] = nil

        let decoded = try JSONDecoder().decode(TrainerPlan.self, from: JSONSerialization.data(withJSONObject: object))

        #expect(decoded.lightWeeks.isEmpty)
        #expect(decoded.target.goalPace == nil)
        let trigger = TrainerTrigger.lightWeek(monday)
        let roundTrip = try JSONDecoder().decode(TrainerTrigger.self, from: JSONEncoder().encode(trigger))
        #expect(roundTrip == trigger)
    }

    @Test func lightWeekShiftsTheAutomaticRecoveryAndExplainsIt() throws {
        let plan = create(target(weeks: 12))
        let day = plan.weeks[5].start
        #expect(plan.weeks.filter(\.isRecovery).map(\.index) == [4, 8])

        let adjusted = TrainerEngine.adjust(plan, history: history(), today: monday, now: now, trigger: .lightWeek(day))

        #expect(adjusted.lightWeeks == [day])
        #expect(adjusted.weeks.filter(\.isRecovery).map(\.index) == [4, 6, 10])
        #expect(adjusted.weeks[5].targetMeters < adjusted.weeks[4].targetMeters)
        let version = try #require(adjusted.versions.last)
        let date = TrainerEngineText.date(day)
        let displaced = TrainerEngineText.date(plan.weeks[7].start)
        #expect(version.trigger == .lightWeek(day))
        #expect(version.summary.contains("Semana de \(date) marcada como leve: \(TrainerEngineText.kilometers(adjusted.weeks[5].targetMeters))."))
        #expect(version.summary.contains("A recuperação de \(displaced) virou semana normal."))
        #expect(version.changes.contains { $0.kind == .skeleton && $0.reason.contains("marcada como leve") })
    }

    @Test func clearingALightWeekRestoresTheCycle() {
        let plan = create(target(weeks: 12))
        let day = plan.weeks[5].start
        let marked = TrainerEngine.adjust(plan, history: history(), today: monday, now: now, trigger: .lightWeek(day))

        let cleared = TrainerEngine.adjust(marked, history: history(), today: monday, now: now, trigger: .lightWeek(day))

        #expect(cleared.lightWeeks.isEmpty)
        #expect(cleared.weeks.map(\.isRecovery) == plan.weeks.map(\.isRecovery))
        #expect(cleared.versions.last?.summary.contains("voltou ao normal") == true)
    }

    @Test func lightWeeksChosenAtCreationApplyFromTheStart() {
        let day = monday.adding(days: 7)
        let plan = TrainerEngine.create(
            target: target(weeks: 12), structure: TrainerEngine.defaultStructure, strength: [], history: history(),
            today: monday, now: now, lightWeeks: [day]
        )

        #expect(plan.lightWeeks == [day])
        #expect(plan.weeks.filter(\.isRecovery).map(\.index) == [2, 6, 10])
    }
}
