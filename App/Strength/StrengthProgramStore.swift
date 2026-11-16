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
        let cache = StrengthProgramCache(program: nil, known: load().known)
        save(cache)
        return cache
    }

    func update(with program: MFITProgram) -> StrengthProgramCache {
        var known = Dictionary(load().known.map { ($0.id, $0) }) { first, _ in first }
        for workout in program.workouts { known[workout.id] = workout }
        let cache = StrengthProgramCache(program: program, known: known.values.sorted { $0.id < $1.id })
        save(cache)
        return cache
    }
}
