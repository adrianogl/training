import Testing
@testable import trAIning

@Suite struct GoalBulletChartTests {
    @Test func closeLabelsAreSpreadApart() throws {
        let positions = GoalBulletChart.labelPositions(today: 200, raceDay: 210, width: 400)

        let today = try #require(positions.today)
        let raceDay = try #require(positions.raceDay)
        #expect(raceDay - today == TodayConstants.bulletLabelGap)
        #expect(today < raceDay)
    }

    @Test func distantLabelsStayOnTheirMarks() {
        let positions = GoalBulletChart.labelPositions(today: 100, raceDay: 300, width: 400)

        #expect(positions.today == 100)
        #expect(positions.raceDay == 300)
    }

    @Test func spreadLabelsStayInsideTheCard() {
        let positions = GoalBulletChart.labelPositions(today: 395, raceDay: 390, width: 400)

        #expect((positions.today ?? 0) <= 400 - TodayConstants.bulletLabelInset)
        #expect((positions.raceDay ?? 0) >= TodayConstants.bulletLabelInset)
    }

    @Test func weeksLeftUsesSingularAndSkipsZero() {
        #expect(TodayText.weeksLeft(days: 9) == "1 semana e 2 dias de treino")
        #expect(TodayText.weeksLeft(days: 14) == "2 semanas de treino")
        #expect(TodayText.weeksLeft(days: 1) == "1 dia de treino")
        #expect(TodayText.weeksLeft(days: 0) == "0 dias de treino")
    }
}
