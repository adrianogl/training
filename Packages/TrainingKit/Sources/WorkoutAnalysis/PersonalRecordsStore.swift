import Foundation
import Storage
import SwiftData
import TrainingCore

extension ActivityRecord {
    public var bestEfforts: [RunEffort] {
        bestEffortsData.flatMap { try? JSONDecoder().decode([RunEffort].self, from: $0) } ?? []
    }

    var expectedEffortsVersion: Int {
        PersonalRecordsConstants.effortsVersion * PersonalRecordsConstants.versionScale + processingVersion
    }
}

extension PersonalRecords {
    @discardableResult
    public static func refreshEfforts(in context: ModelContext) -> Bool {
        let runs = (try? context.fetch(FetchDescriptor<ActivityRecord>())) ?? []
        var changed = false
        for run in runs where ActivityTypeKey.isRun(run.typeKey) && run.bestEffortsVersion != run.expectedEffortsVersion {
            run.bestEffortsData = try? JSONEncoder().encode(efforts(record: run, samples: SampleStore.samples(run)))
            run.bestEffortsVersion = run.expectedEffortsVersion
            changed = true
        }
        if changed { try? context.save() }
        return changed
    }

    public static func runEfforts(_ records: [ActivityRecord]) -> [RunEfforts] {
        records.filter { ActivityTypeKey.isRun($0.typeKey) }.map { RunEfforts(activityId: $0.activityId, start: $0.start, efforts: $0.bestEfforts) }
    }

    public static func timeline(in context: ModelContext) -> [Int64: RunRecords] {
        timeline(runEfforts((try? context.fetch(FetchDescriptor<ActivityRecord>())) ?? []))
    }
}
