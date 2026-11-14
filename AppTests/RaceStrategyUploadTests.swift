import GarminAPI
import Metrics
import Testing
@testable import trAIning

@Suite struct RaceStrategyUploadTests {
    @Test func oneStepPerKmWithPartialLastAndBand() {
        let strategy = (0..<22).map { KmPlan(index: $0, pace: 261, grade: 0, label: "plano", manual: false) }

        let steps = RaceStrategyUpload.steps(strategy, distance: 21_097.5)

        #expect(steps.count == 22)
        #expect(steps[0] == UploadStep(meters: 1_000, fastestSecondsPerKm: 256, slowestSecondsPerKm: 266))
        #expect(abs(steps[21].meters - 97.5) < 0.01)
    }
}
