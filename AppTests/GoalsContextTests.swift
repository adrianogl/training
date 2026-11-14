import FITReader
import Foundation
import Insights
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import trAIning

@MainActor @Suite struct GoalsContextTests {
    private static let today = Day(iso: "2026-11-13")!

    private static func timeGoal(deadline: Day? = Day(iso: "2026-03-15"), today seconds: Double? = 2_484, gap: Double? = 84, achievedOn: Day? = nil) -> GoalSnapshot {
        GoalSnapshot(
            id: UUID(), kind: .time, distanceKm: 10, targetSeconds: 2_400, deadline: deadline, paceSecondsPerKm: nil,
            progress: .time(TimeGoalProgress(todaySeconds: seconds, gapSeconds: gap, crossing: .noGoal, achievedOn: achievedOn))
        )
    }

    private static func longGoal(runs: Int = 6, met: Int = 0, best: Double? = 11.8) -> GoalSnapshot {
        let checks = (0..<runs).map { LongRunCheck(activityId: Int64($0), day: today, distanceKm: 16) }
        return GoalSnapshot(
            id: UUID(), kind: .continuousLong, distanceKm: 16, targetSeconds: nil, deadline: nil, paceSecondsPerKm: 290,
            progress: .continuousLong(LongGoalProgress(runs: checks, metCount: met, bestContinuousKm: best, achievedOn: nil))
        )
    }

    private static func samples(kilometers: Double, secondsPerKm: Double, pauseAtKm: Double? = nil) -> Data {
        let speed = 1_000 / secondsPerKm
        var result: [FITSample] = []
        var t = 0.0
        var distance = 0.0
        var paused = false
        while distance < kilometers * 1_000 {
            result.append(FITSample(t: t, speed: speed, distance: distance))
            if let pauseAtKm, !paused, distance >= pauseAtKm * 1_000 {
                paused = true
                for _ in 0..<4 {
                    t += 10
                    result.append(FITSample(t: t, speed: 0, distance: distance))
                }
            }
            t += 10
            distance += speed * 10
        }
        result.append(FITSample(t: t, speed: speed, distance: distance))
        return try! JSONEncoder().encode(result)
    }

    private static func run(meters: Double, seconds: Double, name: String = "Longão", samples: Data? = nil) -> ActivityRecord {
        let record = ActivityRecord(activityId: 1, typeKey: "running", name: name, start: .now, distance: meters, duration: seconds, movingDuration: seconds)
        record.samplesData = samples
        return record
    }

    @Test func chatFactsDescribeTimeGoal() {
        let lines = GoalsChatFacts.lines([Self.timeGoal()])

        #expect(lines == ["Meta: 10 km em 40:00, previsão de hoje 41:24, faltam 1:24, prazo 15 de mar."])
    }

    @Test func chatFactsDescribeLongGoal() {
        let lines = GoalsChatFacts.lines([Self.longGoal()])

        #expect(lines == ["Meta: longão de 16 km a 4:50/km sem pausas; 0 de 6 longões recentes cumpriram; melhor trecho contínuo 11,8 km."])
    }

    @Test func buildersAppendGoalFacts() {
        let context = EvolutionChatContextBuilder.context(
            verdictTitle: "Evoluindo", sentence: "", indicators: [], outlook: TodaySummary.empty.race, countdownDays: nil,
            cards: [], records: [], zoneWeeks: [], goals: [Self.timeGoal()]
        )

        #expect(context.facts.contains("Meta: 10 km em 40:00"))
    }

    @Test func noticeAnnouncesMetLongGoal() {
        let record = Self.run(meters: 16_100, seconds: 16.1 * 280, samples: Self.samples(kilometers: 16.1, secondsPerKm: 280))

        let content = WorkoutNotice.content(record: record, score: nil, opening: "Boa corrida.", goals: [Self.longGoal()])

        #expect(content.title == "Meta cumprida · 16 km sem pausas · Longão")
        #expect(content.body == "Boa corrida.")
    }

    @Test func noticeMentionsPauseOnNearLongRun() {
        let record = Self.run(meters: 13_000, seconds: 13 * 280, samples: Self.samples(kilometers: 13, secondsPerKm: 280, pauseAtKm: 9))

        let content = WorkoutNotice.content(record: record, score: nil, opening: "Boa corrida.", goals: [Self.longGoal()])

        #expect(content.title == "Longão")
        #expect(content.body.hasPrefix("Teve 1 pausa. Maior trecho contínuo: 9"))
        #expect(content.body.hasSuffix("A meta é 16 km sem pausas.\nBoa corrida."))
    }

    @Test func noticeAnnouncesMetTimeGoal() {
        let record = Self.run(meters: 10_020, seconds: 2_390, name: "Corrida")

        let content = WorkoutNotice.content(record: record, score: 80, opening: nil, goals: [Self.timeGoal()])

        #expect(content.title == "Meta cumprida · 10 km em 40:00 · Corrida · nota 80")
    }

    @Test func noticeKeepsDefaultWithoutGoalOrWhenSlower() {
        let slow = Self.run(meters: 10_000, seconds: 2_500)

        #expect(WorkoutNotice.content(record: slow, score: nil, opening: "x", goals: [Self.timeGoal()]).title == "Longão")
        #expect(WorkoutNotice.content(record: slow, score: nil, opening: "x").title == "Longão")
    }

    @Test func watchFaceUsesTimeGoalWhenThereIsNoRace() throws {
        let container = try TrainingSchema.container(inMemory: true)
        let context = ModelContext(container)
        context.insert(GoalRecord(kind: .time, distanceKm: 10, targetSeconds: 2_400, deadline: "2026-12-20"))
        context.insert(GoalRecord(kind: .time, distanceKm: 5, targetSeconds: 1_200))
        try context.save()

        let face = WatchFaceBuilder.face(context: context, summary: .empty, today: Self.today, planned: [], weeklyGoalKm: 0)

        #expect(face?.raceName == "META 10K")
        #expect(face?.raceDay == "2026-12-20")
        #expect(face?.raceGoal == 2_400)
    }

    @Test func watchGoalLineCarriesPredictionAndSkipsGoalsWithoutDeadline() {
        let line = WatchFaceBuilder.goalLine(goalSnapshots: [Self.timeGoal(deadline: nil), Self.timeGoal(deadline: Day(iso: "2026-12-20"))], today: Self.today)

        #expect(line == WatchGoalLine(name: "META 10K", day: "2026-12-20", goalSeconds: 2_400, predictionSeconds: 2_484))
        #expect(WatchFaceBuilder.goalLine(goalSnapshots: [Self.timeGoal(deadline: nil), Self.longGoal()], today: Self.today) == nil)
    }
}
