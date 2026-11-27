import Foundation
import Testing
import TrainingCore
@testable import Insights

@Suite struct TrainerSignalWeekTests {
    private let plan = makePlan()

    private func week(_ index: Int) -> TrainerWeek {
        plan.weeks[index - 1]
    }

    private func days(of week: TrainerWeek) -> [Day] {
        (0..<7).map { week.start.adding(days: $0) }
    }

    private func series<T>(_ closed: TrainerWeek, baseline: (Int) -> T, week value: T) -> [Day: T] {
        var result: [Day: T] = [:]
        for offset in 1...60 { result[closed.start.adding(days: -offset)] = baseline(offset) }
        for day in days(of: closed) { result[day] = value }
        return result
    }

    private func signalHistory(_ closed: TrainerWeek, _ signals: Set<TrainerSignal>) -> TrainerHistory {
        var history = makeHistory()
        if signals.contains(.hrv) { history.hrv = series(closed, baseline: { $0 % 2 == 0 ? 50.0 : 70.0 }, week: 30) }
        if signals.contains(.restingHeartRate) { history.restingHeartRate = series(closed, baseline: { _ in 50 }, week: 60) }
        if signals.contains(.sleep) { history.sleepSeconds = series(closed, baseline: { _ in 28_800 }, week: 24_000) }
        if signals.contains(.readiness) {
            history.readiness = Dictionary(uniqueKeysWithValues: days(of: closed).map { ($0, 40) })
        }
        if signals.contains(.load) {
            let end = closed.start.adding(days: 6)
            for offset in 7..<28 { history.dailyLoad[end.adding(days: -offset)] = 10 }
            for offset in 0..<7 { history.dailyLoad[end.adding(days: -offset)] = 50 }
        }
        if signals.contains(.performance) {
            history.runs += [0, 2].enumerated().map { index, offset in
                TrainerRun(
                    activityId: Int64(500 + index), day: closed.start.adding(days: offset), meters: 10_000, seconds: 3_600,
                    kind: .easy, averageHeartRate: 155
                )
            }
            history.runs += (0..<3).map { index in
                TrainerRun(
                    activityId: Int64(600 + index), day: closed.start.adding(days: -3 - index * 5), meters: 10_000, seconds: 3_600,
                    kind: .easy, averageHeartRate: 145
                )
            }
        }
        return history
    }

    private func closing(_ index: Int, _ signals: Set<TrainerSignal>) -> TrainerPlan {
        let closed = week(index)
        let history = signalHistory(closed, signals)
        #expect(Set(TrainerEngine.signals(plan: plan, history: history, week: closed)) == signals)
        return TrainerEngine.adjust(plan, history: history, today: closed.start.adding(days: 7), now: now, trigger: .weekEnded(index))
    }

    private func plain(_ index: Int) -> TrainerPlan {
        TrainerEngine.adjust(plan, history: makeHistory(), today: week(index).start.adding(days: 7), now: now, trigger: .weekEnded(index))
    }

    private func workouts(_ plan: TrainerPlan, week index: Int) -> [TrainerWorkout] {
        let start = plan.weeks[index - 1].start
        return plan.workouts.filter { $0.day >= start && $0.day < start.adding(days: 7) }.sorted { $0.day < $1.day }
    }

    private func rounded(_ meters: Double) -> Double {
        (meters / 1_000).rounded() * 1_000
    }

    @Test func noSignalKeepsThePlan() {
        let adjusted = closing(1, [])
        #expect(adjusted.weeks == plain(1).weeks)
        #expect(adjusted.earlyLightWeeks.isEmpty)
    }

    @Test func lowReadinessAloneKeepsThePlan() {
        let adjusted = closing(1, [.readiness])
        #expect(adjusted.weeks == plain(1).weeks)
        #expect(adjusted.versions.last?.summary.contains("segue o esqueleto") == true)
        #expect(adjusted.versions.last?.summary.contains("prontidão") == false)
    }

    @Test func oneBodySignalKeepsThePlan() {
        #expect(closing(1, [.hrv]).weeks == plain(1).weeks)
    }

