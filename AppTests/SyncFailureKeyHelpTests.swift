import Testing
@testable import trAIning

struct SyncFailureKeyHelpTests {
    @Test func keyHelpShowsOnlyForMissingOrInvalidKey() {
        #expect(SyncFailure.missingKey.needsKeyHelp)
        #expect(SyncFailure.invalidKey.needsKeyHelp)
        #expect(!SyncFailure.offline.needsKeyHelp)
        #expect(!SyncFailure.rateLimited.needsKeyHelp)
        #expect(!SyncFailure.server(500).needsKeyHelp)
    }

    @Test func helpListsFiveStepsInOrder() {
        #expect(GarminKeyHelpConstants.steps.map(\.number) == [1, 2, 3, 4, 5])
    }
}
