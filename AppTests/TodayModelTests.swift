import Foundation
import Insights
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct TodayModelTests {
    private typealias F = WorkoutDetailFixtures

    private static let today = Day(iso: F.day(F.base))!

    static func store(withRace: Bool, goalSeconds: Double? = 6_300) throws -> ModelContainer {
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        let name = "Tiros 3 x 1 km"
        for (index, daysAgo) in stride(from: 0, through: 100, by: 7).enumerated() {
            let record = F.run(id: Int64(index + 1), daysAgo: Double(daysAgo), meters: 5_900, workoutName: name, structure: F.intervalStructure())
            record.fastestSplit_5000 = 1_500 + Double(daysAgo)
            record.activityTrainingLoad = 70
            context.insert(record)
        }
        for offset in 0...40 {
            context.insert(DailyRecord(
                day: today.adding(days: -offset).iso,
                stressAvg: 25,
                bodyBatteryMorningMax: 70,
                hrvLastNight: offset == 0 ? 70 : 60,
                hrvLowUpper: 40,
                hrvBalancedLow: 50,
                hrvBalancedUpper: 70,
                sleepSeconds: 7 * 3_600,
                sleepScore: 80
            ))
        }
        if withRace {
            context.insert(RaceRecord(name: "Alvo", day: today.adding(days: 34).iso, distance: 21_097.5, goalSeconds: goalSeconds, priority: .a))
        }
        try context.save()
        return container
    }

    @Test func todayModelBuildsFromStore() async throws {
        let container = try Self.store(withRace: true)

        let model = TodayModel(container: container, today: Self.today)
        #expect(model.isLoaded == false)
        #expect(model.lastRun == nil)
        await model.load()

        #expect(model.summary.readiness != nil)
        #expect(model.summary.verdict != nil)
        #expect(!model.summary.fitness.history.isEmpty)
        #expect(!model.summary.fitness.projection.isEmpty)
        #expect(model.summary.race.today != nil)
        #expect(model.summary.raceCountdownDays == 34)
        #expect(model.summary.week.perDay[Self.today] != nil)
        #expect(model.summary.predictions.count == 4)
        #expect(model.lastRun != nil)
        #expect(!model.readinessSentence.isEmpty)
        #expect(model.readinessDay.sleepSeconds == 7 * 3_600)
        #expect(model.isLoaded)
    }

    @Test func todayModelWithoutRaceShowsHalfAndNoCountdown() async throws {
        let container = try Self.store(withRace: false)

        let model = TodayModel(container: container, today: Self.today)
        await model.load()

        #expect(model.summary.raceCountdownDays == nil)
        #expect(model.summary.race.goalCrossing == .noGoal)
        #expect(model.summary.race.label == "21,1 km")
        #expect(model.summary.fitness.raceDayForm == nil)
        #expect(model.raceTitle == "21,1 km")
        #expect(model.goalSentence == nil)
    }

    @Test func lastRunUsesPlan2Comparison() async throws {
        let container = try Self.store(withRace: true)
        let context = container.mainContext
        let model = TodayModel(container: container, today: Self.today)
        await model.load()
        let records = try context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))
        let id = try #require(model.summary.lastRunId)
        let record = try #require(records.first { $0.activityId == id })

        let expected = WorkoutAnalysisContext.build(record: record, records: records, in: context)

        let lastRun = try #require(model.lastRun)
        #expect(lastRun.rows == expected.comparisonRows)
        #expect(!lastRun.rows.isEmpty)
        #expect(lastRun.title == "Tiros 3 x 1 km")
        #expect(lastRun.activityId == id)
    }

    @Test func factorRowsShowRealValueAndNormal() async throws {
        let container = try Self.store(withRace: true)
        let model = TodayModel(container: container, today: Self.today)
        await model.load()

        let rows = model.factorRows
        let hrv = try #require(rows.first { $0.component == .hrv })
        let sleep = try #require(rows.first { $0.component == .sleep })
        let load = try #require(rows.first { $0.component == .load })

        #expect(hrv.detail == "70 ms · seu normal 60 ms · peso 35%")
        #expect(hrv.group == .up)
        #expect(sleep.detail.hasPrefix("nota 80 · 7h00 · seu normal 80 · peso"))
        #expect(load.detail.contains("aguda:crônica"))
        #expect(load.detail.contains("ideal 0,8–1,3"))
    }

    @Test func readinessSummaryHasNoDuplicatedSign() {
        #expect(TodayText.readinessSummary(score: 74, normal: 68) == "+6 sobre o seu normal (68)")
        #expect(TodayText.readinessSummary(score: 65, normal: 68) == "3 abaixo do seu normal (68)")
        #expect(TodayText.readinessSummary(score: 68, normal: 68) == "No seu normal (68)")
    }

    @Test func goalSentencesFollowCrossing() {
        let race = Day(iso: "2026-12-10")!
        func sentence(_ crossing: GoalCrossing, today: Double? = 6_000) -> String? {
            TodayText.goalSentence(crossing: crossing, goalSeconds: 6_300, hasPrediction: today != nil, raceDay: race)
        }

        #expect(sentence(.on(Day(iso: "2027-01-15")!)) == "Meta de 1:45 deve chegar em meados de janeiro, 5 semanas depois da prova.")
        #expect(sentence(.on(Day(iso: "2026-12-02")!)) == "Meta de 1:45 deve chegar em início de dezembro.")
        #expect(sentence(.on(Day(iso: "2026-12-26")!)) == "Meta de 1:45 deve chegar em fim de dezembro, 2 semanas depois da prova.")
        #expect(sentence(.alreadyBeaten) == "A previsão já está abaixo da meta.")
        #expect(sentence(.unreachable) == "Na tendência atual, a meta não é alcançada.")
        #expect(sentence(.unreachable, today: nil) == nil)
        #expect(sentence(.noGoal) == nil)
    }
}
