import Testing
@testable import trAIning

@Suite struct SyncEngineConfigurationTests {
    @Test func launchSyncLimitsFITAndSettingsSyncDoesNot() {
        #expect(SyncEngineConfiguration(trigger: .launch).fitLimit == AppConstants.launchFITLimit)
        #expect(AppConstants.launchFITLimit == 25)
        #expect(SyncEngineConfiguration(trigger: .settings).fitLimit == nil)
    }
}
