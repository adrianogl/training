import Foundation
import TrainingCore

public enum GarminReadiness {
    public static func fetch(client: GarminAccountClient, day: Day) async throws -> GarminReadinessScore? {
        let data = try await client.get(GarminAccountEndpoints.trainingReadinessPathPrefix + day.iso)
        return latest(try entries(data), day: day)
    }

    static func entries(_ data: Data) throws -> [GarminReadinessDTO] {
        guard !data.isEmpty else { return [] }
        let decoder = JSONDecoder()
        if let list = try? decoder.decode([GarminReadinessDTO].self, from: data) { return list }
        return [try decoder.decode(GarminReadinessDTO.self, from: data)]
    }

    static func latest(_ entries: [GarminReadinessDTO], day: Day) -> GarminReadinessScore? {
        entries
            .filter { ($0.calendarDate ?? day.iso) == day.iso && $0.score != nil }
            .max { ($0.timestamp ?? "") < ($1.timestamp ?? "") }
            .flatMap { entry in entry.score.map { GarminReadinessScore(day: day.iso, score: min(max($0, 0), 100)) } }
    }
}
