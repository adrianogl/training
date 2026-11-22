import Foundation
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import Insights

@Suite struct TrainerEditTests {
    private let monday = Day(year: 2026, month: 11, day: 9)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var secondMonday: Day { monday.adding(days: 7) }

    private var target: TrainerTarget {
        TrainerTarget(kind: .race, name: "Meia maratona", date: monday.adding(days: 12 * 7 + 5), distanceMeters: 21_097.5, goalSeconds: 5_700)
    }

    private func run(_ id: Int64, _ day: Day, km: Double, pace: Double, kind: RunKind) -> TrainerRun {
        TrainerRun(activityId: id, day: day, meters: km * 1_000, seconds: km * pace, kind: kind)
    }

    private var history: TrainerHistory {
        var runs: [TrainerRun] = []
        for week in 1...4 {
            let start = monday.adding(days: -7 * week)
            let base = Int64(week * 10)
            runs.append(run(base + 1, start, km: 8, pace: 340, kind: .easy))
            runs.append(run(base + 2, start.adding(days: 1), km: 10, pace: 262, kind: .tempo))
            runs.append(run(base + 3, start.adding(days: 2), km: 8, pace: 340, kind: .easy))
            runs.append(run(base + 4, start.adding(days: 5), km: Double(18 - week), pace: 335, kind: .long))
        }
        return TrainerHistory(runs: runs, predictions: [10_000: 2_580, 5_000: 1_230])
    }

    private func createPlan() -> TrainerPlan {
        TrainerEngine.create(
            target: target, structure: TrainerEngine.defaultStructure, strength: [], history: history, today: monday, now: now
        )
    }

    private func firstWorkout(_ plan: TrainerPlan, _ kind: TrainerDayKind, from day: Day) throws -> TrainerWorkout {
        try #require(plan.workouts.filter { $0.kind == kind && $0.day >= day }.sorted { $0.day < $1.day }.first)
    }

    private func editedThreshold(_ plan: TrainerPlan, from day: Day) throws -> TrainerWorkout {
        let workout = try firstWorkout(plan, .threshold, from: day)
        var draft = try #require(TrainerEngine.draft(of: workout))
        draft.repeats += 1
        return TrainerEngine.applying(draft, to: workout)
    }

    @Test func manualPaceOverridesApplyAndRemove() throws {
        let plan = createPlan()
        let baseline = plan.paces.threshold
        let edit = TrainerEdit(paceOverrides: [.threshold: baseline - 6])

        let manual = TrainerEngine.adjust(plan, history: history, today: secondMonday, now: now, trigger: .edited(edit))

        #expect(manual.paces.threshold == baseline - 6)
        #expect(manual.paces.thresholdSource == .manual)
        #expect(manual.paceOverrides[.threshold] == baseline - 6)
        let threshold = try firstWorkout(manual, .threshold, from: secondMonday)
        #expect(threshold.rationale.contains("Pace definido por você."))
        #expect(manual.versions.count == plan.versions.count + 1)

        let cleared = TrainerEngine.adjust(
            manual, history: history, today: secondMonday, now: now, trigger: .edited(TrainerEdit(paceOverrides: [:]))
        )

        #expect(cleared.paceOverrides.isEmpty)
        #expect(cleared.paces.threshold == baseline)
        #expect(cleared.paces.thresholdSource != .manual)
    }

    @Test func manualPaceSurvivesAutomaticAdjust() {
        let plan = createPlan()
        let manual = TrainerEngine.adjust(
            plan, history: history, today: secondMonday, now: now, trigger: .edited(TrainerEdit(paceOverrides: [.easy: 350]))
        )

        let next = TrainerEngine.adjust(manual, history: history, today: secondMonday, now: now, trigger: .weekEnded(1))

        #expect(next.paces.easy == 350)
    }

