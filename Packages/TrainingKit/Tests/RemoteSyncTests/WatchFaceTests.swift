import Foundation
import Testing
@testable import RemoteSync

@Suite struct WatchFaceTests {
    @Test func clampsToServerLimits() {
        let face = WatchFace(
            vo2Delta: 30,
            weekPlannedKm: -2,
            workout: String(repeating: "a", count: 50),
            workoutShape: [[0, 9], [150, 0]] + Array(repeating: [1, 1], count: 30),
            raceName: "",
            raceGoal: 0,
            racePrediction: 6_000
        )

        #expect(face.vo2Delta == 20)
        #expect(face.weekPlannedKm == 0)
        #expect(face.workout?.count == 40)
        #expect(face.workoutShape?.count == 24)
        #expect(face.workoutShape?.prefix(2).map { $0 } == [[1, 5], [100, 1]])
        #expect(face.raceName == nil)
        #expect(face.raceGoal == nil)
        #expect(face.racePrediction == 6_000)
    }

    @Test func readinessWithoutFaceOmitsKey() throws {
        let body = try String(decoding: JSONEncoder().encode(WatchReadiness(day: "2026-11-13", score: 62, verdict: "Moderado")), as: UTF8.self)

        #expect(!body.contains("face"))
    }
}
