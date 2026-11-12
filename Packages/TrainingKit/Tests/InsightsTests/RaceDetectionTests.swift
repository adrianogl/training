import Foundation
import Storage
import SwiftData
import Sync
import Testing
import TrainingCore
@testable import Insights

private func raceRun(
    id: Int64,
    daysAgo offset: Int,
    distance: Double = 10_050,
    seconds: Double = 2_900,
    averageHR: Double? = 165,
    name: String = "Corrida 10K",
    workoutName: String? = nil,
    structured: Bool = false,
    fitProcessed: Bool = true,
    anaerobic: Double? = 1.2,
    pr: Bool? = nil
) -> ActivityRecord {
    let day = daysAgo(offset)
    return ActivityRecord(
        activityId: id,
        typeKey: "running",
        name: name,
        start: noon(day),
        distance: distance,
        duration: seconds + 20,
        movingDuration: seconds,
        averageHR: averageHR,
        anaerobicTrainingEffect: anaerobic,
        pr: pr,
        fitProcessed: fitProcessed,
        localDay: day.iso,
        workoutName: workoutName,
        structureData: structured ? Data([1]) : nil
    )
}

private func easyRuns(around distance: Double = 10_000, days: [Int] = [20, 30, 40], startingId: Int64 = 100) -> [ActivityRecord] {
    days.enumerated().map { index, offset in
        raceRun(id: startingId + Int64(index), daysAgo: offset, distance: distance, seconds: distance * 0.36, averageHR: 140, name: "Corrida leve")
    }
}

private func threshold(_ heartRate: Int) -> ThresholdHistoryRecord {
    ThresholdHistoryRecord(sport: SyncConstants.fitThresholdSport, day: daysAgo(200).iso, heartRate: heartRate)
}

@Suite struct RaceDetectionTests {
    @Test func detectsFastUnstructuredRunAtRaceDistance() throws {
        let race = raceRun(id: 1, daysAgo: 5, pr: true)
        let fastOffDistance = raceRun(id: 2, daysAgo: 6, distance: 8_000, seconds: 2_300)
        let context = try makeContext(easyRuns() + [race, fastOffDistance])

        let candidates = try raceCandidates(in: context, today: fixtureToday)

        #expect(candidates.map(\.activityId) == [1])
        let candidate = try #require(candidates.first)
        #expect(candidate.day == daysAgo(5))
        #expect(candidate.name == "Corrida 10K")
        #expect(candidate.distance == 10_050)
        #expect(candidate.seconds == 2_920)
        #expect(candidate.averageHeartRate == 165)
        #expect(candidate.isPR)
    }

    @Test func ignoresStructuredWorkouts() throws {
        let named = raceRun(id: 1, daysAgo: 5, workoutName: "Limiar 3x10")
        let structured = raceRun(id: 2, daysAgo: 6, structured: true)
        let context = try makeContext(easyRuns() + [named, structured])

        #expect(try raceCandidates(in: context, today: fixtureToday).isEmpty)
    }

    @Test func ignoresUnprocessedRuns() throws {
        let context = try makeContext(easyRuns() + [raceRun(id: 1, daysAgo: 5, fitProcessed: false)])

        #expect(try raceCandidates(in: context, today: fixtureToday).isEmpty)
    }

    @Test func ignoresIntervalsWithoutGarminWorkout() throws {
        let context = try makeContext(easyRuns() + [raceRun(id: 1, daysAgo: 5, anaerobic: 3.1)])

        #expect(try raceCandidates(in: context, today: fixtureToday).isEmpty)
    }

    @Test func usesThresholdWhenNoBaseline() throws {
        let hard = raceRun(id: 1, daysAgo: 5, distance: 21_100, seconds: 6_300, averageHR: 153)
        let easy = raceRun(id: 2, daysAgo: 60, distance: 5_000, seconds: 1_500, averageHR: 140)
        let context = try makeContext([threshold(160), hard, easy])

        #expect(try raceCandidates(in: context, today: fixtureToday).map(\.activityId) == [1])
    }

    @Test func withoutBaselineOrThresholdNothingIsAsked() throws {
        let context = try makeContext([raceRun(id: 1, daysAgo: 5, averageHR: 180)])

        #expect(try raceCandidates(in: context, today: fixtureToday).isEmpty)
    }