    @Test func planEditCreatesVersionAndKeepsPast() throws {
        let plan = createPlan()
        let today = monday.adding(days: 9)
        var structure = plan.structure
        structure[3] = .threshold
        let edit = TrainerEdit(structure: structure)

        let edited = TrainerEngine.adjust(plan, history: history, today: today, now: now, trigger: .edited(edit))

        #expect(edited.workouts.filter { $0.day < today } == plan.workouts.filter { $0.day < today })
        #expect(edited.structure[3] == .threshold)
        let version = try #require(edited.versions.last)
        #expect(version.trigger == .edited(edit))
        #expect(version.number == plan.versions.count + 1)
        #expect(version.summary.contains("estrutura"))
        #expect(version.changes.contains { $0.kind != .unchanged })
    }

    @Test func planEditWithoutChangesReturnsSamePlan() {
        let plan = createPlan()

        let result = TrainerEngine.adjust(plan, history: history, today: secondMonday, now: now, trigger: .edited(TrainerEdit()))

        #expect(result == plan)
    }

    @Test func planEditKeepsDoneWorkout() throws {
        let plan = createPlan()
        let today = monday.adding(days: 9)
        let done = run(900, today, km: 8, pace: 340, kind: .easy)
        let withRun = TrainerHistory(runs: history.runs + [done], predictions: history.predictions)
        var structure = plan.structure
        structure[today.weekStart.days(until: today) + 1] = .vo2max
        let before = try #require(plan.workouts.first { $0.day == today })

        let edited = TrainerEngine.adjust(
            plan, history: withRun, today: today, now: now, trigger: .edited(TrainerEdit(structure: structure))
        )

        #expect(edited.workouts.first { $0.day == today } == before)
    }

    @Test func previewListsChangesWithoutMutatingPlan() {
        let plan = createPlan()
        var structure = plan.structure
        structure[3] = .threshold
        let edit = TrainerEdit(structure: structure, paceOverrides: [.threshold: plan.paces.threshold - 8])

        let changes = TrainerEngine.previewEdit(plan, edit: edit, history: history, today: secondMonday, now: now)

        #expect(!changes.isEmpty)
        #expect(changes.contains { $0.title == "Pace do limiar" })
        #expect(plan.structure[3] != .threshold)
    }

    @Test func makeEditKeepsOnlyChangedFields() {
        let plan = createPlan()
        let volumes = TrainerEngine.volumes(of: plan, history: history, today: secondMonday)

        let untouched = TrainerEngine.makeEdit(
            for: plan, target: plan.target, startMeters: volumes.start, peakMeters: volumes.peak, structure: plan.structure,
            strength: plan.strength, longMode: plan.longMode, paceOverrides: plan.paceOverrides, history: history, today: secondMonday
        )
        let changed = TrainerEngine.makeEdit(
            for: plan, target: plan.target, startMeters: volumes.start + 5_000, peakMeters: volumes.peak + 5_000,
            structure: plan.structure, strength: plan.strength, longMode: .blocks, paceOverrides: [.easy: 330],
            history: history, today: secondMonday
        )

        #expect(untouched == TrainerEdit())
        #expect(changed.startMeters == volumes.start + 5_000)
        #expect(changed.longMode == .blocks)
        #expect(changed.paceOverrides == [.easy: 330])
        #expect(changed.structure == nil)
    }

    @Test func editedWorkoutSurvivesWeekEndedAndWorkoutTriggers() throws {
        let plan = createPlan()
        let edited = try editedThreshold(plan, from: secondMonday.adding(days: 1))
        let saved = TrainerEngine.editWorkout(plan, edited, now: now)

        let weekly = TrainerEngine.adjust(saved, history: history, today: secondMonday, now: now, trigger: .weekEnded(1))
        let single = TrainerEngine.adjust(
            saved, history: history, today: secondMonday, now: now, trigger: .workout(activityId: 777, day: monday.adding(days: 5))
        )

        for result in [weekly, single] {
            let kept = try #require(result.workouts.first { $0.day == edited.day })
            #expect(kept == saved.workouts.first { $0.day == edited.day })
            #expect(kept.edited)
            let changes = result.versions.last?.changes ?? []
            #expect(!changes.contains { $0.day == edited.day })
        }
    }

