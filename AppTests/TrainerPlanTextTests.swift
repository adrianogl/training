import Insights
import Testing
@testable import trAIning

@Suite struct TrainerPlanTextTests {
    @Test func formatsWeekProgressOnlyInsideThePlan() {
        #expect(TrainerText.weekProgress(index: 3, total: 24) == "semana 3 de 24")
        #expect(TrainerText.weekProgress(index: nil, total: 24) == nil)
        #expect(TrainerText.weekProgress(index: 1, total: 0) == nil)
    }

    @Test func summarizesPlanAdjustments() {
        let sessions = [
            TrainerStrengthSession(weekday: 2, group: .lower, legLoad: .heavy, name: "Inferiores"),
            TrainerStrengthSession(weekday: 4, group: .upper, legLoad: .light, name: "Superiores"),
        ]

        #expect(TrainerText.adjustmentsSummary(strength: sessions, longMode: .blocks) == "Força 2×/semana · Longão em blocos · Paces · Pedir readequação")
        #expect(TrainerText.adjustmentsSummary(strength: [], longMode: .continuous) == "Força · Longão contínuo · Paces · Pedir readequação")
    }
}
