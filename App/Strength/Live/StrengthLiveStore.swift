import Foundation
import Insights

struct StrengthLiveStore {
    private let directory = URL.documentsDirectory

    func load() -> StrengthLiveSnapshot? {
        read(StrengthLiveSnapshot.self, file: StrengthLiveConstants.sessionFile)
    }

    func save(_ snapshot: StrengthLiveSnapshot) {
        write(snapshot, file: StrengthLiveConstants.sessionFile)
    }

    func nextLoads() -> [String: Double] {
        read([String: Double].self, file: StrengthLiveConstants.nextLoadsFile) ?? [:]
    }

    func saveNextLoads(_ loads: [LiveStrengthNextLoad]) {
        var known = nextLoads()
        for load in loads { known[load.loadKey] = load.next }
        write(known, file: StrengthLiveConstants.nextLoadsFile)
    }

    func bodyweightKeys() -> Set<String> {
        Set(read([String].self, file: StrengthLiveConstants.bodyweightFile) ?? [])
    }

    func setBodyweight(_ key: String, on: Bool) {
        var keys = bodyweightKeys()
        if on { keys.insert(key) } else { keys.remove(key) }
        write(keys.sorted(), file: StrengthLiveConstants.bodyweightFile)
    }

    func clear() {
        try? FileManager.default.removeItem(at: directory.appending(path: StrengthLiveConstants.sessionFile))
    }

    func sentPlans() -> [LiveStrengthPlan] {
        Array((read([String: LiveStrengthPlan].self, file: StrengthLiveConstants.plansFile) ?? [:]).values)
    }

    func sentPlan(version: String) -> LiveStrengthPlan? {
        (read([String: LiveStrengthPlan].self, file: StrengthLiveConstants.plansFile) ?? [:])[version]
    }

    func rememberSentPlans(_ plans: [LiveStrengthPlan], keepFrom day: String) {
        var known = (read([String: LiveStrengthPlan].self, file: StrengthLiveConstants.plansFile) ?? [:]).filter { $0.value.day >= day }
        for plan in plans { known[LiveStrengthWatch.version(plan)] = plan }
        write(known, file: StrengthLiveConstants.plansFile)
    }

    private func read<T: Decodable>(_ type: T.Type, file: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appending(path: file)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, file: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: directory.appending(path: file), options: .atomic)
    }
}
