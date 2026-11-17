import FITReader
import Testing
@testable import WorkoutAnalysis

private func row(_ index: Int, pace: Double, climb: Double = 0, descent: Double = 0) -> WorkoutBlock {
    let lap = LapSummary(
        startOffset: Double(index) * pace, timerSeconds: pace, distance: 1000, avgSpeed: 1000 / pace,
        climb: climb, descent: descent
    )
    return WorkoutBlock(
        kind: .active, ordinal: index + 1, label: "Km \(index + 1)", prescribed: nil, laps: [lap], seconds: pace, distance: 1000,
        avgSpeed: 1000 / pace, avgHeartRate: nil, maxHeartRate: nil, dominantZone: nil, status: .noTarget
    )
}

private func run(_ rows: [WorkoutBlock]) -> WorkoutAssessment {
    let block = WorkoutBlock(
        kind: .active, ordinal: 1, label: "Bloco 1", prescribed: nil, laps: [], seconds: rows.reduce(0) { $0 + $1.seconds },
        distance: Double(rows.count) * 1000, avgSpeed: nil, avgHeartRate: nil, maxHeartRate: nil, dominantZone: nil, status: .noTarget
    )
    return assess([block], context: AssessmentContext(kilometers: [0: rows]))
}

@Suite struct ElevationPaceTests {
    @Test func climbAndDescentTurnIntoLevelPace() {
        let lap = LapSummary(startOffset: 0, timerSeconds: 316, distance: 1000, avgSpeed: 1000 / 316.0, climb: 30, descent: 6)

        #expect(abs((flatPace(lap) ?? 0) - 290.4) < 0.5)
        #expect(flatPace(316, distance: 1000, climb: 4, descent: 3) == 316)
    }

    @Test func counterIgnoresAltimeterNoise() {
        var noisy = ElevationCounter()
        for altitude in [800.0, 801, 800, 801.5, 800.5, 801] { noisy.add(altitude) }
        var hill = ElevationCounter()
        for altitude in [800.0, 803, 806, 810, 808, 805] { hill.add(altitude) }

        #expect(noisy.climb == 0 && noisy.descent == 0)
        #expect(hill.climb == 10 && hill.descent == 5)
    }

    @Test func slowLastKilometerUphillIsNotAFade() {
        let rows = (0..<10).map { row($0, pace: 285) } + [row(10, pace: 300, climb: 25)]

        let assessment = run(rows)

        #expect(!assessment.negatives.contains { $0.kind == .paceFade })
        let climb = assessment.positives.first { $0.kind == .climbSlower }
        #expect(climb?.facts[FindingFact.fromKilometer] == 11)
        #expect(climb?.facts[FindingFact.climb] == 25)
        #expect(climb?.facts[FindingFact.pace] == 300)
    }

    @Test func fadeThatSurvivesTheClimbCitesIt() {
        let rows = (0..<10).map { row($0, pace: 285) } + [row(10, pace: 320, climb: 7)]

        let fade = run(rows).negatives.first { $0.kind == .paceFade }

        #expect(fade?.facts[FindingFact.flatAdjusted] == 1)
        #expect(fade?.facts[FindingFact.lastClimb] == 7)
        #expect(fade?.facts[FindingFact.pace] == 320)
    }

    @Test func consecutiveClimbsAndADescentBecomeSegments() {
        let rows = [
            row(0, pace: 305, climb: 4, descent: 6), row(1, pace: 316, climb: 30, descent: 6), row(2, pace: 282, descent: 20),
            row(3, pace: 286), row(4, pace: 285), row(5, pace: 300, climb: 8, descent: 1), row(6, pace: 298, climb: 9),
        ]

        let positives = run(rows).positives

        let climbs = positives.filter { $0.kind == .climbSlower }
        #expect(climbs.map { $0.facts[FindingFact.fromKilometer] } == [2, 6])
        #expect(climbs.map { $0.facts[FindingFact.toKilometer] } == [2, 7])
        #expect(climbs.last?.facts[FindingFact.climb] == 17)
        let descent = positives.first { $0.kind == .descentFaster }
        #expect(descent?.facts[FindingFact.fromKilometer] == 3)
        #expect(descent?.facts[FindingFact.descent] == 20)
    }

    @Test func kilometerSplitsCarryTheAltitude() {
        let samples = (0...400).map { second in
            FITSample(t: Double(second), speed: 5, altitude: 800 + (second < 200 ? Double(second) * 0.1 : 20), distance: Double(second) * 5)
        }

        let rows = kilometerSplits(samples, zones: nil)

        #expect(rows.first?.laps.first?.climb == 20)
        #expect(rows.last?.laps.first?.climb == 0)
    }
}
