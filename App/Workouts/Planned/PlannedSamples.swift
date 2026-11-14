#if DEBUG
import GarminAPI
import TrainingCore

enum PlannedSamples {
    static func week(from today: Day) -> [PlannedWorkout] {
        [
            PlannedWorkout(
                id: 9_001, day: today.adding(days: 1).iso, title: "Corrida Longo exemplo", estimatedSeconds: 5_400, estimatedMeters: 20_000,
                steps: [PlannedStep(kind: .other, meters: 20_000, target: .pace(fastest: 264, slowest: 280))]
            ),
            PlannedWorkout(
                id: 9_002, day: today.adding(days: 3).iso, title: "Intervalado exemplo", estimatedSeconds: 3_300, estimatedMeters: 12_000,
                steps: [
                    PlannedStep(kind: .warmup, seconds: 900),
                    PlannedStep(kind: .other, repeats: 9, children: [
                        PlannedStep(kind: .active, meters: 1_000, target: .pace(fastest: 211, slowest: 224)),
                        PlannedStep(kind: .recovery, seconds: 120),
                    ]),
                    PlannedStep(kind: .cooldown, seconds: 600),
                ]
            ),
        ]
    }
}
#endif
