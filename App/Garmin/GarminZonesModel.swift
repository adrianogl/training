import Foundation
import GarminAPI
import Metrics
import Observation
import SwiftData
import Sync
import TrainingCore

@MainActor @Observable final class GarminZonesModel {
    private typealias C = GarminZonesConstants

    private(set) var threshold: Int?
    private(set) var upperFloors: [Int] = []
    private(set) var updatedAt: Date?
    private(set) var failed = false
    private(set) var isWorking = false
    var enabled: Bool {
        didSet { defaults.set(enabled, forKey: C.enabledDefaultsKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        self.enabled = defaults.object(forKey: C.enabledDefaultsKey) as? Bool ?? true
        self.updatedAt = (defaults.object(forKey: C.updatedAtDefaultsKey) as? Double).map(Date.init(timeIntervalSince1970:))
    }

    func load(container: ModelContainer, today: Day = Day.today()) {
        let context = ModelContext(container)
        threshold = (try? thresholdHeartRates(on: [today], in: context))?[today]
        upperFloors = threshold.map { Array(thresholdZones(thresholdHeartRate: $0).floors.dropFirst()) } ?? []
    }

    func sync(container: ModelContainer, client: GarminAccountClient?) async {
        load(container: container)
        guard enabled, !isWorking, let client, let threshold, upperFloors.count == C.zoneNames.count else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let profiles = try await HeartRateZoneProfiles.fetch(client: client)
            if let updated = HeartRateZoneProfiles.applying(upperFloors: upperFloors, threshold: threshold, to: profiles) {
                try await HeartRateZoneProfiles.save(updated, client: client)
                let saved = try await HeartRateZoneProfiles.fetch(client: client)
                guard HeartRateZoneProfiles.running(in: saved)?.upperFloors == upperFloors.map(Optional.some) else {
                    failed = true
                    return
                }
                markUpdated()
            } else if updatedAt == nil {
                markUpdated()
            }
            failed = false
        } catch {
            failed = true
        }
    }

    func ranges() -> [(name: String, text: String)] {
        guard upperFloors.count == C.zoneNames.count else { return [] }
        return C.zoneNames.indices.map { index in
            let text = index == upperFloors.count - 1
                ? String(format: C.lastFormat, upperFloors[index])
                : String(format: C.rangeFormat, upperFloors[index], upperFloors[index + 1] - 1)
            return (C.zoneNames[index], text)
        }
    }

    private func markUpdated() {
        let now = Date.now
        updatedAt = now
        defaults.set(now.timeIntervalSince1970, forKey: C.updatedAtDefaultsKey)
    }
}
