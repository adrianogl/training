import Foundation
import Insights
import Storage
import Sync
import SwiftData
import TrainingCore

extension TrainerModel {
    var thresholdHeartRate: Int? {
        let day = currentDay
        return (try? thresholdHeartRates(on: [day], in: container.mainContext))?[day]
    }

    var maxHeartRate: Int? {
        try? estimatedMaxHeartRate(on: currentDay, in: container.mainContext)
    }

    var zoneBands: [TrainerZoneBand] {
        TrainerZones.bands(thresholdHeartRate: thresholdHeartRate, paces: plan?.paces)
    }

    var zoneTrendKey: TrainerZoneTrendKey {
        TrainerZoneTrendKey(
            day: currentDay, runCount: history.runs.count, lastRunId: history.runs.map(\.activityId).max(), target: plan?.target,
            overrides: plan?.paceOverrides ?? [:]
        )
    }

    func zoneTrend() async -> TrainerZoneTrend {
        let key = zoneTrendKey
        if let cached = zoneTrendCache, cached.key == key { return cached.value }
        let container = container
        let value = await Task.detached(priority: .utility) {
            TrainerZoneTrendLoader.load(container: container, today: key.day, target: key.target, overrides: key.overrides)
        }.value
        zoneTrendCache = (key, value)
        return value
    }
}
