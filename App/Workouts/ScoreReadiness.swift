import Foundation
import Storage
import Sync
import TrainingCore

enum ScoreReadiness {
    static func pending(_ record: ActivityRecord, now: Date = .now) -> ScorePending? {
        guard ActivityTypeKey.isRun(record.typeKey) else { return nil }
        guard record.fitProcessed else {
            return record.fitTransientFailures < SyncConstants.maxFitTransientFailures ? .workout : nil
        }
        return ActivityWeatherStore.awaitsWeather(record, now: now) ? .weather : nil
    }
}
