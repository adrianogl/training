import Foundation
import Testing
@testable import GarminAPI

@Suite struct TrainingStatusTests {
    @Test func readsThePhraseOfThePrimaryDevice() throws {
        let json = #"{"mostRecentTrainingStatus":{"latestTrainingStatusData":{"1":{"trainingStatusFeedbackPhrase":"RECOVERY_1","primaryTrainingDevice":false},"3483865878":{"trainingStatusFeedbackPhrase":"MAINTAINING_2","primaryTrainingDevice":true}}}}"#

        #expect(try TrainingStatus.phrase(from: Data(json.utf8)) == "MAINTAINING_2")
    }

    @Test func missingStatusIsNil() throws {
        #expect(try TrainingStatus.phrase(from: Data(#"{"mostRecentTrainingStatus":null}"#.utf8)) == nil)
    }
}
