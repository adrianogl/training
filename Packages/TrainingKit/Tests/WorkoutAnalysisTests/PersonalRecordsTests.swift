import FITReader
import Foundation
import Storage
import Testing
@testable import WorkoutAnalysis

@Suite struct PersonalRecordsTests {
    private func samples(paces: [Double]) -> [FITSample] {
        var result = [FITSample(t: 0, distance: 0)]
        var t = 0.0
        var d = 0.0
        for pace in paces {
            for _ in 0..<10 {
                t += pace / 10
                d += 100
                result.append(FITSample(t: t, distance: d))
            }
        }
        return result
    }

    private func run(_ id: Int64, day: Int, _ efforts: [RunEffort]) -> RunEfforts {
        RunEfforts(activityId: id, start: Date(timeIntervalSince1970: Double(day) * 86_400), efforts: efforts)
    }

    private func effort(_ meters: Double, _ seconds: Double, _ source: RecordSource = .wholeRun) -> RunEffort {
        RunEffort(meters: meters, seconds: seconds, source: source)
    }

    @Test func bestSegmentFindsTheFastestKilometer() {
        let points = samples(paces: [300, 300, 240, 300]).compactMap { s in s.distance.map { (t: s.t, d: $0) } }
        let best = PersonalRecords.bestSegment(points, meters: 1_000)
        #expect(best?.seconds == 240)
        #expect(best?.startMeters == 2_000)
    }

    @Test func bestSegmentNeedsTheWholeDistance() {
        let points = samples(paces: [300, 300]).compactMap { s in s.distance.map { (t: s.t, d: $0) } }
        #expect(PersonalRecords.bestSegment(points, meters: 5_000) == nil)
    }

    @Test func effortsTakeTheWholeRunAndTheSegments() {
        let record = ActivityRecord(activityId: 1, typeKey: "running", name: "Ritmo", start: .now, distance: 5_000, duration: 1_440)
        let efforts = PersonalRecords.efforts(record: record, samples: samples(paces: [300, 290, 280, 290, 280]))
        #expect(efforts.map(\.meters) == [1_000, 3_000, 5_000])
        #expect(efforts.first { $0.meters == 3_000 }?.seconds == 850)
        #expect(efforts.first { $0.meters == 5_000 }?.seconds == 1_440)
        #expect(efforts.first { $0.meters == 1_000 }?.seconds == 280)
    }

    @Test func fallsBackToGarminSplitsWithoutSamples() {
        let record = ActivityRecord(activityId: 1, typeKey: "running", name: "Rodagem", start: .now, distance: 8_000, duration: 2_800)
        record.fastestSplit_1000 = 320
        let efforts = PersonalRecords.efforts(record: record, samples: [])
        #expect(efforts == [RunEffort(meters: 1_000, seconds: 320, source: .segment)])
    }

    @Test func timelineMarksFasterRunsAsRecordsWithThePreviousBest() {
        let result = PersonalRecords.timeline([
            run(1, day: 1, [effort(5_000, 1_500)]),
            run(2, day: 2, [effort(5_000, 1_480)]),
            run(3, day: 3, [effort(5_000, 1_480)]),
        ])
        #expect(result[1] == nil)
        #expect(result[2]?.records == [RecordHit(effort: effort(5_000, 1_480), previousSeconds: 1_500, previousStart: Date(timeIntervalSince1970: 86_400))])
        #expect(result[3]?.records.isEmpty == true)
    }

    @Test func severalRecordsInOneRunComeFromLongestToShortest() {
        let result = PersonalRecords.timeline([
            run(1, day: 1, [effort(1_000, 260, .segment), effort(5_000, 1_450, .segment), effort(21_097.5, 6_700)]),
            run(2, day: 2, [effort(1_000, 250, .segment), effort(5_000, 1_400, .segment), effort(21_097.5, 6_600)]),
        ])
        #expect(result[2]?.records.map(\.effort.meters) == [21_097.5, 5_000, 1_000])
    }

    @Test func firstTimeAtADistanceAfterOtherRuns() {
        let result = PersonalRecords.timeline([
            run(1, day: 1, [effort(5_000, 1_500)]),
            run(2, day: 2, [effort(5_000, 1_550, .segment), effort(21_097.5, 6_730)]),
        ])
        #expect(result[2]?.records == [RecordHit(effort: effort(21_097.5, 6_730), previousSeconds: nil)])
        #expect(result[2]?.records.first?.isFirst == true)
    }

    @Test func firstRunWithSeveralDistancesHasNoRecords() {
        let result = PersonalRecords.timeline([
            run(1, day: 1, [effort(1_000, 287, .segment), effort(3_000, 868, .segment), effort(5_000, 1_451, .segment), effort(10_000, 2_917, .segment)]),
        ])
        #expect(result[1] == nil)
    }

    @Test func nearRecordWithinTwoPercentOnlyWithoutARecord() {
        let result = PersonalRecords.timeline([
            run(1, day: 1, [effort(5_000, 1_421)]),
            run(2, day: 2, [effort(5_000, 1_429)]),
            run(3, day: 3, [effort(5_000, 1_460)]),
        ])
        #expect(result[2]?.near == RecordNear(effort: effort(5_000, 1_429), bestSeconds: 1_421))
        #expect(result[2]?.near?.gapSeconds == 8)
        #expect(result[3] == nil)
    }

    @Test func progressionListsEachImprovementUpToTheRun() {
        let runs = [
            run(1, day: 1, [effort(5_000, 1_510)]),
            run(2, day: 2, [effort(5_000, 1_530)]),
            run(3, day: 3, [effort(5_000, 1_470)]),
            run(4, day: 4, [effort(5_000, 1_421)]),
        ]
        #expect(PersonalRecords.progression(runs, meters: 5_000, through: 3).map(\.seconds) == [1_510, 1_470])
        #expect(PersonalRecords.progression(runs, meters: 5_000, through: 4).map(\.activityId) == [1, 3, 4])
    }

    @Test func standingsKeepTheBestOfEachDistance() {
        let standings = PersonalRecords.standings([
            run(1, day: 1, [effort(5_000, 1_500)]),
            run(2, day: 2, [effort(5_000, 1_450), effort(1_000, 250, .segment)]),
        ])
        #expect(standings.map(\.meters) == [1_000, 5_000])
        #expect(standings.first { $0.meters == 5_000 }?.activityId == 2)
    }

    @Test func distancesIncludeThreeKilometers() {
        #expect(PersonalRecordsConstants.distances == [1_000, 3_000, 5_000, 10_000, 21_097.5, 42_195])
        #expect(PersonalRecordsConstants.segmentDistances.contains(3_000))
        #expect(PersonalRecordsConstants.effortsVersion == 2)
    }
}
