import Foundation
import Testing
import WorkoutAnalysis
@testable import trAIning

@Suite struct RecordDistanceTextTests {
    private func hit(_ meters: Double, previous: Double? = 300) -> RecordHit {
        RecordHit(effort: RunEffort(meters: meters, seconds: 290, source: .wholeRun), previousSeconds: previous, previousStart: previous == nil ? nil : .now)
    }

    @Test func titlesUseTheRightPreposition() {
        #expect(RecordText.title(hit(1_000)) == "Recorde no 1 km")
        #expect(RecordText.title(hit(3_000)) == "Recorde nos 3 km")
        #expect(RecordText.title(hit(21_097.5)) == "Recorde na meia maratona")
        #expect(RecordText.title(hit(42_195)) == "Recorde na maratona")
        #expect(RecordText.title(hit(3_000, previous: nil)) == "Primeiros 3 km")
    }

    @Test func labelsAndPills() {
        #expect([1_000, 3_000, 5_000, 10_000, 21_097.5, 42_195].map(RecordText.label) == ["1 km", "3 km", "5 km", "10 km", "Meia maratona", "Maratona"])
        #expect(RecordText.pill([hit(21_097.5)]) == "RP meia")
        #expect(RecordText.pill([hit(42_195)]) == "RP maratona")
        #expect(RecordText.pill([hit(3_000)]) == "RP 3 km")
    }

    @Test func evolutionRecordsUseTheSameSixDistances() {
        #expect(EvolutionExtrasConstants.records.map(\.label) == ["1 km", "3 km", "5 km", "10 km", "Meia maratona", "Maratona"])
        #expect(EvolutionExtrasConstants.records.map(\.meters) == [1_000, 3_000, 5_000, 10_000, 21_097.5, 42_195])
    }
}
