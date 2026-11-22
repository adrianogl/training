import Foundation
import RemoteSync
import Testing
@testable import trAIning

@Suite struct StravaImportTextTests {
    private func run(heartRate: Double?, gps: Bool) -> StravaRunCandidate {
        StravaRunCandidate(
            id: 1, name: "Longão", sportType: "Run", start: Date(timeIntervalSince1970: 1_789_207_500), startLocal: "2026-09-12T07:05:00Z",
            distanceMeters: 18_200, movingSeconds: 5_700, elapsedSeconds: 5_900, elevationGain: 120, averageHeartRate: heartRate, maxHeartRate: nil, hasGps: gps
        )
    }

    @Test func rowShowsDayDistanceAndWhatIsMissing() {
        let full = run(heartRate: 148, gps: true)
        let bare = run(heartRate: nil, gps: false)

        #expect(StravaImportText.runTitle(full).hasSuffix("12 set · Longão"))
        #expect(StravaImportText.distance(full) == "18,2 km")
        #expect(StravaImportText.detail(full).suffix(2) == ["FC 148", "GPS"])
        #expect(StravaImportText.detail(bare).suffix(2) == ["sem FC", "sem GPS"])
    }
}
