import Foundation
import GarminAPI
import Insights
import MFIT
import TrainingCore

enum MFITSendBuilder {
    private typealias C = TrainerSendConstants

    static func end(_ program: MFITProgram, today: Day) -> Day {
        program.end.flatMap(Day.init(iso:)) ?? today.adding(days: C.mfitDaysWithoutEnd)
    }

    static func exercises(_ blocks: [StrengthBlock], catalogId: (String) -> String?) -> [PlannedStrengthExercise] {
        blocks.flatMap { block in
            block.exercises.map { exercise in
                let catalog = catalogId(exercise.name).flatMap(StrengthCatalog.exercise)
                return PlannedStrengthExercise(
                    description: exercise.name,
                    category: catalog?.category ?? StrengthCatalog.garminCategory(exercise.category ?? C.mfitFallbackCategory),
                    exerciseName: catalog?.exerciseName, sets: max(block.sets, 1), reps: exercise.reps,
                    seconds: exercise.seconds.map { Int($0.rounded()) }, restSeconds: Int((block.restSeconds ?? 0).rounded()), weight: exercise.weight
                )
            }
        }
    }

    static func items(workouts: [StrengthWorkout], replaced: (Day) -> Bool, catalogId: (String) -> String?) -> [TrainerSendItem] {
        workouts.compactMap { workout in
            guard let day = Day(iso: workout.day), !replaced(day) else { return nil }
            let title = workout.title
            let exercises = exercises(workout.blocks, catalogId: catalogId)
            guard !exercises.isEmpty, let payload = try? GarminPlannedPayload.strength(name: title, exercises: exercises) else { return nil }
            var item = TrainerSendItem(
                key: C.mfitKeyPrefix + workout.day + "|" + String(workout.id), day: day, kind: .strength, title: title, payload: payload,
                strengthSeconds: seconds(exercises)
            )
            item.isMFIT = true
            return item
        }
    }

    static func catalogId(forMFITName name: String) -> String? {
        if case .catalog(let id) = ExerciseMediaCatalog.shared.key(forMFITName: name, category: nil) { return id }
        return nil
    }

    private static func seconds(_ exercises: [PlannedStrengthExercise]) -> Double {
        exercises.reduce(0) { total, exercise in
            let work = Double(exercise.seconds ?? (exercise.reps ?? 0) * C.secondsPerRep)
            return total + Double(exercise.sets) * (work + Double(exercise.restSeconds))
        }
    }
}
