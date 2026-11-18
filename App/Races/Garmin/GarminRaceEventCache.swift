import Foundation
import GarminAPI
import TrainingCore

actor GarminRaceEventCache {
    static let shared = GarminRaceEventCache()
    private var cached: (events: [GarminRaceEvent], at: Date)?

    func events(client: GarminAccountClient, today: Day) async -> [GarminRaceEvent]? {
        if let cached, Date.now.timeIntervalSince(cached.at) < GarminRaceConstants.cacheTTL { return cached.events }
        guard let events = try? await GarminRaceEvents.upcoming(client: client, from: today) else { return cached?.events }
        cached = (events, .now)
        return events
    }
}
