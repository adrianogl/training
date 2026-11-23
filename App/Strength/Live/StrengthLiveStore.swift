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

    func sentPlans() -> [LiveStrengthPlan] {
        read([LiveStrengthPlan].self, file: StrengthLiveConstants.plansFile) ?? []
    }

    func saveSentPlans(_ plans: [LiveStrengthPlan]) {
        write(plans, file: StrengthLiveConstants.plansFile)
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
