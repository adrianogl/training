import Foundation
import MFIT

struct StrengthProgramStore: Sendable {
    let url: URL

    init(url: URL = AccountScope.current.strengthProgramURL) {
        self.url = url
    }

    func load() -> StrengthProgramCache {
        guard let data = try? Data(contentsOf: url),
              let cache = try? JSONDecoder().decode(StrengthProgramCache.self, from: data) else { return StrengthProgramCache(program: nil, known: []) }
        return cache
    }

    func save(_ cache: StrengthProgramCache) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func clearProgram() -> StrengthProgramCache {
        let current = load()
        let cache = StrengthProgramCache(program: nil, known: current.known, loads: current.loads, watchProcessed: current.watchProcessed)
        save(cache)
        return cache
    }

    func updateLoads(_ records: [MFITLoadRecord], fetched workoutIds: Set<Int64>) -> StrengthProgramCache {
        let current = load()
        let kept = current.loads.filter { $0.fromWatch == true || !workoutIds.contains($0.workoutId) }
        let cache = StrengthProgramCache(program: current.program, known: current.known, loads: kept + records, watchProcessed: current.watchProcessed)
        save(cache)
        return cache
    }

    func replaceLiveLoads(_ records: [MFITLoadRecord], day: String, activity: Int64) -> StrengthProgramCache {
        let current = load()
        let keys = Set(records.map(\.key))
        let kept = current.loads.filter { !($0.fromWatch == true && $0.day == day && keys.contains($0.key)) }
        let processed = current.watchProcessed.contains(activity) ? current.watchProcessed : current.watchProcessed + [activity]
        let cache = StrengthProgramCache(program: current.program, known: current.known, loads: kept + records, watchProcessed: processed)
        save(cache)
        return cache
    }

    func addWatchLoads(_ records: [MFITLoadRecord], activity: Int64) -> StrengthProgramCache {
        let current = load()
        let cache = StrengthProgramCache(program: current.program, known: current.known, loads: current.loads + records, watchProcessed: current.watchProcessed + [activity])
        save(cache)
        return cache
    }

    func update(with program: MFITProgram) -> StrengthProgramCache {
        let current = load()
        var known = Dictionary(current.known.map { ($0.id, $0) }) { first, _ in first }
        for workout in program.workouts { known[workout.id] = workout }
        let cache = StrengthProgramCache(program: program, known: known.values.sorted { $0.id < $1.id }, loads: current.loads, watchProcessed: current.watchProcessed)
        save(cache)
        return cache
    }
}
