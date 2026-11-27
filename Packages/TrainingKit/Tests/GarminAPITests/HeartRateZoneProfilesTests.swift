import Foundation
import Testing
@testable import GarminAPI

@Suite struct HeartRateZoneProfilesTests {
    private let profiles = [
        HRZoneProfile(trainingMethod: "LACTATE_THRESHOLD", lactateThresholdHeartRateUsed: 175, zone1Floor: 108, zone2Floor: 134, zone3Floor: 148, zone4Floor: 157, zone5Floor: 167, sport: "DEFAULT", changeState: "UNCHANGED"),
        HRZoneProfile(trainingMethod: "LACTATE_THRESHOLD", lactateThresholdHeartRateUsed: 163, zone1Floor: 99, zone2Floor: 122, zone3Floor: 135, zone4Floor: 147, zone5Floor: 153, sport: "RUNNING", changeState: "UNCHANGED"),
    ]

    @Test func changesOnlyTheRunningZonesAboveZoneOne() throws {
        let updated = try #require(HeartRateZoneProfiles.applying(upperFloors: [139, 147, 155, 163], threshold: 163, to: profiles))

        #expect(updated[0] == profiles[0])
        #expect(updated[1].zone1Floor == 99)
        #expect(updated[1].upperFloors == [139, 147, 155, 163])
        #expect(updated[1].changeState == "CHANGED")
    }

    @Test func sameZonesNeedNoWrite() {
        #expect(HeartRateZoneProfiles.applying(upperFloors: [122, 135, 147, 153], threshold: 163, to: profiles) == nil)
    }

    @Test func writesTheEstimatedMaxHeartRateOnlyWhenItChanges() throws {
        let updated = try #require(HeartRateZoneProfiles.applying(upperFloors: [122, 135, 147, 153], threshold: 163, maxHeartRate: 188, to: profiles))

        #expect(updated[1].maxHeartRateUsed == 188)
        #expect(updated[1].changeState == "CHANGED")
        #expect(updated[0].maxHeartRateUsed == nil)
        #expect(HeartRateZoneProfiles.applying(upperFloors: [122, 135, 147, 153], threshold: 163, maxHeartRate: 188, to: updated) == nil)
    }

    @Test func maxHeartRateBelowZoneFiveKeepsTheCurrentOne() throws {
        var current = profiles
        current[1].maxHeartRateUsed = 183

        #expect(HeartRateZoneProfiles.applying(upperFloors: [122, 135, 147, 153], threshold: 163, maxHeartRate: 150, to: current) == nil)
        let updated = try #require(HeartRateZoneProfiles.applying(upperFloors: [139, 147, 155, 163], threshold: 163, maxHeartRate: 160, to: current))
        #expect(updated[1].maxHeartRateUsed == 183)
        #expect(updated[1].upperFloors == [139, 147, 155, 163])
    }

    @Test func decodesTheGarminPayload() throws {
        let json = #"[{"trainingMethod":"LACTATE_THRESHOLD","restingHeartRateUsed":57,"lactateThresholdHeartRateUsed":163,"zone1Floor":99,"zone2Floor":122,"zone3Floor":135,"zone4Floor":147,"zone5Floor":153,"maxHeartRateUsed":183,"restingHrAutoUpdateUsed":false,"sport":"RUNNING","changeState":"UNCHANGED"}]"#

        let decoded = try JSONDecoder().decode([HRZoneProfile].self, from: Data(json.utf8))

        #expect(HeartRateZoneProfiles.running(in: decoded)?.zone5Floor == 153)
    }
}
