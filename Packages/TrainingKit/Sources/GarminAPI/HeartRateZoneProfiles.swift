import Foundation

public enum HeartRateZoneProfiles {
    private typealias C = HeartRateZoneProfileConstants

    public static func fetch(client: GarminAccountClient) async throws -> [HRZoneProfile] {
        let data = try await client.get(C.path)
        return try JSONDecoder().decode([HRZoneProfile].self, from: data)
    }

    public static func save(_ profiles: [HRZoneProfile], client: GarminAccountClient) async throws {
        _ = try await client.put(C.path, body: try JSONEncoder().encode(profiles))
    }

    public static func running(in profiles: [HRZoneProfile]) -> HRZoneProfile? {
        profiles.first { $0.sport == C.runningSport }
    }

    public static func applying(upperFloors: [Int], threshold: Int, to profiles: [HRZoneProfile]) -> [HRZoneProfile]? {
        guard upperFloors.count == 4, let index = profiles.firstIndex(where: { $0.sport == C.runningSport }) else { return nil }
        let current = profiles[index]
        guard current.upperFloors != upperFloors.map(Optional.some) || current.lactateThresholdHeartRateUsed != threshold else { return nil }
        var updated = profiles.map { profile -> HRZoneProfile in
            var copy = profile
            copy.changeState = C.unchanged
            return copy
        }
        updated[index].lactateThresholdHeartRateUsed = threshold
        updated[index].zone2Floor = upperFloors[0]
        updated[index].zone3Floor = upperFloors[1]
        updated[index].zone4Floor = upperFloors[2]
        updated[index].zone5Floor = upperFloors[3]
        updated[index].changeState = C.changed
        return updated
    }
}
