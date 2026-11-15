import GarminAPI
import Insights

enum TodayWorkoutPicker {
    static func pick(
        garminToday: PlannedWorkout?,
        trainerToday: TrainerDayRow?,
        garminTomorrow: PlannedWorkout?,
        trainerTomorrow: TrainerDayRow?
    ) -> TodayWorkoutPick? {
        if let today = source(garmin: garminToday, trainer: trainerToday) {
            return TodayWorkoutPick(today: today, tomorrow: nil, strength: trainerToday?.strength ?? [])
        }
        let tomorrow = source(garmin: garminTomorrow, trainer: trainerTomorrow)
        guard trainerToday != nil || tomorrow != nil else { return nil }
        return TodayWorkoutPick(today: nil, tomorrow: tomorrow, strength: trainerToday?.strength ?? [])
    }

    private static func source(garmin: PlannedWorkout?, trainer: TrainerDayRow?) -> TodayWorkoutSource? {
        if let garmin { return .garmin(garmin) }
        guard let trainer, trainer.workout.kind != .off else { return nil }
        return .trainer(trainer)
    }
}
