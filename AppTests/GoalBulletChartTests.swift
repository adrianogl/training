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

    @Test func rulerTicksFollowTheSpan() {
        #expect(GoalBulletLayout.ticks(fastest: 2_390, slowest: 2_435).map(\.text) == ["40:00", "40:15", "40:30"])
        #expect(GoalBulletLayout.ticks(fastest: 5_880, slowest: 6_330).map(\.text) == ["1:38", "1:40", "1:42", "1:44"])
    }

    @Test func gapTextSaysHowFarTheRaceDayIs() {
        #expect(GoalBulletLayout.gapText(raceDay: 2_420, goal: 2_400) == "faltam 20 s no dia")
        #expect(GoalBulletLayout.gapText(raceDay: 6_070, goal: 5_940) == "faltam 2:10 no dia")
        #expect(GoalBulletLayout.gapText(raceDay: 2_390, goal: 2_400) == "10 s abaixo da meta no dia")
        #expect(GoalBulletLayout.gapText(raceDay: 2_400, goal: 2_400) == "na meta no dia")
        #expect(GoalBulletLayout.gapText(raceDay: nil, goal: 2_400) == nil)
    }
}
