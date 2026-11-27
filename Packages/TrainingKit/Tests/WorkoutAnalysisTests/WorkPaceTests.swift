import Testing
@testable import WorkoutAnalysis

@Suite struct WorkPaceTests {
    @Test func shortBlocksWithPausesAreFractioned() {
        #expect(WorkPace(seconds: 980, meters: 4_000, blocks: 4, longestBlockMeters: 1_010).fractioned)
        #expect(WorkPace(seconds: 1_960, meters: 8_000, blocks: 4, longestBlockMeters: 2_030).fractioned)
        #expect(!WorkPace(seconds: 2_250, meters: 9_000, blocks: 3, longestBlockMeters: 3_000).fractioned)
        #expect(!WorkPace(seconds: 1_500, meters: 6_000).fractioned)
    }
}
