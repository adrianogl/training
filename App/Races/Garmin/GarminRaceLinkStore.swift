import Foundation
import GarminAPI

struct GarminRaceLinkStore {
    let defaults: UserDefaults

    init(defaults: UserDefaults = AccountScope.current.defaults) {
        self.defaults = defaults
    }

    func load() -> GarminRaceLinks {
        guard let data = defaults.data(forKey: GarminRaceConstants.defaultsKey),
              let links = try? JSONDecoder().decode(GarminRaceLinks.self, from: data) else { return GarminRaceLinks() }
        return links
    }

    func recordImport(_ event: GarminRaceEvent, raceId: UUID) {
        update { $0.imported[event.id] = GarminRaceLink(raceId: raceId, event: event) }
    }

    func decline(_ eventId: Int64) {
        update { $0.declined.insert(eventId) }
    }

    func acknowledge(_ event: GarminRaceEvent) {
        update { links in links.imported[event.id]?.event = event }
    }

    private func update(_ change: (inout GarminRaceLinks) -> Void) {
        var links = load()
        change(&links)
        if let data = try? JSONEncoder().encode(links) { defaults.set(data, forKey: GarminRaceConstants.defaultsKey) }
    }
}
