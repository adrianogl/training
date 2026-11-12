import FITReader
import Foundation
import Storage
import SwiftData
import Testing
@testable import trAIning

@MainActor
@Suite struct SyncEngineConfigurationTests {
    private static func activity(id: Int64, typeKey: String = "running", fitProcessed: Bool = true, version: Int) -> ActivityRecord {
        ActivityRecord(
            activityId: id, typeKey: typeKey, name: "Corrida", start: Date(timeIntervalSince1970: 1_700_000_000),
            fitProcessed: fitProcessed, processingVersion: version
        )
    }

    @Test func launchSyncLimitsFITAndSettingsSyncDoesNot() {
        #expect(SyncEngineConfiguration(trigger: .launch).fitLimit == AppConstants.launchFITLimit)
        #expect(AppConstants.launchFITLimit == 25)
        #expect(SyncEngineConfiguration(trigger: .settings).fitLimit == nil)
    }

    @Test func pullSyncDropsFITLimitOnlyWhileRunsAreOutdated() {
        #expect(SyncEngineConfiguration(trigger: .pull).fitLimit == AppConstants.launchFITLimit)
        #expect(SyncEngineConfiguration(trigger: .pull, hasOutdatedRuns: true).fitLimit == nil)
        #expect(SyncEngineConfiguration(trigger: .pull, hasOutdatedRuns: true).mode == .foreground)
        #expect(SyncEngineConfiguration(trigger: .launch, hasOutdatedRuns: true).fitLimit == AppConstants.launchFITLimit)
    }

    @Test func outdatedRunsAreProcessedRunsWithOlderVersion() throws {
        let current = FITReaderConstants.processingVersion
        let container = try TrainingSchema.container(inMemory: true)
        let context = container.mainContext
        context.insert(Self.activity(id: 1, version: current))
        context.insert(Self.activity(id: 2, fitProcessed: false, version: 0))
        context.insert(Self.activity(id: 3, typeKey: "cycling", version: current - 1))
        try context.save()
        #expect(try SyncEngineConfiguration.hasOutdatedRuns(in: context) == false)

        context.insert(Self.activity(id: 4, version: current - 1))
        try context.save()
        #expect(try SyncEngineConfiguration.hasOutdatedRuns(in: context))
    }
}
