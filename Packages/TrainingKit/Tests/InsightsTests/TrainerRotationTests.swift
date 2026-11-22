import Foundation
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import Insights

@Suite struct TrainerRotationTests {
    private let monday = Day(year: 2026, month: 11, day: 9)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func history(readiness: [Day: Int] = [:]) -> TrainerHistory {
        var runs: [TrainerRun] = []
        for week in 1...4 {
            let start = monday.adding(days: -7 * week)
            let base = Int64(week * 10)
            runs.append(TrainerRun(activityId: base + 1, day: start, meters: 10_000, seconds: 3_000, kind: .easy))
            runs.append(TrainerRun(activityId: base + 2, day: start.adding(days: 1), meters: 12_000, seconds: 3_000, kind: .tempo))
            runs.append(TrainerRun(activityId: base + 3, day: start.adding(days: 3), meters: 10_000, seconds: 3_000, kind: .easy))
            runs.append(TrainerRun(activityId: base + 4, day: start.adding(days: 5), meters: 18_000, seconds: 18 * 310, kind: .long))
        }
        return TrainerHistory(runs: runs, readiness: readiness, predictions: [10_000: 2_460, 5_000: 1_170])
    }

    private var halfMarathon: TrainerTarget {
        TrainerTarget(kind: .race, name: "Meia", date: monday.adding(days: 12 * 7 + 5), distanceMeters: 21_097.5, goalSeconds: 5_700)
    }

    private func plan(peak: Double, longMode: TrainerLongMode = .continuous, readiness: [Day: Int] = [:]) -> TrainerPlan {
        TrainerEngine.create(
            target: halfMarathon, structure: TrainerEngine.defaultStructure, strength: [], history: history(readiness: readiness),
            today: monday, now: now, startMeters: (peak * 0.75 / 1_000).rounded() * 1_000, peakMeters: peak, longMode: longMode
        )
    }

    private func days(_ plan: TrainerPlan, _ week: TrainerWeek) -> [TrainerWorkout] {
        plan.workouts.filter { $0.day.weekStart == week.start }
    }

    private func workout(_ plan: TrainerPlan, _ week: TrainerWeek, _ kind: TrainerDayKind) -> TrainerWorkout? {
        days(plan, week).first { $0.kind == kind }
    }

    private func format(_ workout: TrainerWorkout?) -> String {
        guard let workout else { return "" }
        let blocks = workout.steps.filter { $0.kind == .work && $0.method != .repetition }.map { String(Int($0.meters)) }
        return "\(workout.variant?.rawValue ?? "")|\(workout.method?.rawValue ?? "")|\(Set(blocks).sorted())"
    }

    private func comparable(_ plan: TrainerPlan) -> [TrainerWeek] {
        plan.weeks.filter { $0.phase != .taper }
    }

