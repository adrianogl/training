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

    @Test func keepsThreeValidEventsWithTrimmedTitles() {
        let events = [
            WatchEvent(start: 0, title: "Sem horário"),
            WatchEvent(start: 1_794_908_700, title: ""),
            WatchEvent(start: 1_794_908_700, title: String(repeating: "a", count: 50)),
            WatchEvent(start: 1_794_910_000, title: "Daily MEF"),
            WatchEvent(start: 1_794_920_000, title: "Refinamento"),
            WatchEvent(start: 1_794_930_000, title: "Quarta"),
        ]

        let face = WatchFace(events: events)

        #expect(face.events?.count == 3)
        #expect(face.events?.first?.title.count == 40)
        #expect(face.events?.last?.title == "Refinamento")
        #expect(WatchFace(events: []).events == nil)
    }

    @Test func readinessWithoutFaceOmitsKey() throws {
        let body = try String(decoding: JSONEncoder().encode(WatchReadiness(day: "2026-11-13", score: 62, verdict: "Moderado")), as: UTF8.self)

        #expect(!body.contains("face"))
    }

    @Test func faceWithoutScoreOmitsScoreAndVerdict() throws {
        let readiness = WatchReadiness(day: "2026-11-14", score: nil, verdict: nil, face: WatchFace(raceName: "LIVE!21K"))
        let body = try String(decoding: JSONEncoder().encode(readiness), as: UTF8.self)

        #expect(!body.contains("score"))
        #expect(!body.contains("verdict"))
        #expect(body.contains("LIVE!21K"))
    }
}
