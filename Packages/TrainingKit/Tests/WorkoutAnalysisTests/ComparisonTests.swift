import Testing
import TrainingCore
@testable import WorkoutAnalysis

private func block(_ kind: BlockKind, _ label: String, seconds: Double, distance: Double, heartRate: Int?) -> WorkoutBlock {
    WorkoutBlock(
        kind: kind,
        ordinal: 1,
        label: label,
        prescribed: nil,
        laps: [],
        seconds: seconds,
        distance: distance,
        avgSpeed: seconds > 0 ? distance / seconds : nil,
        avgHeartRate: heartRate,
        maxHeartRate: heartRate.map { $0 + 10 },
        dominantZone: nil,
        status: .noTarget
    )
}

private func intervals(activeSeconds: Double, heartRate: Int) -> [WorkoutBlock] {
    [
        block(.warmup, "Aquecimento", seconds: 600, distance: 1800, heartRate: 130),
        block(.active, "Tiro 1", seconds: activeSeconds, distance: 1000, heartRate: heartRate),
        block(.recovery, "Recuperação 1", seconds: 120, distance: 300, heartRate: 140),
        block(.active, "Tiro 2", seconds: activeSeconds * 2, distance: 2000, heartRate: heartRate + 4),
        block(.cooldown, "Desaquecimento", seconds: 600, distance: 1700, heartRate: 125),
    ]
}

private func occurrence(_ id: Int64, day: Int, _ blocks: [WorkoutBlock]) -> WorkoutOccurrence {
    WorkoutOccurrence(activityId: id, day: Day(year: 2026, month: 10, day: day), blocks: blocks)
}

@Test func compareSameStructure() throws {
    let current = occurrence(100, day: 30, intervals(activeSeconds: 240, heartRate: 160))
    let previous = [
        occurrence(90, day: 23, intervals(activeSeconds: 245, heartRate: 162)),
        occurrence(70, day: 9, intervals(activeSeconds: 260, heartRate: 168)),
        occurrence(80, day: 16, intervals(activeSeconds: 250, heartRate: 165)),
    ]

    let comparison = try #require(compare(current: current, previous: previous))

    #expect(comparison.sameStructure)
    #expect(comparison.occurrences == [100, 90, 80, 70])
    #expect(comparison.blocks.map(\.label) == ["Aquecimento", "Tiro 1", "Recuperação 1", "Tiro 2", "Desaquecimento"])
    #expect(comparison.blocks[1].values[70]?.heartRate == 168)
    #expect(comparison.blocks[1].values[100]?.status == .noTarget)
    let speedDelta = try #require(comparison.activeSpeedDelta)
    #expect(abs(speedDelta - (3000.0 / 720 - 3000.0 / 780)) < 0.0001)
    let heartRateDelta = try #require(comparison.activeHeartRateDelta)
    #expect(abs(heartRateDelta - (((160.0 + 2 * 164) / 3) - ((168.0 + 2 * 172) / 3))) < 0.0001)
}

@Test func compareDifferentStructureFlags() throws {
    let current = occurrence(100, day: 30, intervals(activeSeconds: 240, heartRate: 160))
    let shorter = [
        block(.warmup, "Aquecimento", seconds: 600, distance: 1800, heartRate: 130),
        block(.active, "Tiro 1", seconds: 250, distance: 1000, heartRate: 166),
        block(.cooldown, "Desaquecimento", seconds: 600, distance: 1700, heartRate: 125),
    ]

    let comparison = try #require(compare(current: current, previous: [occurrence(90, day: 23, shorter)]))

    #expect(!comparison.sameStructure)
    #expect(comparison.blocks.map(\.label) == ["Aquecimento", "Tiro 1", "Desaquecimento"])
    #expect(abs((comparison.activeSpeedDelta ?? 0) - (1000.0 / 240 - 1000.0 / 250)) < 0.0001)
    #expect(comparison.activeHeartRateDelta == -6)
}

@Test func compareLimitsToFour() throws {
    let current = occurrence(100, day: 30, intervals(activeSeconds: 240, heartRate: 160))
    let previous = (1...6).map { index in
        occurrence(Int64(index), day: index, intervals(activeSeconds: 250, heartRate: 165))
    }

    let comparison = try #require(compare(current: current, previous: previous))

    #expect(comparison.occurrences.count == 5)
    #expect(comparison.occurrences == [100, 6, 5, 4, 3])
    #expect(comparison.blocks.allSatisfy { $0.values.count == 5 })
}

@Test func compareWithoutPreviousIsNil() {
    let current = occurrence(100, day: 30, intervals(activeSeconds: 240, heartRate: 160))

    #expect(compare(current: current, previous: []) == nil)
}
