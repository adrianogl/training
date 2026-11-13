import Foundation
import Testing
import TrainingCore
@testable import GarminAPI

private let calendarJSON = """
{"calendarItems":[
 {"itemType":"workout","date":"2026-11-13","title":"Intervalado 5x1000","workoutId":10,"sportTypeKey":"running"},
 {"itemType":"workout","date":"2026-11-13","title":"Intervalado 5x1000","workoutId":10,"sportTypeKey":"running"},
 {"itemType":"workout","date":"2026-11-12","title":"Natação","workoutId":11,"sportTypeKey":"swimming"},
 {"itemType":"workout","date":"2026-11-20","title":"Fora da semana","workoutId":12,"sportTypeKey":"running"},
 {"itemType":"activity","date":"2026-11-10","title":"Corrida","sportTypeKey":"running"}
]}
"""

private let workoutJSON = """
{"workoutId":10,"workoutName":"Intervalado 5x1000","estimatedDistanceInMeters":9800,"estimatedDurationInSecs":3300,
 "workoutSegments":[{"workoutSteps":[
  {"type":"ExecutableStepDTO","stepType":{"stepTypeKey":"warmup"},"endCondition":{"conditionTypeKey":"time"},"endConditionValue":900,
   "targetType":{"workoutTargetTypeKey":"pace.zone"},"targetValueOne":2.6315,"targetValueTwo":2.8571},
  {"type":"RepeatGroupDTO","numberOfIterations":5,"workoutSteps":[
   {"type":"ExecutableStepDTO","stepType":{"stepTypeKey":"interval"},"endCondition":{"conditionTypeKey":"distance"},"endConditionValue":1000,
    "targetType":{"workoutTargetTypeKey":"pace.zone"},"targetValueOne":4.0,"targetValueTwo":4.1666},
   {"type":"ExecutableStepDTO","stepType":{"stepTypeKey":"recovery"},"endCondition":{"conditionTypeKey":"time"},"endConditionValue":120,
    "targetType":{"workoutTargetTypeKey":"no.target"}}
  ]},
  {"type":"ExecutableStepDTO","stepType":{"stepTypeKey":"cooldown"},"endCondition":{"conditionTypeKey":"time"},"endConditionValue":600,
   "targetType":{"workoutTargetTypeKey":"heart.rate.zone"},"zoneNumber":2}
 ]}]}
"""

@Suite struct PlannedWorkoutsTests {
    @Test func keepsOnlyRunWorkoutsInsideTheWeekOnce() throws {
        let items = try JSONDecoder().decode(CalendarDTO.self, from: Data(calendarJSON.utf8)).calendarItems
        let runs = PlannedWorkouts.runItems(items, from: Day(year: 2026, month: 11, day: 9), through: Day(year: 2026, month: 11, day: 15))
        #expect(runs.map(\.workoutId) == [10])
    }

    @Test func parsesStepsRepeatsAndTargets() throws {
        let dto = try JSONDecoder().decode(WorkoutDTO.self, from: Data(workoutJSON.utf8))

        let workout = PlannedWorkouts.workout(dto, day: "2026-11-13", fallbackTitle: nil)

        #expect(workout.title == "Intervalado 5x1000")
        #expect(workout.estimatedMeters == 9_800)
        #expect(workout.steps.count == 3)
        let warmup = workout.steps[0]
        #expect(warmup.kind == .warmup)
        #expect(warmup.seconds == 900)
        guard case .pace(let fastest, let slowest) = warmup.target else { Issue.record("sem alvo de pace"); return }
        #expect(abs(fastest - 350) < 1)
        #expect(abs(slowest - 380) < 1)
        #expect(workout.steps[1].repeats == 5)
        #expect(workout.steps[1].children.map(\.kind) == [.active, .recovery])
        #expect(workout.steps[1].children[0].meters == 1_000)
        #expect(workout.steps[1].children[1].target == nil)
        #expect(workout.steps[2].target == .zone(2))
        #expect(workout.steps.flatMap(\.flattened).count == 12)
    }
}
