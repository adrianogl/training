import Testing
@testable import trAIning

@Suite struct PlanTextTests {
    @Test func titleDropsTheTrailingWeekdayAndDate() {
        #expect(PlanText.title("Corrida fácil qui 19/11") == "Corrida fácil")
        #expect(PlanText.title("Longão sáb. 22/11/2026") == "Longão")
        #expect(PlanText.title("Limiar 4 × 2 km") == "Limiar 4 × 2 km")
        #expect(PlanText.title("qui 19/11") == "qui 19/11")
    }

    @Test func distanceUsesKilometersFromOneKilometer() {
        #expect(PlanText.distance(10_000) == "10 km")
        #expect(PlanText.distance(1_500) == "1,5 km")
        #expect(PlanText.distance(400) == "400 m")
    }
}
