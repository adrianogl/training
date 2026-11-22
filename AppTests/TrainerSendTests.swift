import Foundation
import GarminAPI
import Insights
import Testing
import TrainingCore
@testable import trAIning

@Suite struct TrainerSendTests {
    private let day = Day(iso: "2026-11-18")!

    private func threshold() -> TrainerWorkout {
        TrainerWorkout(day: day, kind: .threshold, title: "Limiar 8 × 1 km", totalMeters: 11_000, steps: [
            TrainerStep(kind: .warmup, meters: 3_000),
            TrainerStep(kind: .work, repeats: 8, meters: 1_000, restSeconds: 120, paceLow: 240, paceHigh: 248),
        ], rationale: "")
    }

    @Test func runStepsKeepWarmupRepeatsAndStandingRest() {
        let steps = TrainerSendBuilder.runSteps(threshold())
        #expect(steps == [
            .warmup(meters: 3_000),
            .repeated(times: 7, steps: [.interval(meters: 1_000, fastest: 240, slowest: 248), .rest(seconds: 120)]),
            .interval(meters: 1_000, fastest: 240, slowest: 248),
        ])
    }

    @Test func heartRateTargetGoesOnWarmupAndLongBlocksOnly() {
        let workout = TrainerWorkout(day: day, kind: .threshold, title: "Limiar 12 km", totalMeters: 12_000, steps: [
            TrainerStep(kind: .warmup, meters: 4_000),
            TrainerStep(kind: .work, repeats: 4, meters: 2_000, restSeconds: 120, paceLow: 243, paceHigh: 249),
        ], rationale: "")
        let short = threshold()

        let steps = TrainerSendBuilder.runSteps(workout, thresholdHeartRate: 172)
        let shortSteps = TrainerSendBuilder.runSteps(short, thresholdHeartRate: 172)

        #expect(steps.first == .warmup(meters: 4_000, heartRate: 146...154))
        #expect(steps.last == .interval(meters: 2_000, fastest: 243, slowest: 249, heartRate: 163...171))
        #expect(shortSteps.last == .interval(meters: 1_000, fastest: 240, slowest: 248))
        #expect(ZoneText.label(4, band: TrainerZones.bands(thresholdHeartRate: 172, paces: nil)[3]) == "Z4 · 163–171")
    }

    @Test func standingRestGoesAsTimedRestInsideTheSeries() {
        let workout = TrainerWorkout(day: day, kind: .vo2max, title: "VO2", totalMeters: 10_000, steps: [
            TrainerStep(kind: .warmup, meters: 3_000),
            TrainerStep(kind: .work, repeats: 2, meters: 1_000, paceLow: 230, paceHigh: 236),
            TrainerStep(kind: .recovery, meters: 0, restSeconds: 150),
            TrainerStep(kind: .recovery, meters: 0, restSeconds: 150),
            TrainerStep(kind: .work, repeats: 3, meters: 1_000, paceLow: 230, paceHigh: 236),
            TrainerStep(kind: .recovery, repeats: 2, meters: 0, restSeconds: 150),
            TrainerStep(kind: .work, repeats: 6, meters: 100, paceLow: 200, paceHigh: 206),
            TrainerStep(kind: .recovery, repeats: 5, meters: 100),
            TrainerStep(kind: .cooldown, meters: 1_000),
        ], rationale: "")
        let rep = PlannedRunStep.interval(meters: 1_000, fastest: 230, slowest: 236)
        let stride = PlannedRunStep.interval(meters: 100, fastest: 200, slowest: 206)
        #expect(TrainerSendBuilder.runSteps(workout) == [
            .warmup(meters: 3_000),
            rep, .rest(seconds: 150), rep,
            .rest(seconds: 150),
            .repeated(times: 2, steps: [rep, .rest(seconds: 150)]), rep,
            .repeated(times: 5, steps: [stride, .recovery(meters: 100)]), stride,
            .cooldown(meters: 1_000),
        ])
        #expect(!TrainerSendBuilder.runSteps(workout).description.contains("recovery(meters: 0.0)"))
    }

    @Test func garminNameIsTheWorkoutTitleWithoutPrefix() throws {
        let item = try #require(TrainerSendBuilder.runItem(threshold()))
        let body = try #require(try JSONSerialization.jsonObject(with: item.payload) as? [String: Any])
        #expect(body["workoutName"] as? String == "Limiar 8 × 1 km")
    }

    @Test func easyRunWithoutStepsIsOneInterval() {
        let easy = TrainerWorkout(day: day, kind: .easy, title: "Rodagem 10 km", totalMeters: 10_000, steps: [], paceLow: 295, paceHigh: 310, rationale: "")
        #expect(TrainerSendBuilder.runSteps(easy) == [.interval(meters: 10_000, fastest: 295, slowest: 310)])
    }

    @Test func strengthExercisesCarryGarminKeysAndSides() {
        let exercise = GeneratedExercise(exerciseId: "bulgaro-halteres", name: "Agachamento búlgaro", category: "LUNGE", exerciseName: "DUMBBELL_BULGARIAN_SPLIT_SQUAT", sets: 3, reps: 8, seconds: nil, restSeconds: 60, weight: 12, perSide: true)
        let mapped = TrainerSendBuilder.strengthExercises([exercise])
        #expect(mapped == [PlannedStrengthExercise(description: "Agachamento búlgaro - cada lado", category: "LUNGE", exerciseName: "DUMBBELL_BULGARIAN_SPLIT_SQUAT", sets: 3, reps: 8, seconds: nil, restSeconds: 60, weight: 12)])
    }

    @Test func deletingThePlanTakesFutureRunsAndTrainerStrengthOnly() {
        let records = [
            "run|2026-11-17": TrainerSentRecord(workoutId: 1, signature: "a", day: "2026-11-17", kind: .run),
            "run|2026-11-19": TrainerSentRecord(workoutId: 2, signature: "a", day: "2026-11-19", kind: .run),
            "strength|2026-11-20|x": TrainerSentRecord(workoutId: 3, signature: "a", day: "2026-11-20", kind: .strength),
            "mfit|2026-11-21|9": TrainerSentRecord(workoutId: 4, signature: "a", day: "2026-11-21", kind: .strength),
        ]
        let taken = TrainerSendBuilder.planRecords(records, from: day)
        #expect(taken.map(\.record.workoutId) == [2, 3])
    }

    @Test func labelsTheWholePlanAndTheMFITEnd() {
        let end = Day(iso: "2027-02-14")!
        #expect(TrainerSendText.windowLabel(planEnd: end, mfitEnd: nil) == "Plano até 14 fev")
        #expect(TrainerSendText.windowLabel(planEnd: end, mfitEnd: Day(iso: "2026-12-18")!) == "Plano até 14 fev e MFIT até 18 dez")
        #expect(TrainerSendText.windowLabel(planEnd: nil, mfitEnd: nil) == "Próximos 7 dias")
    }

    @Test func statusComparesSignatures() {
        let item = TrainerSendItem(key: "run|2026-11-18", day: day, kind: .run, title: "Limiar", payload: Data("a".utf8))
        #expect(TrainerSendBuilder.status(item, records: [:]) == .new)
        #expect(TrainerSendBuilder.status(item, records: [item.key: TrainerSentRecord(workoutId: 1, signature: item.signature, day: day.iso, kind: .run)]) == .current)
        #expect(TrainerSendBuilder.status(item, records: [item.key: TrainerSentRecord(workoutId: 1, signature: "x", day: day.iso, kind: .run)]) == .changed)
    }

    @Test func staleOnlyListsRecordsTheAppCreatedInTheWindow() {
        let records: [String: TrainerSentRecord] = [
            "run|2026-11-18": TrainerSentRecord(workoutId: 1, signature: "a", day: "2026-11-18", kind: .run),
            "strength|2026-11-19|x": TrainerSentRecord(workoutId: 2, signature: "b", day: "2026-11-19", kind: .strength),
            "run|2026-12-30": TrainerSentRecord(workoutId: 3, signature: "c", day: "2026-12-30", kind: .run),
        ]
        let stale = TrainerSendBuilder.stale(records: records, current: ["run|2026-11-18"], kinds: [.run, .strength], from: day, through: day.adding(days: 6))
        #expect(stale.map(\.workoutId) == [2])
    }

    @Test func storeKeepsRecordsAndSettings() {
        let store = TrainerSendStore(defaults: UserDefaults(suiteName: "send-\(UUID())")!)
        store.record(TrainerSentRecord(workoutId: 9, signature: "s", day: "2026-11-18", kind: .strength), key: "k")
        var settings = store.settings()
        settings.auto = .strength
        store.save(settings)
        #expect(store.records()["k"]?.workoutId == 9)
        #expect(store.settings().auto == .strength)
        #expect(store.settings().runFromTrainer == false)
        store.remove(key: "k")
        #expect(store.records().isEmpty)
    }
}

