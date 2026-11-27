import Foundation
@testable import GarminAPI
import Testing

@Suite struct PlannedStridesTests {
    private func group(_ repeats: Int, meters: Double, back: PlannedStep) -> PlannedStep {
        PlannedStep(kind: .other, repeats: repeats, children: [PlannedStep(kind: .active, meters: meters, target: .pace(fastest: 212, slowest: 218)), back])
    }

    @Test func shortRepsWithAWalkBackOfTheSameDistanceAreStrides() {
        #expect(group(4, meters: 100, back: PlannedStep(kind: .recovery, meters: 100)).isStrides)
    }

    @Test func intervalsAndClosingRepsAreNotStrides() {
        #expect(!group(3, meters: 200, back: PlannedStep(kind: .recovery, meters: 200)).isStrides)
        #expect(!group(5, meters: 100, back: PlannedStep(kind: .rest, seconds: 60)).isStrides)
        #expect(!group(1, meters: 100, back: PlannedStep(kind: .recovery, meters: 100)).isStrides)
        #expect(!PlannedStep(kind: .active, meters: 100).isStrides)
    }
}
