import Foundation
import GarminAPI
import Testing
import TrainingCore
import WorkoutKit
@testable import trAIning

@Suite struct AppleWorkoutBuilderTests {
    private let day = Day(iso: "2026-11-25")!

    @Test func thresholdRunBecomesWarmupRepeatsAndCooldown() throws {
        let steps: [PlannedRunStep] = [
            .warmup(meters: 2000),
            .repeated(times: 3, steps: [.interval(meters: 2000, fastest: 295, slowest: 305), .recovery(meters: 400)]),
            .cooldown(meters: 1000),
        ]
        let item = TrainerSendItem(key: "run|x", day: day, kind: .run, title: "Limiar 3 × 2 km", payload: Data(), runSteps: steps)
        let workout = try #require(AppleWorkoutBuilder.run(item))
        #expect(workout.displayName == "Limiar 3 × 2 km")
        #expect(workout.warmup?.goal == .distance(2000, .meters))
        #expect(workout.cooldown?.goal == .distance(1000, .meters))
        #expect(workout.blocks.count == 1)
        #expect(workout.blocks[0].iterations == 3)
        #expect(workout.blocks[0].steps.count == 2)
        #expect(workout.blocks[0].steps[0].purpose == .work)
        #expect(workout.blocks[0].steps[1].purpose == .recovery)
        #expect(workout.blocks[0].steps[0].step.alert != nil)
    }

    @Test func paceRangeConvertsToSpeed() throws {
        let alert = try #require(AppleWorkoutBuilder.paceAlert(fastest: 250, slowest: 400))
        #expect(alert.target.lowerBound.converted(to: .metersPerSecond).value == 2.5)
        #expect(alert.target.upperBound.converted(to: .metersPerSecond).value == 4)
        #expect(AppleWorkoutBuilder.paceAlert(fastest: nil, slowest: 300) == nil)
    }

    @Test func strengthGoesAsTimedStrengthWorkout() throws {
        let item = TrainerSendItem(key: "strength|x", day: day, kind: .strength, title: "Força A", payload: Data(), strengthSeconds: 2350)
        let workout = try #require(AppleWorkoutBuilder.strength(item))
        #expect(workout.activity == .traditionalStrengthTraining)
        #expect(workout.goal == .time(40, .minutes))
    }

    @Test func scheduledMorningOfTheDayAndStableId() {
        #expect(AppleWorkoutBuilder.date(day) == DateComponents(year: 2026, month: 11, day: 25, hour: TrainerSendConstants.scheduledHour))
        let plan = WorkoutPlan(.goal(SingleGoalWorkout(activity: .running, goal: .open)), id: UUID(uuidString: "00000000-0000-0001-0000-000000000000")!)
        #expect(AppleWorkoutBuilder.id(plan) == 1)
    }
}