@MainActor
@Suite struct TrainerSenderTests {
    private struct Failure: Error {}
    private let day = Day(iso: "2026-11-18")!

    private func item(_ text: String) -> TrainerSendItem {
        TrainerSendItem(key: "strength|2026-11-18|a", day: day, kind: .strength, title: "Mobilidade", payload: Data(text.utf8))
    }

    @Test func keepsTheRecordWhenRemovingAStaleWorkoutFails() async {
        let store = TrainerSendStore(defaults: UserDefaults(suiteName: "sender-\(UUID())")!)
        let record = TrainerSentRecord(workoutId: 10, signature: "x", day: "2026-11-19", kind: .strength)
        store.record(record, key: "old")
        let result = await TrainerSender.send([], stale: [(key: "old", record: record)], store: store, create: { _ in 1 }, remove: { _ in throw Failure() })
        #expect(result.failed == 1 && result.sent == 0 && result.removed == 0)
        #expect(result.firstError?.hasPrefix("erro no envio") == true)
        #expect(store.records()["old"] == record)
    }

    @Test func explainsGarminFailures() {
        #expect(TrainerSendText.errorReason(GarminAccountError.sessionExpired) == "a sessão do Garmin venceu, conecte de novo em Ajustes")
        #expect(TrainerSendText.errorReason(GarminAccountError.rateLimited) == "o Garmin limitou os envios, tente de novo em alguns minutos")
        #expect(TrainerSendText.errorReason(GarminAccountError.unexpectedResponse(status: 400)) == "o Garmin recusou (código 400)")
    }