    @Test func explicitRequestKeepsEditedWorkoutAndWarns() throws {
        let plan = createPlan()
        let edited = try editedThreshold(plan, from: secondMonday.adding(days: 1))
        let saved = TrainerEngine.editWorkout(plan, edited, now: now)
        let request = TrainerRequest(category: .pain, text: "dor na panturrilha", from: edited.day, until: edited.day.adding(days: 2))

        let result = TrainerEngine.adjust(saved, history: history, today: secondMonday, now: now, trigger: .request(request))

        #expect(result.workouts.first { $0.day == edited.day } == saved.workouts.first { $0.day == edited.day })
        let notice = result.versions.last?.changes.first { $0.day == edited.day }
        #expect(notice?.kind == .unchanged)
        #expect(notice?.reason == "Seu treino editado foi mantido.")
    }

    @Test func workoutEditCreatesChangedVersion() throws {
        let plan = createPlan()
        let edited = try editedThreshold(plan, from: secondMonday)
        let original = try #require(plan.workouts.first { $0.day == edited.day })

        let saved = TrainerEngine.editWorkout(plan, edited, now: now)

        let version = try #require(saved.versions.last)
        let change = try #require(version.changes.first)
        #expect(version.trigger == .edited(TrainerEdit(days: [edited.day])))
        #expect(change.kind == .changed)
        #expect(change.reason == "Treino editado por você.")
        #expect(change.before != change.after)
        #expect(saved.workouts.first { $0.day == edited.day }?.edited == true)
        #expect(edited.totalMeters > original.totalMeters)
    }

    @Test func qualityDraftRecalculatesTotal() throws {
        let plan = createPlan()
        let workout = try firstWorkout(plan, .threshold, from: secondMonday)
        var draft = try #require(TrainerEngine.draft(of: workout))

        draft.repeats = 4
        draft.blockMeters = 2_000
        draft.pace = 242
        draft.restSeconds = 120
        let edited = TrainerEngine.applying(draft, to: workout)

        let work = try #require(edited.steps.first { $0.kind == .work })
        #expect(work.repeats == 4)
        #expect(work.meters == 2_000)
        #expect(work.paceLow == 239)
        #expect(work.paceHigh == 245)
        #expect(edited.steps.first { $0.restSeconds != nil }?.restSeconds == 120)
        #expect(edited.totalMeters == 3_000 + 8_000)
        #expect(TrainerEngine.describe(edited).hasPrefix("4 × 2 km"))
        #expect(edited.edited)
    }

    @Test func blockStepsUseTwoHundredMetersBelowOneKilometer() {
        #expect(TrainerEngine.nextBlockMeters(800, up: true) == 1_000)
        #expect(TrainerEngine.nextBlockMeters(1_000, up: true) == 1_500)
        #expect(TrainerEngine.nextBlockMeters(1_000, up: false) == 800)
        #expect(TrainerEngine.nextBlockMeters(1_500, up: false) == 1_000)
        #expect(TrainerEngine.nextBlockMeters(200, up: false) == 200)
    }

    @Test func easyDraftChangesDistanceAndPace() throws {
        let plan = createPlan()
        let workout = try firstWorkout(plan, .easy, from: secondMonday)
        var draft = try #require(TrainerEngine.draft(of: workout))

        draft.totalMeters += 1_500
        draft.pace += 10
        let edited = TrainerEngine.applying(draft, to: workout)

        #expect(edited.totalMeters == workout.totalMeters + 1_500)
        #expect(edited.paceLow == (workout.paceLow ?? 0) + 10)
        #expect(edited.title == TrainerEngineText.title(kind: .easy, meters: edited.totalMeters, variant: workout.variant))
        #expect(edited.variant == workout.variant)
    }

