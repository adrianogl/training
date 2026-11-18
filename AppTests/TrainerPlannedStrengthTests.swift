import Foundation
import GarminAPI
import Insights
import Testing
import TrainingCore
@testable import trAIning

@MainActor
@Suite struct TrainerPlannedStrengthTests {
    @Test func idIsStablePerSessionAndDayAndNeverClashesWithMFIT() {
        let session = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let monday = Day(iso: "2026-11-23")!
        let first = TrainerModel.plannedStrengthId(sessionId: session, day: monday)
        #expect(first == TrainerModel.plannedStrengthId(sessionId: session, day: monday))
        #expect(first != TrainerModel.plannedStrengthId(sessionId: session, day: monday.adding(days: 7)))
        #expect(first < 0)
    }
}