    @Test func candidatesComeMostRecentFirstWithinOneYear() throws {
        let context = try makeContext([
            threshold(160),
            raceRun(id: 1, daysAgo: 300, distance: 5_000, seconds: 1_200),
            raceRun(id: 2, daysAgo: 10, distance: 42_195, seconds: 14_400),
            raceRun(id: 3, daysAgo: 400, distance: 10_000),
        ])

        #expect(try raceCandidates(in: context, today: fixtureToday).map(\.activityId) == [2, 1])
    }

    @Test func declinedStaysHiddenAfterResync() throws {
        let context = try makeContext(easyRuns() + [raceRun(id: 1, daysAgo: 5)])

        try declineRace(activityId: 1, in: context)
        let original = try #require(try context.fetch(FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.activityId == 1 })).first)
        context.delete(original)
        context.insert(raceRun(id: 1, daysAgo: 5))
        try context.save()

        #expect(try raceCandidates(in: context, today: fixtureToday).isEmpty)
        let decisions = try context.fetch(FetchDescriptor<RaceDecisionRecord>())
        #expect(decisions.map(\.raceDecision) == [.notRace])
    }

    @Test func confirmCreatesCompletedRace() throws {
        let context = try makeContext(easyRuns(around: 21_000) + [raceRun(id: 1, daysAgo: 5, distance: 21_300, seconds: 6_000, name: "Meia da cidade")])
        #expect(try raceCandidates(in: context, today: fixtureToday).map(\.activityId) == [1])

        try confirmRace(activityId: 1, in: context)

        let races = try context.fetch(FetchDescriptor<RaceRecord>())
        let race = try #require(races.first)
        #expect(races.count == 1)
        #expect(race.name == "Meia da cidade")
        #expect(race.day == daysAgo(5).iso)
        #expect(race.distance == 21_097.5)
        #expect(race.priorityLevel == .c)
        #expect(race.goalSeconds == nil)
        #expect(race.resultActivityId == 1)
        #expect(try context.fetch(FetchDescriptor<RaceDecisionRecord>()).map(\.raceDecision) == [.race])
        #expect(try raceCandidates(in: context, today: fixtureToday).isEmpty)
    }

    @Test func deletingConfirmedRaceDoesNotAskAgain() throws {
        let context = try makeContext(easyRuns() + [raceRun(id: 1, daysAgo: 5)])

        try confirmRace(activityId: 1, in: context)
        try context.fetch(FetchDescriptor<RaceRecord>()).forEach(context.delete)
        try context.save()

        #expect(try raceCandidates(in: context, today: fixtureToday).isEmpty)
    }

    @Test func registeredRaceLinkedToActivityIsNotAsked() throws {
        let linked = RaceRecord(name: "10 km", day: daysAgo(5).iso, distance: 10_000, resultActivityId: 1)
        let context = try makeContext(easyRuns() + [raceRun(id: 1, daysAgo: 5), linked])

        #expect(try raceCandidates(in: context, today: fixtureToday).isEmpty)
    }

    @Test func autoLinkPicksClosestDistance() throws {
        let race = RaceRecord(name: "10 km", day: daysAgo(3).iso, distance: 10_000)
        let manual = RaceRecord(name: "Meia", day: daysAgo(3).iso, distance: 10_000, resultActivityId: 99)
        let upcoming = RaceRecord(name: "Hoje", day: fixtureToday.iso, distance: 10_000)
        let context = try makeContext([
            race, manual, upcoming,
            raceRun(id: 1, daysAgo: 3, distance: 9_700),
            raceRun(id: 2, daysAgo: 3, distance: 10_100),
            raceRun(id: 3, daysAgo: 3, distance: 10_500),
            raceRun(id: 4, daysAgo: 0, distance: 10_000),
        ])

        try autoLinkRaces(in: context, today: fixtureToday)

        #expect(race.resultActivityId == 2)
        #expect(manual.resultActivityId == 99)
        #expect(upcoming.resultActivityId == nil)
    }

    @Test func autoLinkSkipsRunsOutsideTolerance() throws {
        let race = RaceRecord(name: "10 km", day: daysAgo(3).iso, distance: 10_000)
        let context = try makeContext([race, raceRun(id: 1, daysAgo: 3, distance: 10_500)])

        try autoLinkRaces(in: context, today: fixtureToday)

        #expect(race.resultActivityId == nil)
    }

    @Test func autoLinkRespectsManualUnlink() throws {
        let race = RaceRecord(name: "10 km", day: daysAgo(3).iso, distance: 10_000, manuallyUnlinked: true)
        let context = try makeContext([race, raceRun(id: 1, daysAgo: 3, distance: 10_000)])

        try autoLinkRaces(in: context, today: fixtureToday)

        #expect(race.resultActivityId == nil)
    }
}
