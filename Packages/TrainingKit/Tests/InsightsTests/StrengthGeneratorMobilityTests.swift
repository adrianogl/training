import Foundation
import Testing
import TrainingCore
@testable import Insights

@Suite struct StrengthGeneratorMobilityTests {
    private func session(minutes: Int = 25, place: StrengthPlace = .gym) -> TrainerStrengthSession {
        TrainerStrengthSession(weekday: 2, group: .mobility, legLoad: .light, name: "Mobilidade", source: .trainer, intensity: .light, minutes: minutes, place: place)
    }

    @Test func mobility_session_uses_only_mobility_patterns() {
        for place in StrengthPlace.allCases {
            for minutes in [15, 25, 45] {
                let workout = StrengthGenerator.workout(for: session(minutes: minutes, place: place), context: StrengthContext())
                let allowed: Set<MovementPattern> = [.mobilityHip, .mobilityAnkle, .mobilityThoracic, .hipStability]
                #expect(!workout.exercises.isEmpty)
                #expect(workout.group == .mobility)
                #expect(workout.exercises.allSatisfy { StrengthCatalog.exercise($0.exerciseId).map { allowed.contains($0.pattern) } ?? false })
                #expect(workout.exercises.filter { StrengthCatalog.exercise($0.exerciseId)?.pattern == .hipStability }.count <= 2)
                #expect(abs(workout.estimatedMinutes - Double(minutes)) <= 5, "\(place) \(minutes): \(workout.estimatedMinutes)")
            }
        }
    }

    @Test func mobility_session_has_no_weight() {
        let loads = Dictionary(uniqueKeysWithValues: StrengthCatalog.all.map { ($0.id, StrengthLoadRecord(weight: 40, completedAllSets: true, day: "2026-11-01")) })
        let workout = StrengthGenerator.workout(for: session(), context: StrengthContext(loads: loads))
        #expect(workout.exercises.allSatisfy { $0.weight == nil && $0.suggestedLoad == nil })
        #expect(workout.intensity == .light)
    }

    @Test func old_documents_without_mobility_still_decode() throws {
        let old = #"{"id":"6F1B1E2A-1111-4222-8333-444455556666","weekday":2,"group":"core","legLoad":"light","name":"Core"}"#
        #expect(try JSONDecoder().decode(TrainerStrengthSession.self, from: Data(old.utf8)).group == .core)
        let new = #"{"id":"6F1B1E2A-1111-4222-8333-444455556666","weekday":2,"group":"mobility","legLoad":"light","name":"Mobilidade"}"#
        #expect(try JSONDecoder().decode(TrainerStrengthSession.self, from: Data(new.utf8)).group == .mobility)
    }

    @Test func mobility_leg_load_is_light() {
        for intensity in TrainerStrengthIntensity.allCases {
            #expect(StrengthSessions.legLoad(group: .mobility, intensity: intensity) == .light)
        }
    }
}
