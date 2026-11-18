import Testing
import WorkoutAnalysis
@testable import Narrative

private let heatFacts = [
    FindingFact.temperature: 28.2,
    FindingFact.dewPoint: 20.6,
    FindingFact.weatherFactor: 0.0483,
    FindingFact.pace: 336,
    FindingFact.mildPace: 320.5,
    FindingFact.count: 1,
]

@Test func weatherSlowerTextsNameDegreesAndMildPace() {
    let finding = Finding(group: .positive, kind: .weatherSlower, blockOrdinal: nil, facts: heatFacts)

    #expect(TemplateNarrator.text(finding, blocks: []) == "Com 28 °C, orvalho 21 °C, o ritmo de 5:36/km equivale a 5:21/km em clima ameno.")
    #expect(FindingDetail.evidence(finding, blocks: []) == "5:36 → 5:21 /km · 28 °C, orvalho 21 °C")
    #expect(FindingDetail.why(finding, blocks: []).contains("4,8% mais lento"))
}

@Test func coldWeatherSlowerOmitsDewPoint() {
    var facts = heatFacts
    facts[FindingFact.temperature] = -4
    facts[FindingFact.cold] = 1
    facts[FindingFact.weatherFactor] = 0.009
    let finding = Finding(group: .positive, kind: .weatherSlower, blockOrdinal: nil, facts: facts)

    #expect(FindingDetail.why(finding, blocks: []).hasPrefix("Com -4 °C, o frio deixa o ritmo 0,9% mais lento"))
}

@Test func driftWithWeatherIsExplainedAsExpected() {
    let finding = Finding(group: .positive, kind: .cardiacDrift, blockOrdinal: 0, facts: [
        FindingFact.rise: 0.07, FindingFact.fromHR: 151, FindingFact.toHR: 162,
        FindingFact.temperature: 28, FindingFact.dewPoint: 21, FindingFact.weatherFactor: 0.048,
    ])

    #expect(FindingDetail.why(finding, blocks: []).hasPrefix("Com 28 °C, orvalho 21 °C, a FC sobe"))
    #expect(TemplateNarrator.text(finding, blocks: []).hasSuffix("Esperado com 28 °C, orvalho 21 °C."))
}
