import Foundation
import Testing
import TrainingCore
@testable import Insights

@Suite struct TrainerCycleTests {
    @Test func oldPlanJsonDecodesWithoutEndedOn() throws {
        var plan = makePlan()
        plan.endedOn = nil
        let data = try JSONEncoder().encode(plan)
        let decoded = try JSONDecoder().decode(TrainerPlan.self, from: data)
        #expect(decoded.endedOn == nil)
    }

    @Test func endedOnRoundTrips() throws {
        var plan = makePlan()
        plan.endedOn = Day(year: 2026, month: 11, day: 12)
        let decoded = try JSONDecoder().decode(TrainerPlan.self, from: JSONEncoder().encode(plan))
        #expect(decoded.endedOn == Day(year: 2026, month: 11, day: 12))
    }
}