    @Test func twoSignalsCutTenPercentAndDropStridesAndFartlek() throws {
        let adjusted = closing(1, [.sleep, .readiness])
        let next = adjusted.weeks[1]
        #expect(next.calm)
        #expect(!next.isRecovery)
        #expect(next.targetMeters == rounded(plain(1).weeks[1].targetMeters * 0.9))
        #expect(adjusted.weeks[2].targetMeters == plain(1).weeks[2].targetMeters)
        #expect(adjusted.calmWeeks == [next.start])
        let generated = workouts(adjusted, week: 2)
        #expect(!generated.contains { $0.variant == .strides || $0.variant == .fartlek })
        let before = workouts(plain(1), week: 2)
        #expect(before.contains { $0.variant == .strides } && before.contains { $0.variant == .fartlek })
        let quality: (TrainerWorkout) -> Bool = { $0.kind == .threshold || $0.kind == .vo2max }
        let after = generated.filter(quality)
        let planned = before.filter(quality)
        #expect(after.map(\.day) == planned.map(\.day))
        #expect(after.map(\.kind) == planned.map(\.kind))
        #expect(after.map(\.method) == planned.map(\.method))
        #expect(after.map(\.variant) == planned.map(\.variant))
        #expect(after.map(\.title) == planned.map(\.title))
        #expect(adjusted.weeks[2].calm == false)
    }

    @Test func weekAfterTheCalmWeekKeepsThePlannedProgression() {
        let adjusted = closing(1, [.sleep, .readiness])
        let later = TrainerEngine.adjust(
            adjusted, history: makeHistory(), today: week(3).start, now: now, trigger: .weekEnded(2)
        )
        let reference = TrainerEngine.adjust(
            plain(1), history: makeHistory(), today: week(3).start, now: now, trigger: .weekEnded(2)
        )
        #expect(later.weeks[1].calm)
        #expect(later.weeks[1].targetMeters == adjusted.weeks[1].targetMeters)
        #expect(Array(later.weeks.dropFirst(3)) == Array(reference.weeks.dropFirst(3)))
        #expect(later.weeks[2].targetMeters == reference.weeks[2].targetMeters)
        #expect(later.weeks[2].targetMeters == plan.weeks[2].targetMeters)
    }

    @Test func recreatingThePlanKeepsTheCalmWeek() throws {
        let adjusted = closing(1, [.sleep, .readiness])
        let request = TrainerRequest(category: .other, text: "recriar", from: week(2).start)
        let today = week(2).start
        let recreated = TrainerEngine.adjust(adjusted, history: makeHistory(), today: today, now: now, trigger: .request(request))
        let reference = TrainerEngine.adjust(plain(1), history: makeHistory(), today: today, now: now, trigger: .request(request))
        let calm = recreated.weeks[1]
        #expect(calm.calm)
        #expect(calm.targetMeters == rounded(reference.weeks[1].targetMeters * 0.9))
        #expect(recreated.weeks[2].targetMeters == reference.weeks[2].targetMeters)
        let generated = workouts(recreated, week: 2)
        #expect(!generated.contains { $0.variant == .strides || $0.variant == .fartlek })
        #expect(workouts(reference, week: 2).contains { $0.variant == .strides })
    }

    @Test func calmWeekAfterGeneralWeeksIsReduced() {
        let far = TrainerTarget(
            kind: .race, name: "Meia", date: monday.adding(days: 25 * 7 + 5), distanceMeters: 21_097.5, goalSeconds: 5_700
        )
        let general = TrainerEngine.create(
            target: far, structure: TrainerEngine.defaultStructure, strength: [], history: makeHistory(),
            today: monday, now: now, startMeters: 60_000, peakMeters: 80_000
        )
        #expect(general.weeks[0].phase == .general && general.weeks[1].phase == .general)
        let closed = general.weeks[0]
        let today = closed.start.adding(days: 7)
        let calm = TrainerEngine.adjust(
            general, history: signalHistory(closed, [.sleep, .readiness]), today: today, now: now, trigger: .weekEnded(1)
        )
        let reference = TrainerEngine.adjust(general, history: makeHistory(), today: today, now: now, trigger: .weekEnded(1))
        #expect(calm.weeks[1].calm)
        #expect(calm.weeks[1].targetMeters == rounded(reference.weeks[1].targetMeters * 0.9))
        #expect(calm.weeks[2].targetMeters == reference.weeks[2].targetMeters)
    }

