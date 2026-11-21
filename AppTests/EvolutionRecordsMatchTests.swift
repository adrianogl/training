import Foundation
import Testing
@testable import trAIning

@Suite struct EvolutionRecordsMatchTests {
    @Test func rowsMatchRecordsByDistanceNotByLabel() {
        let old = PersonalRecord(label: "21,1 km", seconds: 5_310, date: .now, source: "corrida", meters: 21_097.5, activityId: 7)
        #expect(EvolutionExtras.record(for: 21_097.5, in: [old])?.activityId == 7)
        #expect(EvolutionExtras.record(for: 42_195, in: [old]) == nil)
    }
}
