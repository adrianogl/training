import Foundation
import GarminAPI

struct PaceProStore: Sendable {
    private typealias C = RacePlanConstants

    let url: URL
    nonisolated(unsafe) let defaults: UserDefaults

    init(url: URL = AccountScope.current.paceProURL, defaults: UserDefaults = AccountScope.current.defaults) {
        self.url = url
        self.defaults = defaults
    }

    func load() -> PaceProCache {
        guard let data = try? Data(contentsOf: url), let cache = try? JSONDecoder().decode(PaceProCache.self, from: data) else { return PaceProCache() }
        return cache
    }

    func save(_ cache: PaceProCache) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func choice(race: UUID) -> Int64? {
        (defaults.dictionary(forKey: C.choiceDefaultsKey) as? [String: Int64])?[race.uuidString]
    }

    func setChoice(_ id: Int64?, race: UUID) {
        var all = defaults.dictionary(forKey: C.choiceDefaultsKey) as? [String: Int64] ?? [:]
        all[race.uuidString] = id ?? 0
        defaults.set(all, forKey: C.choiceDefaultsKey)
    }

    func cachedPlan(race: UUID, distance: Double) -> PaceProPlan? {
        let cache = load()
        guard let id = selectedId(race: race, distance: distance, summaries: cache.summaries) else { return nil }
        return cache.plans.first { $0.id == id }
    }

    func selectedId(race: UUID, distance: Double, summaries: [PaceProSummary]) -> Int64? {
        if let chosen = choice(race: race) { return chosen == 0 ? nil : chosen }
        return PacePro.match(summaries, distance: distance)?.id
    }

    func refresh(race: UUID, distance: Double, client: GarminAccountClient) async -> PaceProPlan? {
        var cache = load()
        if let summaries = try? await PacePro.summaries(client: client) { cache.summaries = summaries }
        guard let id = selectedId(race: race, distance: distance, summaries: cache.summaries) else { save(cache); return nil }
        if let plan = try? await PacePro.plan(id: id, client: client) {
            cache.plans.removeAll { $0.id == id }
            cache.plans.append(plan)
        }
        save(cache)
        return cache.plans.first { $0.id == id }
    }
}