    @Test func twoSignalsExplainTheLighterWeek() throws {
        let adjusted = closing(1, [.sleep, .readiness])
        let version = try #require(adjusted.versions.last)
        #expect(version.trigger == .weekEnded(1))
        #expect(version.summary.hasPrefix("Semana mais leve: sono e prontidão fora do seu normal."))
        let skeleton = try #require(version.changes.first { $0.kind == .skeleton })
        #expect(skeleton.reason.hasPrefix("Semana mais leve: sono e prontidão fora do seu normal."))
    }

    @Test func hrvAndRestingAnticipateABodyLightWeek() throws {
        let adjusted = closing(6, [.hrv, .restingHeartRate])
        let light = adjusted.weeks[6]
        #expect(light.isRecovery)
        #expect(light.lightKind == .body)
        #expect(!light.calm)
        #expect(adjusted.earlyLightWeeks == [light.start: .body])
        #expect(light.targetMeters == rounded(week(6).targetMeters * 0.75))
        let generated = workouts(adjusted, week: 7)
        let thresholds = generated.filter { $0.kind == .threshold }
        #expect(thresholds.count == 1)
        let recoveryThreshold = try #require(workouts(plan, week: 4).first { $0.kind == .threshold })
        #expect(thresholds.first?.title == recoveryThreshold.title)
        #expect(!generated.contains { $0.kind == .vo2max })
        let vo2Day = try #require(workouts(plan, week: 7).first { $0.kind == .vo2max }?.day)
        let replaced = try #require(generated.first { $0.day == vo2Day })
        #expect(replaced.kind == .easy)
        #expect(replaced.variant == nil)
        #expect(!generated.contains { $0.variant == .strides || $0.variant == .fartlek })
    }

    @Test func earlyLightWeekRestartsTheThreeToOneCount() {
        let adjusted = closing(6, [.hrv, .restingHeartRate])
        let recoveries = adjusted.weeks.filter(\.isRecovery).map(\.index)
        #expect(recoveries == [4, 7, 11])
        let later = TrainerEngine.adjust(
            adjusted, history: makeHistory(), today: week(8).start.adding(days: 7), now: now, trigger: .weekEnded(8)
        )
        #expect(later.weeks.filter(\.isRecovery).map(\.index) == [4, 7, 11])
        #expect(later.weeks[6].lightKind == .body)
    }

    @Test func earlyLightWeekExplainsTheChange() throws {
        let adjusted = closing(6, [.hrv, .restingHeartRate])
        let version = try #require(adjusted.versions.last)
        let text = "Semana leve antecipada: HRV e FC de repouso fora do seu normal."
        #expect(version.summary.hasPrefix(text))
        #expect(version.changes.first { $0.kind == .skeleton }?.reason.hasPrefix(text) == true)
        let start = adjusted.weeks[6].start
        let weekChanges = version.changes.filter { change in change.day.map { $0 >= start && $0 < start.adding(days: 7) } ?? false }
        #expect(!weekChanges.isEmpty)
        #expect(weekChanges.allSatisfy { $0.reason == text })
    }

    @Test func trainingSignalsAnticipateATrainingLightWeek() throws {
        let adjusted = closing(6, [.load, .performance, .readiness])
        let light = adjusted.weeks[6]
        #expect(light.isRecovery)
        #expect(light.lightKind == .training)
        #expect(light.targetMeters == rounded(week(6).targetMeters * 0.85))
        let generated = workouts(adjusted, week: 7)
        #expect(!generated.contains { $0.kind == .threshold || $0.kind == .vo2max })
        let qualityDays = workouts(plan, week: 7).filter { $0.kind == .threshold || $0.kind == .vo2max }.map(\.day)
        #expect(qualityDays.count == 2)
        for day in qualityDays {
            let replaced = try #require(generated.first { $0.day == day })
            #expect(replaced.kind == .easy)
            #expect(replaced.variant == .strides)
        }
        #expect(generated.filter { $0.variant == .strides }.count == 2)
        #expect(!generated.contains { $0.variant == .fartlek })
        #expect(adjusted.versions.last?.summary.hasPrefix("Semana leve antecipada: carga, desempenho e prontidão fora do seu normal.") == true)
    }

