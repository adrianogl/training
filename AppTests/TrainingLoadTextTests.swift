import Testing
@testable import trAIning

@Suite struct TrainingLoadTextTests {
    private let others: [Double] = [40, 60, 80, 100, 120, 140, 160, 180, 200, 220]

    @Test func comparesWithTheRunnerOwnLoads() {
        #expect(TrainingLoadText.caption(load: 50, others: others) == "carga baixa")
        #expect(TrainingLoadText.caption(load: 130, others: others) == "carga média")
        #expect(TrainingLoadText.caption(load: 190, others: others) == "carga alta")
        #expect(TrainingLoadText.caption(load: 301, others: others) == "carga top 10%")
    }

    @Test func staysPlainWithoutEnoughHistory() {
        #expect(TrainingLoadText.caption(load: 301, others: [100, 200]) == "carga")
        #expect(TrainingLoadText.caption(load: nil, others: others) == "carga")
    }
}
