import FITReader
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
        (try? runningZonesRecord(in: container.mainContext))?.maxHeartRate
    }

    var zoneBands: [TrainerZoneBand] {
        TrainerZones.bands(thresholdHeartRate: thresholdHeartRate, paces: plan?.paces)
    }

    func realZonePaces() async -> [Int: Double] {
        guard let threshold = thresholdHeartRate else { return [:] }
        let container = container
        let since = Calendar.current.date(byAdding: .day, value: -TrainerZoneGuideConstants.realPaceDays, to: .now) ?? .distantPast
        return await Task.detached(priority: .utility) {
            let descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.start >= since })
            let runs = ((try? ModelContext(container).fetch(descriptor)) ?? [])
                .filter { ActivityTypeKey.isRun($0.typeKey) }
                .compactMap { $0.samplesData.flatMap(FITSampleCoding.decode) }
            return TrainerZones.realPaces(runs, thresholdHeartRate: threshold)
        }.value
    }
}