    @Test func recentLightWeekFallsBackToTenPercent() {
        let adjusted = closing(5, [.hrv, .restingHeartRate])
        let next = adjusted.weeks[5]
        #expect(!next.isRecovery)
        #expect(next.lightKind == nil)
        #expect(next.calm)
        #expect(next.targetMeters == rounded(plain(5).weeks[5].targetMeters * 0.9))
        #expect(adjusted.weeks[6].targetMeters == plain(5).weeks[6].targetMeters)
        #expect(adjusted.earlyLightWeeks.isEmpty)
        #expect(adjusted.versions.last?.summary.hasPrefix("Semana mais leve: HRV e FC de repouso fora do seu normal.") == true)
    }

    @Test func closeToTheRaceDoesNotAnticipate() {
        #expect(week(11).start.days(until: raceDay) <= 21)
        let adjusted = closing(10, [.hrv, .restingHeartRate, .sleep])
        let next = adjusted.weeks[10]
        #expect(!next.isRecovery)
        #expect(next.calm)
        #expect(next.targetMeters == rounded(plain(10).weeks[10].targetMeters * 0.9))
        #expect(adjusted.earlyLightWeeks.isEmpty)
    }

    @Test func taperIsNotTouched() {
        let adjusted = closing(11, [.hrv, .restingHeartRate, .sleep])
        #expect(adjusted.weeks == plain(11).weeks)
    }

    @Test func scheduledLightWeekStaysAsIs() {
        let baseline = plain(7).weeks
        #expect(closing(7, [.hrv, .restingHeartRate, .sleep]).weeks == baseline)
        #expect(closing(7, [.sleep, .readiness]).weeks == baseline)
    }

    @Test func tieBetweenBodyAndTrainingIsBody() {
        let decision = TrainerEngine.signalDecision(plan: plan, closed: week(6), signals: [.hrv, .restingHeartRate, .load, .readiness])
        #expect(decision == .early(.body))
        let training = TrainerEngine.signalDecision(plan: plan, closed: week(6), signals: [.sleep, .load, .readiness])
        #expect(training == .early(.training))
    }

    @Test func reasonTextsAreExact() {
        #expect(TrainerEngineText.signalWeek([.sleep, .readiness], early: false) == "Semana mais leve: sono e prontidão fora do seu normal.")
        #expect(
            TrainerEngineText.signalWeek([.hrv, .restingHeartRate, .sleep], early: true)
                == "Semana leve antecipada: HRV, FC de repouso e sono fora do seu normal."
        )
        #expect(
            TrainerEngineText.signalWeek([.load, .performance], early: false)
                == "Semana mais leve: carga e desempenho fora do seu normal."
        )
    }

    @Test func oldPlanJsonDecodesWithoutTheNewFields() throws {
        let data = try JSONEncoder().encode(plan)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "earlyLightWeeks")
        object.removeValue(forKey: "calmWeeks")
        var weeks = try #require(object["weeks"] as? [[String: Any]])
        for index in weeks.indices {
            weeks[index].removeValue(forKey: "calm")
            weeks[index].removeValue(forKey: "lightKind")
            weeks[index].removeValue(forKey: "baseMeters")
        }
        object["weeks"] = weeks
        let decoded = try JSONDecoder().decode(TrainerPlan.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.earlyLightWeeks.isEmpty)
        #expect(decoded.calmWeeks.isEmpty)
        #expect(decoded.weeks.allSatisfy { !$0.calm && $0.lightKind == nil })
        #expect(decoded == plan)
    }

    @Test func planWithEarlyLightWeeksRoundTrips() throws {
        let adjusted = closing(6, [.hrv, .restingHeartRate])
        let data = try JSONEncoder().encode(adjusted)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["earlyLightWeeks"] as? [String: String] == [week(7).start.iso: "body"])
        let decoded = try JSONDecoder().decode(TrainerPlan.self, from: data)
        #expect(decoded == adjusted)
        let calm = closing(1, [.sleep, .readiness])
        let decodedCalm = try JSONDecoder().decode(TrainerPlan.self, from: JSONEncoder().encode(calm))
        #expect(decodedCalm == calm)
        #expect(decodedCalm.weeks[1].calm)
        #expect(decodedCalm.calmWeeks == [week(2).start])
    }
}

