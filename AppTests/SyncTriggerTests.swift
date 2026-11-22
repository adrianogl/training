import Testing
@testable import trAIning

@Suite struct SyncTriggerTests {
    private static func runs(_ trigger: SyncTrigger, after running: SyncTrigger?) -> Bool {
        trigger.runsAfter(running)
    }

    @Test func launchAndPullRunAfterLightSync() {
        #expect(Self.runs(.launch, after: SyncTrigger.workoutFinished))
        #expect(Self.runs(.pull, after: SyncTrigger.workoutFinished))
        #expect(!Self.runs(.launch, after: SyncTrigger.background))
        #expect(!Self.runs(.pull, after: SyncTrigger.launch))
    }

    @Test func settingsRunsAfterAnythingButSettings() {
        #expect(Self.runs(.settings, after: SyncTrigger.launch))
        #expect(!Self.runs(.settings, after: SyncTrigger.settings))
        #expect(!Self.runs(.workoutFinished, after: SyncTrigger.workoutFinished))
        #expect(!Self.runs(.background, after: SyncTrigger.workoutFinished))
    }
}
