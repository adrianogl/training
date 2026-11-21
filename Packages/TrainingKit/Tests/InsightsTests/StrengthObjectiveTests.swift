import Foundation
import Testing
import TrainingCore
@testable import Insights

@Suite struct StrengthObjectiveTests {
    private func session(_ group: TrainerStrengthGroup, minutes: Int = 45, place: StrengthPlace = .gym) -> TrainerStrengthSession {
        TrainerStrengthSession(weekday: 2, group: group, legLoad: StrengthSessions.legLoad(group: group, intensity: .moderate), name: "x", source: .trainer, intensity: .moderate, minutes: minutes, place: place)
    }

    private func patterns(_ workout: GeneratedStrengthWorkout) -> [MovementPattern] {
        workout.exercises.compactMap { StrengthCatalog.exercise($0.exerciseId)?.pattern }
    }

    @Test func withoutObjectiveLegsStartWithSquat() {
        let workout = StrengthGenerator.workout(for: session(.lower), context: StrengthContext())
        #expect(patterns(workout).first == .squat)
    }

    @Test func performanceStartsWithRunningSpecificPatterns() {
        let workout = StrengthGenerator.workout(for: session(.lower), context: StrengthContext(objective: .performance))
        let first = Array(patterns(workout).prefix(4))
        #expect(first == [.singleLeg, .plyo, .calf, .hipStability])
        let full = StrengthGenerator.workout(for: session(.fullBody), context: StrengthContext(objective: .performance))
        #expect(patterns(full).first == .singleLeg)
        #expect(patterns(full).contains(.plyo))
    }

    @Test func maintenanceHasNoPlyometrics() {
        for group in [TrainerStrengthGroup.lower, .fullBody] {
            let workout = StrengthGenerator.workout(for: session(group), context: StrengthContext(objective: .maintenance))
            #expect(!workout.exercises.isEmpty)
            #expect(!patterns(workout).contains(.plyo))
        }
    }

    @Test func runningMobilityUsesOnlyDynamicExercises() {
        let workout = StrengthGenerator.workout(for: session(.mobility, minutes: 20, place: .home), context: StrengthContext(objective: .mobility))
        let exercises = workout.exercises.compactMap { StrengthCatalog.exercise($0.exerciseId) }
        #expect(!exercises.isEmpty)
        #expect(abs(workout.estimatedMinutes - 20) <= 5)
        #expect(exercises.allSatisfy { !$0.timed && !$0.id.contains("STRETCH") })
        let generic = StrengthGenerator.workout(for: session(.mobility, minutes: 20, place: .home), context: StrengthContext())
        #expect(generic.exercises.contains { $0.exerciseId.contains("STRETCH") })
    }

    @Test func newObjectivesDecodeAndKeepOldValues() throws {
        for objective in StrengthObjective.allCases {
            let data = try JSONEncoder().encode(objective)
            #expect(try JSONDecoder().decode(StrengthObjective.self, from: data) == objective)
        }
        #expect(StrengthObjective(rawValue: "mobility") == .mobility)
        #expect(StrengthObjective(rawValue: "performance") == .performance)
        #expect(StrengthObjective(rawValue: "maintenance") == .maintenance)
    }
}