    @Test(arguments: [80_000.0, 70_000.0])
    func qualityFormatsDoNotRepeatInConsecutiveWeeks(peak: Double) {
        let plan = plan(peak: peak)
        let weeks = comparable(plan)
        for (first, second) in zip(weeks, weeks.dropFirst()) {
            #expect(format(workout(plan, first, .threshold)) != format(workout(plan, second, .threshold)))
            #expect(format(workout(plan, first, .vo2max)) != format(workout(plan, second, .vo2max)))
            let firstLong = workout(plan, first, .long)?.variant
            let secondLong = workout(plan, second, .long)?.variant
            if firstLong != nil { #expect(firstLong != secondLong) }
        }
        let thresholds = Set(weeks.compactMap { workout(plan, $0, .threshold)?.variant })
        #expect(thresholds.isSuperset(of: [.continuousTempo, .progressiveThreshold]))
        let vo2 = weeks.compactMap { workout(plan, $0, .vo2max) }
        #expect(vo2.contains { $0.variant == .hills })
        #expect(vo2.contains { $0.title.hasPrefix("VO2 ") && TrainerEngine.describe($0).hasPrefix("6 × 800 m") })
        #expect(vo2.filter { $0.variant == .hills }.allSatisfy { workout in
            plan.weeks.first { $0.start == workout.day.weekStart }?.phase == .base
        })
    }

    @Test func longRunsWaveBetweenEighteenAndTwentyFourAndTheLongestIsEasy() throws {
        let plan = plan(peak: 80_000)
        let progression = plan.weeks.filter { !$0.isRecovery && $0.phase != .taper }
        let longs = try progression.map { try #require(workout(plan, $0, .long)) }

        #expect(longs.allSatisfy { (18_000...24_000).contains($0.totalMeters) })
        #expect(longs.map(\.totalMeters).max() == 24_000)
        #expect(longs.filter { $0.variant != nil }.allSatisfy { $0.totalMeters <= 20_000 })
        #expect(Set(longs.compactMap(\.variant)) == [.progressiveLong, .fastFinish, .racePaceLong])
        var block: [TrainerWorkout] = []
        for (index, week) in plan.weeks.enumerated() {
            if let long = workout(plan, week, .long), progression.contains(week) { block.append(long) }
            let closes = index == plan.weeks.count - 1 || !progression.contains(plan.weeks[index + 1]) || block.count == 3
            guard closes, !block.isEmpty else { continue }
            let longest = try #require(block.max { $0.totalMeters < $1.totalMeters })
            #expect(longest.variant == nil)
            #expect(block.filter { $0.totalMeters == longest.totalMeters }.count == 1)
            #expect(longest.steps.allSatisfy { $0.kind == .steady && $0.paceLow == longest.paceLow })
            #expect(longest.rationale.hasPrefix("Maior longão do bloco"))
            block = []
        }
        for week in plan.weeks where week.isRecovery {
            let long = try #require(workout(plan, week, .long))
            #expect(long.variant == nil && long.totalMeters <= 17_000)
        }
        let racePace = try #require(longs.first { $0.variant == .racePaceLong })
        #expect(racePace.title == "Longão 19 km" && racePace.variant == .racePaceLong)
        #expect(racePace.steps.contains { $0.kind == .work && $0.repeats == 3 && $0.meters == 3_000 && $0.method == .racePace })
    }

    @Test(arguments: [80_000.0, 70_000.0])
    func longRunCapsAndOrderStillHold(peak: Double) throws {
        let plan = plan(peak: peak)
        for week in plan.weeks {
            let items = days(plan, week)
            guard let long = items.first(where: { $0.kind == .long }) else { continue }
            let share = long.rationale.hasPrefix("Maior longão") ? 0.35 : 0.30
            #expect(long.totalMeters <= max(TrainerEngine.floorKilometers(week.targetMeters * share), 10_000))
            #expect(long.totalMeters / 1_000 * plan.paces.long <= 150 * 60)
            #expect(items.filter { $0.id != long.id }.allSatisfy { $0.totalMeters < long.totalMeters })
        }
    }

    @Test(arguments: [80_000.0, 70_000.0])
    func longRunsFromSixtyKilometersStayBetweenEighteenAndTwentyFour(peak: Double) throws {
        let plan = plan(peak: peak)
        let weeks = plan.weeks.filter { !$0.isRecovery && $0.phase != .taper && $0.targetMeters >= 60_000 }
        #expect(!weeks.isEmpty)
        for week in weeks {
            let long = try #require(workout(plan, week, .long))
            #expect((18_000...24_000).contains(long.totalMeters))
        }
    }

    @Test(arguments: [80_000.0, 70_000.0])
    func mediumLongOnlyFromSixtyFiveKilometers(peak: Double) {
        let plan = plan(peak: peak)
        let limit = TrainerEngine.easyLimit(paces: plan.paces)
        var found = 0
        for week in plan.weeks {
            for item in days(plan, week) where item.variant == .mediumLong {
                found += 1
                #expect(week.targetMeters >= 65_000)
                #expect(!week.isRecovery && week.phase != .taper)
                #expect(TrainerEngine.weekdayNumber(item.day) == 3)
                #expect((14_000...16_000).contains(item.totalMeters) && item.totalMeters <= limit)
                #expect(item.title == "Média-longa \(Int(item.totalMeters / 1_000)) km")
            }
        }
        if peak >= 80_000 { #expect(found >= 3) }
        #expect(plan.weeks.filter { $0.targetMeters < 65_000 }.allSatisfy { week in !days(plan, week).contains { $0.variant == .mediumLong } })
    }

    @Test func stridesOnTheFirstEasyRunOutsideLightAndRaceWeeks() throws {
        let plan = plan(peak: 80_000)
        for week in plan.weeks {
            let monday = try #require(days(plan, week).first)
            let raceWeek = halfMarathon.date?.weekStart == week.start
            if week.isRecovery || raceWeek {
                #expect(monday.variant == nil)
            } else {
                #expect(monday.variant == .strides)
                #expect(monday.variant == .strides && monday.title.hasPrefix("Rodagem "))
                #expect(monday.totalMeters.truncatingRemainder(dividingBy: 1_000) == 0)
                let strides = try #require(monday.steps.first { $0.kind == .work })
                #expect(strides.repeats == 6 && strides.meters == 100)
                #expect(monday.steps.first { $0.kind == .recovery }?.restSeconds == 60)
            }
            #expect(days(plan, week).filter { $0.variant == .strides }.count <= 1)
        }
    }

    @Test(arguments: [80_000.0, 70_000.0])
    func weeklyKilometersFollowTheTarget(peak: Double) {
        let plan = plan(peak: peak)
        let minimum = TrainerEngine.easyMinimum(paces: plan.paces)
        for week in plan.weeks where week.phase != .taper {
            let items = days(plan, week)
            let total = items.reduce(0) { $0 + $1.totalMeters }
            let flexible = items.filter { ($0.kind == .easy && $0.variant != .mediumLong) || ($0.kind == .optionalEasy && $0.variant == nil) }
            #expect(abs(total - week.plannedMeters) < 1)
            if flexible.contains(where: { $0.totalMeters > minimum }) {
                #expect(abs(total - week.targetMeters) <= 1_000)
            } else {
                #expect(total >= week.targetMeters - 1_000)
            }
        }
    }

    @Test(arguments: [80_000.0, 70_000.0])
    func limitsStillHold(peak: Double) {
        let plan = plan(peak: peak)
        let easyMinimum = TrainerEngine.easyMinimum(paces: plan.paces)
        let easyLimit = TrainerEngine.easyLimit(paces: plan.paces)
        for week in plan.weeks {
            for item in days(plan, week) {
                let work = item.steps.filter { $0.kind == .work && $0.method != .repetition }
                let meters = work.reduce(0) { $0 + Double($1.repeats) * $1.meters }
                #expect(!item.steps.contains { $0.kind == .cooldown })
                #expect(abs(item.totalMeters - item.steps.reduce(0) { $0 + Double($1.repeats) * $1.meters }) < 1)
                switch item.kind {
                case .threshold where item.method != .racePace:
                    #expect(meters <= week.targetMeters * 0.17 + 1)
                    #expect(item.steps.first == TrainerStep(kind: .warmup, meters: 3_000, paceLow: item.steps.first?.paceLow, paceHigh: item.steps.first?.paceHigh))
                    if item.method == .cruiseIntervals && week.phase != .taper { #expect(work.reduce(0) { $0 + $1.repeats } >= 2) }
                case .vo2max where item.method == .intervals:
                    #expect(meters <= min(week.targetMeters * 0.08, 10_000) + 1)
                    #expect(work.reduce(0) { $0 + $1.repeats } >= 2)
                    #expect(item.steps.first?.kind == .warmup && item.steps.first?.meters == 3_000)
                case .easy, .optionalEasy:
                    #expect(item.totalMeters.truncatingRemainder(dividingBy: 1_000) == 0)
                    if halfMarathon.date?.weekStart != week.start {
                        #expect(item.totalMeters >= easyMinimum)
                        if item.variant != .fartlek { #expect(item.totalMeters <= easyLimit) }
                    }
                    if item.variant == .fartlek {
                        #expect(item.steps.first?.kind == .warmup && (item.steps.first?.meters ?? 0) >= 3_000)
                        #expect(item.steps.contains { $0.kind == .work && $0.repeats == 6 && $0.meters == 500 })
                        #expect(item.steps.contains { $0.kind == .recovery && $0.meters == 500 && $0.restSeconds == nil })
                    }
                case .long:
                    #expect(item.totalMeters.truncatingRemainder(dividingBy: 1_000) == 0)
                default:
                    break
                }
            }
        }
    }

    @Test func fartlekEveryOtherWeekFallsBackToAnEasyRunWithLowReadiness() throws {
        let plain = plan(peak: 80_000)
        let fartleks = plain.workouts.filter { $0.variant == .fartlek }
        let first = try #require(fartleks.first)

        #expect(fartleks.count >= 3)
        #expect(first.kind == .optionalEasy && first.variant == .fartlek && first.title.hasPrefix("Fartlek "))
        #expect(first.note == "só se a prontidão ≥ 60; senão rodagem leve de \(Int(first.totalMeters / 1_000)) km")
        for item in fartleks {
            let week = try #require(plain.weeks.first { $0.start == item.day.weekStart })
            #expect(!week.isRecovery && week.phase != .taper)
            let previous = plain.workouts.first { $0.day == item.day.adding(days: -7) }
            #expect(previous?.variant != .fartlek)
        }

        let tired = plan(peak: 80_000, readiness: [first.day: 45])
        let easy = try #require(tired.workouts.first { $0.day == first.day })
        #expect(easy.kind == .optionalEasy && easy.variant == nil)
        #expect(easy.totalMeters == first.totalMeters)
        #expect(easy.rationale.hasPrefix("Prontidão 45 hoje"))
        let ready = plan(peak: 80_000, readiness: [first.day: 75])
        #expect(ready.workouts.first { $0.day == first.day }?.variant == .fartlek)
    }

    @Test func blocksModeKeepsTheLongWithoutRotation() {
        let plan = plan(peak: 80_000, longMode: .blocks)
        let longs = plan.workouts.filter { $0.kind == .long }

        #expect(plan.weeks.allSatisfy { $0.baseLongMeters == nil })
        #expect(longs.allSatisfy { $0.variant == nil })
        #expect(plan.workouts.contains { $0.variant == .strides })
    }

    @Test func rationalesExplainTheFormat() throws {
        let plan = plan(peak: 80_000)
        let tempo = try #require(plan.workouts.first { $0.variant == .continuousTempo })
        let progressive = try #require(plan.workouts.first { $0.variant == .progressiveThreshold })
        let hills = try #require(plan.workouts.first { $0.variant == .hills })
        let medium = try #require(plan.workouts.first { $0.variant == .mediumLong })

        #expect(tempo.title.hasPrefix("Tempo "))
        #expect(tempo.rationale.contains("segura o limiar sem pausa"))
        #expect(progressive.title.hasPrefix("Limiar progressivo ") && progressive.steps.filter { $0.kind == .work && $0.meters == 2_000 }.count == 3)
        #expect(progressive.rationale.contains("5 s/km mais rápido"))
        let paces = progressive.steps.filter { $0.kind == .work }.compactMap(\.paceLow)
        #expect(paces == paces.sorted(by: >) && Set(paces).count == 3)
        #expect(hills.rationale.contains("Subidas na fase base"))
        #expect(medium.rationale.contains("Média-longa"))
        #expect(plan.workouts.filter { $0.variant == .strides }.allSatisfy { $0.rationale.contains("6 × 100 m de aceleração") })
    }

    @Test func recalculatingAfterAGoodWeekKeepsTheRotation() {
        let created = plan(peak: 80_000)
        let nextMonday = monday.adding(days: 7)
        let adjusted = TrainerEngine.adjust(created, history: history(), today: nextMonday, now: now, trigger: .weekEnded(1))

        #expect(adjusted.weeks == created.weeks)
        #expect(adjusted.workouts.filter { $0.day >= nextMonday } == created.workouts.filter { $0.day >= nextMonday })
    }

    @Test func oldPlanJsonDecodesWithoutVariantOrBaseLong() throws {
        let workout = #"{"day":"2026-11-09","kind":"easy","title":"Rodagem 8 km","totalMeters":8000,"steps":[],"rationale":"x"}"#
        let decoded = try JSONDecoder().decode(TrainerWorkout.self, from: Data(workout.utf8))
        #expect(decoded.variant == nil)
        let unknown = #"{"day":"2026-11-09","kind":"easy","title":"x","totalMeters":8000,"steps":[],"rationale":"x","variant":"novo"}"#
        #expect(try JSONDecoder().decode(TrainerWorkout.self, from: Data(unknown.utf8)).variant == nil)
        let week = #"{"index":1,"start":"2026-11-09","phase":"base","isRecovery":false,"plannedMeters":60000,"longMeters":18000,"thresholdFocus":"Blocos de 1 km","vo2Focus":"5 × 1 km"}"#
        #expect(try JSONDecoder().decode(TrainerWeek.self, from: Data(week.utf8)).baseLongMeters == nil)

        let plan = plan(peak: 80_000)
        let data = try JSONEncoder().encode(plan)
        #expect(try JSONDecoder().decode(TrainerPlan.self, from: data) == plan)
        let plain = try #require(plan.workouts.first { $0.variant == nil && $0.kind == .threshold })
        let encoded = try #require(String(data: try JSONEncoder().encode(plain), encoding: .utf8))
        #expect(!encoded.contains("variant"))
    }
}