    @Test func longInBlocksKeepsStageAndChangesDistance() throws {
        var plan = createPlan()
        plan = TrainerEngine.adjust(plan, history: history, today: secondMonday, now: now, trigger: .longModeChanged)
        let workout = try firstWorkout(plan, .long, from: secondMonday)
        let pauses = TrainerEngine.plannedPauses(of: workout)
        try #require(pauses > 0)
        var draft = try #require(TrainerEngine.draft(of: workout))

        draft.totalMeters += 2_000
        let edited = TrainerEngine.applying(draft, to: workout)

        #expect(TrainerEngine.plannedPauses(of: edited) == pauses)
        #expect(edited.totalMeters == workout.totalMeters + 2_000)
    }

    @Test func swapExchangesTwoWorkoutsAndMarksBothEdited() throws {
        let plan = createPlan()
        let first = secondMonday.adding(days: 1)
        let second = secondMonday.adding(days: 3)
        let a = try #require(plan.workouts.first { $0.day == first })
        let b = try #require(plan.workouts.first { $0.day == second })

        let swapped = TrainerEngine.swapWorkouts(plan, first, second, now: now)

        let newFirst = try #require(swapped.workouts.first { $0.day == first })
        let newSecond = try #require(swapped.workouts.first { $0.day == second })
        #expect(newFirst.title == b.title)
        #expect(newSecond.title == a.title)
        #expect(newFirst.edited && newSecond.edited)
        #expect(swapped.versions.last?.changes.count == 2)
        #expect(swapped.versions.last?.changes.allSatisfy { $0.kind == .changed } == true)
    }

    @Test func swapIgnoresDaysFromDifferentWeeks() {
        let plan = createPlan()

        let result = TrainerEngine.swapWorkouts(plan, secondMonday, secondMonday.adding(days: 8), now: now)

        #expect(result == plan)
    }

    @Test func revertRestoresSuggestion() throws {
        let plan = createPlan()
        let original = try firstWorkout(plan, .threshold, from: secondMonday)
        let edited = try editedThreshold(plan, from: secondMonday)
        let saved = TrainerEngine.editWorkout(plan, edited, now: now)

        let reverted = TrainerEngine.revertWorkout(saved, day: original.day, history: history, today: secondMonday, now: now)

        let restored = try #require(reverted.workouts.first { $0.day == original.day })
        #expect(!restored.edited)
        #expect(restored.steps == original.steps)
        #expect(restored.totalMeters == original.totalMeters)
        #expect(reverted.versions.last?.changes.first?.reason == "Você voltou à sugestão do treinador.")
    }

    @Test func oldJsonDecodesWithoutEditFields() throws {
        let plan = createPlan()
        let data = try JSONEncoder().encode(plan)
        let text = try #require(String(data: data, encoding: .utf8))

        let decoded = try JSONDecoder().decode(TrainerPlan.self, from: data)

        #expect(!text.contains("paceOverrides"))
        #expect(!text.contains("\"edited\""))
        #expect(decoded.paceOverrides.isEmpty)
        #expect(decoded.workouts.allSatisfy { !$0.edited })
        #expect(decoded == plan)
    }

    @Test func editFieldsRoundTrip() throws {
        var plan = createPlan()
        plan.paceOverrides = [.threshold: 250, .race: 240]
        plan.workouts[0].edited = true

        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(TrainerPlan.self, from: data)

        #expect(decoded.paceOverrides == [.threshold: 250, .race: 240])
        #expect(decoded.workouts[0].edited)
        #expect(decoded == plan)
    }

    @Test func editTextsReadNaturally() {
        #expect(TrainerEngineText.editedPlanSummary(["meta", "paces"]) == "Plano editado por você: meta, paces.")
        #expect(TrainerEngineText.manualPaceBasis == "Pace definido por você.")
        #expect(TrainerEngineText.editedPaceReason(manual: false) == "Você voltou ao pace do histórico.")
        #expect(TrainerEngineText.editedSwapSummary(secondMonday, secondMonday.adding(days: 2)).contains("trocados por você"))
    }
}