    @Test func doesNotCreateWhenTheOldVersionCouldNotBeRemoved() async {
        let store = TrainerSendStore(defaults: UserDefaults(suiteName: "sender-\(UUID())")!)
        let changed = item("novo")
        let previous = TrainerSentRecord(workoutId: 10, signature: "antigo", day: day.iso, kind: .strength)
        store.record(previous, key: changed.key)
        var created = 0
        let result = await TrainerSender.send([changed], stale: [], store: store, create: { _ in created += 1; return 20 }, remove: { _ in throw Failure() })
        #expect(created == 0)
        #expect(result.failed == 1)
        #expect(store.records()[changed.key] == previous)
    }

    @Test func replacesTheOldVersionAfterRemovingIt() async {
        let store = TrainerSendStore(defaults: UserDefaults(suiteName: "sender-\(UUID())")!)
        let changed = item("novo")
        store.record(TrainerSentRecord(workoutId: 10, signature: "antigo", day: day.iso, kind: .strength), key: changed.key)
        var removed: [Int64] = []
        let result = await TrainerSender.send([changed], stale: [], store: store, create: { _ in 20 }, remove: { removed.append($0) })
        #expect(removed == [10])
        #expect(result == TrainerSendResult(sent: 1, removed: 0, failed: 0))
        #expect(store.records()[changed.key]?.workoutId == 20)
    }
}
