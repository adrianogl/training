import Foundation
import GarminAPI
import Insights
import TrainingCore

extension TrainerModel {
    func plannedStrength(from first: Day, days: Int) -> [TrainerPlannedStrength] {
        (0...days).flatMap { offset -> [TrainerPlannedStrength] in
            let day = first.adding(days: offset)
            return trainerSessions(on: day).compactMap { session in
                guard let workout = strengthWorkout(sessionId: session.id, day: day), !workout.exercises.isEmpty else { return nil }
                return TrainerPlannedStrength(workout: Self.strengthWorkout(workout, sessionId: session.id, day: day), sessionId: session.id)
            }
        }
    }

    static func strengthWorkout(_ workout: GeneratedStrengthWorkout, sessionId: UUID, day: Day) -> StrengthWorkout {
        let blocks = workout.exercises.map { exercise in
            StrengthBlock(
                exercises: [StrengthExercise(
                    name: exercise.name, detail: nil, category: exercise.category, exerciseKey: exercise.exerciseName,
                    reps: exercise.reps, seconds: exercise.seconds.map(Double.init), weight: exercise.weight
                )],
                sets: exercise.sets, restSeconds: Double(exercise.restSeconds)
            )
        }
        return StrengthWorkout(id: plannedStrengthId(sessionId: sessionId, day: day), day: day.iso, title: TrainerStrengthText.focusName(workout.group), blocks: blocks)
    }

    static func plannedStrengthId(sessionId: UUID, day: Day) -> Int64 {
        let text = sessionId.uuidString + "|" + day.iso
        let hash = text.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
        return -Int64(bitPattern: hash & 0x7FFF_FFFF_FFFF_FFFF) - 1
    }
}
