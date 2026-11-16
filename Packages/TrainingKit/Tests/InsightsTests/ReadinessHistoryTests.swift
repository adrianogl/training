import Storage
import Testing
import TrainingCore
@testable import Insights

@Suite struct ReadinessHistoryTests {
    @Test func historyCoversThirtyDaysEndingTodayWithGarminFallback() throws {
        let context = try makeContext([
            DailyRecord(day: fixtureToday.iso, readinessScore: 90),
            DailyRecord(day: daysAgo(1).iso, readinessScore: 49),
            DailyRecord(day: daysAgo(29).iso, readinessScore: 82),
            DailyRecord(day: daysAgo(30).iso, readinessScore: 11),
        ])

        let history = try todaySummary(context: context, today: fixtureToday).readinessHistory ?? []

        #expect(history.count == InsightsConstants.readinessChartDays)
        #expect(history.first == ReadinessDayScore(day: daysAgo(29), score: 82))
        #expect(history.last == ReadinessDayScore(day: fixtureToday, score: 90))
        #expect(history[history.count - 2].score == 49)
        #expect(history[history.count - 3].score == nil)
    }

    @Test func historyUsesTheAppScoreWhenTheNightHasData() throws {
        var records = (1...40).map { offset in
            DailyRecord(day: daysAgo(offset).iso, hrvLastNight: 45, sleepScore: 75, readinessScore: 20)
        }
        records.append(DailyRecord(day: fixtureToday.iso, hrvLastNight: 55, sleepScore: 85, readinessScore: 20))
        let context = try makeContext(records)

        let summary = try todaySummary(context: context, today: fixtureToday)
        let today = try #require(summary.readinessHistory?.last)

        #expect(today.score == summary.readiness?.score)
        #expect(today.score != 20)
    }

    @Test func movingAverageSkipsMissingDaysAndStartsWithAFullWindow() {
        let scores: [Int?] = [10, 20, nil, 40, 50, 60, 70, 80]

        let average = readinessMovingAverage(scores, window: 3)

        #expect(average.count == scores.count)
        #expect(average[0] == nil)
        #expect(average[1] == nil)
        #expect(average[2] == 15)
        #expect(average[3] == 30)
        #expect(average[7] == 70)
    }

    @Test func averageIgnoresMissingDays() {
        #expect(readinessAverage([nil, 40, 60, nil]) == 50)
        #expect(readinessAverage([nil, nil]) == nil)
    }
}
