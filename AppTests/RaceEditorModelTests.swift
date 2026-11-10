import Foundation
import Insights
import Metrics
import Storage
import SwiftData
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct RaceEditorModelTests {
    private static let today = Day(iso: WorkoutDetailFixtures.day(WorkoutDetailFixtures.base))!

    @Test func editorAssessesAgainstRaceDayProjection() async throws {
        let container = try TodayModelTests.store(withRace: true, goalSeconds: 6_000)
        let race = try #require(try container.mainContext.fetch(FetchDescriptor<RaceRecord>()).first)
        let next = NextRaceModel(container: container, raceId: race.id, today: Self.today)
        await next.load()

        let editor = RaceEditorModel(container: container, raceId: race.id, today: Self.today)
        await editor.load()
        await editor.evaluate()

        let assessment = try #require(editor.assessment)
        let card = try #require(next.goalSummary)
        #expect(assessment.reference == .raceDayProjection)
        #expect(assessment.referenceSeconds == next.outlook.raceDay?.mid)
        #expect(assessment.level == next.outlook.assessment)
        #expect(assessment.sentence == card.sentence)
    }

    @Test func editorFallsBackToTodayPredictionWithoutProjection() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let run = WorkoutDetailFixtures.run(id: 1, daysAgo: 0, meters: 5_000)
        run.fastestSplit_5000 = 1_500
        container.mainContext.insert(run)
        try container.mainContext.save()
        let editor = RaceEditorModel(container: container, raceId: nil, today: Self.today)
        await editor.load()
        editor.distanceOption = .half
        editor.date = Self.today.adding(days: 30).chartDate
        editor.goalText = "1:45:00"
        await editor.evaluate()

        let efforts = try raceEfforts(context: container.mainContext, today: Self.today)
        let outlook = raceOutlook(distance: 21_097.5, raceDay: Self.today.adding(days: 30), goalSeconds: 6_300, efforts: efforts, today: Self.today)
        #expect(outlook.raceDay == nil)
        let todaySeconds = try #require(outlook.today)
        let assessment = try #require(editor.assessment)
        #expect(editor.goalSeconds == 6_300)
        #expect(assessment.targetPaceText == "4:59 /km")
        #expect(assessment.reference == .todayPrediction)
        #expect(assessment.referenceSeconds == todaySeconds)
        #expect(assessment.comparedText == RacesConstants.comparedToday)
        #expect(assessment.sentence.hasSuffix("da previsão de hoje."))
    }

    @Test func savesNewRaceAndClearsFrozenTargetWhenDateMoves() async throws {
        let container = try TrainingSchema.container(inMemory: true)
        let editor = RaceEditorModel(container: container, raceId: nil, today: Self.today)
        await editor.load()
        editor.name = "Meia de teste"
        editor.distanceOption = .half
        editor.goalText = "1:46:00"
        editor.priority = .a
        editor.date = Self.today.adding(days: 30).chartDate
        try editor.save()

        let race = try #require(try container.mainContext.fetch(FetchDescriptor<RaceRecord>()).first)
        #expect(race.name == "Meia de teste")
        #expect(race.distance == 21_097.5)
        #expect(race.goalSeconds == 6_360)
        #expect(race.day == Self.today.adding(days: 30).iso)
        race.frozenTargetSeconds = 6_400
        race.frozenTargetDay = Self.today.iso

        let again = RaceEditorModel(container: container, raceId: race.id, today: Self.today)
        await again.load()
        again.date = Self.today.adding(days: 40).chartDate
        try again.save()

        #expect(race.day == Self.today.adding(days: 40).iso)
        #expect(race.frozenTargetSeconds == nil)
        #expect(race.frozenTargetDay == nil)
    }

    @Test func parsesGoalText() {
        #expect(RaceEditorModel.parseClock("1:45:00") == 6_300)
        #expect(RaceEditorModel.parseClock("22:30") == 1_350)
        #expect(RaceEditorModel.parseClock("1:75:00") == nil)
        #expect(RaceEditorModel.parseClock("") == nil)
    }
}