extension TrainerSignalWeekTests {
    @Test func editingAfterAnEarlyLightWeekKeepsTheThreeToOneCount() {
        let adjusted = closing(6, [.hrv, .restingHeartRate])
        let today = week(8).start
        var overrides = adjusted.paceOverrides
        overrides[.easy] = 340
        let edited = TrainerEngine.adjust(
            adjusted, history: makeHistory(), today: today, now: now, trigger: .edited(TrainerEdit(paceOverrides: overrides))
        )
        #expect(edited.versions.count == adjusted.versions.count + 1)
        #expect(edited.weeks.filter(\.isRecovery).map(\.index) == [4, 7, 11])
        #expect(edited.weeks[7].isRecovery == false)
    }

    @Test func recreatingAfterAnEarlyLightWeekKeepsTheThreeToOneCount() {
        let adjusted = closing(6, [.hrv, .restingHeartRate])
        let today = week(8).start
        let request = TrainerRequest(category: .other, text: "recriar", from: today)
        let recreated = TrainerEngine.adjust(adjusted, history: makeHistory(), today: today, now: now, trigger: .request(request))
        #expect(recreated.versions.count == adjusted.versions.count + 1)
        #expect(recreated.weeks.filter(\.isRecovery).map(\.index) == [4, 7, 11])
        #expect(recreated.weeks[7].isRecovery == false)
    }

    @Test func togglingAnEarlyLightWeekUndoesTheAnticipation() {
        let adjusted = closing(6, [.hrv, .restingHeartRate])
        let start = week(7).start
        #expect(adjusted.earlyLightWeeks[start] == .body)
        let undone = TrainerEngine.adjust(adjusted, history: makeHistory(), today: start, now: now, trigger: .lightWeek(start))
        #expect(undone.earlyLightWeeks.isEmpty)
        #expect(undone.lightWeeks.isEmpty)
        #expect(undone.weeks[6].isRecovery == false)
        #expect(undone.weeks[6].lightKind == nil)
        #expect(undone.weeks.filter(\.isRecovery).map(\.index) == plan.weeks.filter(\.isRecovery).map(\.index))
    }

    @Test func offTargetQualitiesBeforeALightWeekDoNotFireAgain() throws {
        let adjusted = closing(6, [.load, .performance, .readiness])
        let light = adjusted.weeks[6]
        #expect(light.lightKind == .training)
        let qualities = workouts(adjusted, week: 6).filter { $0.kind == .threshold || $0.kind == .vo2max }
        try #require(qualities.count == 2)
        var history = makeHistory()
        history.runs += qualities.enumerated().map { index, workout in
            TrainerRun(
                activityId: Int64(700 + index), day: workout.day, meters: workout.totalMeters, seconds: workout.totalMeters / 1_000 * 300,
                kind: workout.kind == .threshold ? .tempo : .intervals, activeOnTarget: 3, activeTotal: 5
            )
        }
        #expect(TrainerEngine.signals(plan: adjusted, history: history, week: adjusted.weeks[5]).contains(.performance))
        #expect(!workouts(adjusted, week: 7).contains { $0.kind == .threshold || $0.kind == .vo2max })
        #expect(!TrainerEngine.signals(plan: adjusted, history: history, week: light).contains(.performance))
    }
}
