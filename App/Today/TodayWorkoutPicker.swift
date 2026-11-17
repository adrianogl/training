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

    static func pending(_ plans: [PlannedWorkout], doneTitles: [String]) -> [PlannedWorkout] {
        var remaining = plans
        var unmatched = 0
        for title in doneTitles {
            if let index = remaining.firstIndex(where: { $0.title.caseInsensitiveCompare(title) == .orderedSame }) {
                remaining.remove(at: index)
            } else {
                unmatched += 1
            }
        }
        return Array(remaining.dropFirst(unmatched))
    }

    private static func source(garmin: PlannedWorkout?, trainer: TrainerDayRow?) -> TodayWorkoutSource? {
        if let garmin { return .garmin(garmin) }
        guard let trainer, trainer.workout.kind != .off, trainer.run == nil else { return nil }
        return .trainer(trainer)
    }
}
