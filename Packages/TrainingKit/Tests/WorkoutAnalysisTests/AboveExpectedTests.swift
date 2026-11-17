import Testing
import TrainingCore
@testable import WorkoutAnalysis

private func block(_ kind: BlockKind, seconds: Double = 300, distance: Double = 1200, heartRate: Int?, maxHeartRate: Int? = nil) -> WorkoutBlock {
    WorkoutBlock(
        kind: kind, ordinal: 1, label: kind == .active ? "Tiro" : "Rec", prescribed: nil, laps: [],
        seconds: seconds, distance: distance, avgSpeed: seconds > 0 ? distance / seconds : nil,
        avgHeartRate: heartRate, maxHeartRate: maxHeartRate, dominantZone: nil, status: .noTarget
    )
}

private func session(activeHeartRate: Int, peak: Int = 180, recovered: Int = 150, distance: Double = 1200) -> [WorkoutBlock] {
    (0..<4).flatMap { _ in
        [block(.active, distance: distance, heartRate: activeHeartRate, maxHeartRate: peak), block(.recovery, seconds: 120, distance: 300, heartRate: recovered)]
    }
}

@Suite struct AboveExpectedTests {
    @Test func lowerHeartRateAtTheSamePace() {
        let signals = aboveExpected(session(activeHeartRate: 163), previous: [session(activeHeartRate: 168), session(activeHeartRate: 168), session(activeHeartRate: 168)])
        let signal = signals.first { $0.kind == .heartRateAtPace }
        #expect(signal == AboveExpectedSignal(kind: .heartRateAtPace, before: 168, today: 163, compared: 3))
    }

    @Test func slowerPaceDoesNotCountAsLowerHeartRate() {
        let signals = aboveExpected(session(activeHeartRate: 160, distance: 1100), previous: [session(activeHeartRate: 168), session(activeHeartRate: 168)])
        #expect(!signals.contains { $0.kind == .heartRateAtPace })
    }

    @Test func smallDifferenceIsNotAboveExpected() {
        let signals = aboveExpected(session(activeHeartRate: 166), previous: [session(activeHeartRate: 168), session(activeHeartRate: 168)])
        #expect(!signals.contains { $0.kind == .heartRateAtPace })
    }

    @Test func recoveryDropAboveTheUsual() {
        let signals = aboveExpected(session(activeHeartRate: 168, recovered: 142), previous: [session(activeHeartRate: 168, recovered: 151), session(activeHeartRate: 168, recovered: 151)])
        #expect(signals.first { $0.kind == .recoveryDrop } == AboveExpectedSignal(kind: .recoveryDrop, before: 29, today: 38, compared: 2))
    }

    @Test func needsAtLeastTwoEarlierWorkouts() {
        #expect(aboveExpected(session(activeHeartRate: 150, recovered: 130), previous: [session(activeHeartRate: 168)]).isEmpty)
    }
}
