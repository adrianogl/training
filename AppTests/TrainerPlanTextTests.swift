import Insights
import Testing
@testable import trAIning

@Suite struct TrainerPlanTextTests {
    @Test func formatsWeekProgressOnlyInsideThePlan() {
        #expect(TrainerText.weekProgress(index: 3, total: 24) == "semana 3 de 24")
        #expect(TrainerText.weekProgress(index: nil, total: 24) == nil)
        #expect(TrainerText.weekProgress(index: 1, total: 0) == nil)
    }
}
