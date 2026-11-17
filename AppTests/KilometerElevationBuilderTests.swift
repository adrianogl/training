import FITReader
import Testing
import WorkoutAnalysis
@testable import trAIning

@Suite struct KilometerElevationBuilderTests {
    private static func kilometer(pace: Double, climb: Double?, descent: Double?) -> WorkoutBlock {
        let lap = LapSummary(startOffset: 0, timerSeconds: pace, distance: 1_000, avgSpeed: 1_000 / pace, climb: climb, descent: descent)
        return WorkoutBlock(kind: .active, ordinal: 1, label: "km 2", prescribed: nil, laps: [lap], seconds: pace, distance: 1_000, avgSpeed: 1_000 / pace, avgHeartRate: nil, maxHeartRate: nil, dominantZone: nil, status: .noTarget)
    }

    @Test func climbShowsTheFlatPace() {
        let elevation = KilometerElevationBuilder.elevation(Self.kilometer(pace: 316, climb: 30, descent: 6))

        #expect(elevation == KilometerElevation(climb: 30, descent: 6, flatPace: "4:50"))
    }

    @Test func flatOrMissingAltitudeShowsNothing() {
        #expect(KilometerElevationBuilder.elevation(Self.kilometer(pace: 286, climb: 2, descent: 1)) == nil)
        #expect(KilometerElevationBuilder.elevation(Self.kilometer(pace: 286, climb: nil, descent: nil)) == nil)
    }
}
