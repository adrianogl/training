import Foundation
import GarminAPI
import TrainingCore

enum GarminReadinessCache {
    static func cached(day: Day, defaults: UserDefaults = .standard) -> GarminReadinessScore? {
        let stored = defaults.data(forKey: AppConstants.garminReadinessDefaultsKey)
            .flatMap { try? JSONDecoder().decode(GarminReadinessScore.self, from: $0) }
        return stored?.day == day.iso ? stored : nil
    }

    static func refresh(client: GarminAccountClient?, day: Day, defaults: UserDefaults = .standard) async -> GarminReadinessScore? {
        guard let client else { return cached(day: day, defaults: defaults) }
        do {
            guard let score = try await GarminReadiness.fetch(client: client, day: day) else { return cached(day: day, defaults: defaults) }
            defaults.set(try? JSONEncoder().encode(score), forKey: AppConstants.garminReadinessDefaultsKey)
            return score
        } catch {
            TodayConstants.logger.error("Falha ao buscar a prontidão da Garmin: \(String(describing: error), privacy: .public)")
            return cached(day: day, defaults: defaults)
        }
    }
}
