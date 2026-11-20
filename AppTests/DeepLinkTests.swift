import Foundation
import Testing
@testable import trAIning

@MainActor @Suite struct DeepLinkTests {
    private func link(_ text: String) -> DeepLink? {
        DeepLink(url: URL(string: text)!)
    }

    @Test func parsesEveryNotificationLink() {
        #expect(link("training://hoje/prontidao") == .readiness)
        #expect(link("training://hoje") == .section(.today))
        #expect(link("training://ajustes") == .section(.settings))
        #expect(link("training://provas") == .section(.races))
        #expect(link(DeepLink.workoutURL(123)) == .workout(123))
        #expect(link("training://treinos") == .section(.workouts))
        #expect(link(DeepLinkConstants.trainerStrength) == .trainer(.strength))
        #expect(link(DeepLinkConstants.trainerChanges) == .trainer(.changes))
        #expect(link("https://training.aglv.dev") == nil)
    }

    @Test func centerKeepsTheLinkUntilTheScreenTakesIt() {
        let center = DeepLinkCenter()
        center.open(URL(string: DeepLink.workoutURL(7))!)
        #expect(center.take { $0 == .readiness } == nil)
        #expect(center.pending == .workout(7))
        #expect(center.take { if case .workout = $0 { true } else { false } } == .workout(7))
        #expect(center.pending == nil)
    }
}
