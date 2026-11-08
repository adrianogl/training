import FITReader
import Testing
import WorkoutAnalysis
@testable import trAIning

@Suite struct KmSplitsTests {
    @Test func splitsSamplesByKilometerWithPartialTail() {
        let samples = WorkoutDetailFixtures.samples(kilometers: 2.5, secondsPerKm: 300)
        let zones = HeartRateZones(floors: [100, 120, 140, 160, 180])

        let blocks = KmSplits.blocks(samples, zones: zones)

        #expect(blocks.map(\.label) == ["Km 1", "Km 2", "Km 3"])
        #expect(abs(blocks[0].seconds - 300) < 1)
        #expect(abs(blocks[0].distance - 1_000) < 1)
        #expect(abs(blocks[2].distance - 500) < 20)
        #expect(blocks.allSatisfy { $0.status == .noTarget && $0.kind == .active && $0.laps.count == 1 })
        #expect(blocks[0].dominantZone == 3)
        #expect(blocks[0].avgSpeed.map { abs($0 - 1_000.0 / 300) < 0.01 } == true)
    }

    @Test func ignoresTinyTailAndEmptySamples() {
        #expect(KmSplits.blocks([], zones: nil).isEmpty)
        let blocks = KmSplits.blocks(WorkoutDetailFixtures.samples(kilometers: 2.02, secondsPerKm: 300), zones: nil)
        #expect(blocks.count == 2)
        #expect(blocks[0].dominantZone == nil)
    }
}
