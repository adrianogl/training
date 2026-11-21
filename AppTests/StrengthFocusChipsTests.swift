import Insights
import Testing
@testable import trAIning

@Suite struct StrengthFocusChipsTests {
    @Test func focusesSplitInTwoRowsKeepingTheOrder() {
        #expect(TrainerStrengthConstants.focusRows == [[.upper, .lower, .fullBody], [.core, .mobility]])
        #expect(TrainerStrengthConstants.focusRows.flatMap { $0 } == TrainerStrengthConstants.focusOrder)
    }
}
