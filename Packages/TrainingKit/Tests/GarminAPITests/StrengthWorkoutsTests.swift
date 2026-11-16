import Foundation
import Testing
import TrainingCore
@testable import GarminAPI

private let calendarJSON = """
{"calendarItems":[
 {"itemType":"workout","date":"2026-11-18","title":"MMII (quarta)","workoutId":20,"sportTypeKey":"strength_training"},
 {"itemType":"workout","date":"2026-11-18","title":"Corrida fácil","workoutId":21,"sportTypeKey":"running"},
 {"itemType":"workout","date":"2026-11-30","title":"Fora","workoutId":22,"sportTypeKey":"strength_training"}
]}
"""

private let strengthJSON = """
{"workoutId":20,"workoutName":"MMII (quarta)","workoutSegments":[{"workoutSteps":[
 {"type":"RepeatGroupDTO","numberOfIterations":3,"workoutSteps":[
  {"type":"ExecutableStepDTO","stepType":{"stepTypeKey":"interval"},"endCondition":{"conditionTypeKey":"time"},"endConditionValue":45,
   "description":"Ponte dinamica com dumbell - 45 s","category":"HIP_RAISE"},
  {"type":"ExecutableStepDTO","stepType":{"stepTypeKey":"rest"},"endCondition":{"conditionTypeKey":"time"},"endConditionValue":60}
 ]},
 {"type":"RepeatGroupDTO","numberOfIterations":3,"workoutSteps":[
  {"type":"ExecutableStepDTO","stepType":{"stepTypeKey":"interval"},"endCondition":{"conditionTypeKey":"reps"},"endConditionValue":12,
   "description":"Panturrilha maquina sentado (PTP) - 8 a 12 rep boa carga","category":"CALF_RAISE","exerciseName":"WEIGHTED_SEATED_CALF_RAISE"},
  {"type":"ExecutableStepDTO","stepType":{"stepTypeKey":"interval"},"endCondition":{"conditionTypeKey":"reps"},"endConditionValue":30,
   "description":"Agachamento livre (TPH) - 30 rep","category":"SQUAT","exerciseName":"BARBELL_BACK_SQUAT"}
 ]},
 {"type":"ExecutableStepDTO","stepType":{"stepTypeKey":"interval"},"endCondition":{"conditionTypeKey":"reps"},"endConditionValue":20,
  "category":"PLANK"}
]}]}
"""

private let setsJSON = """
{"activityId":5,"exerciseSets":[
 {"exercises":[{"category":"HIP_RAISE","name":null,"probability":99.6}],"duration":45.0,"repetitionCount":7,"weight":null,"setType":"ACTIVE","wktStepIndex":0},
 {"exercises":[],"duration":60.0,"repetitionCount":null,"weight":null,"setType":"REST","wktStepIndex":1},
 {"exercises":[{"category":"SQUAT","name":"BARBELL_BACK_SQUAT","probability":100}],"duration":88.2,"repetitionCount":9,"weight":40000,"setType":"ACTIVE","wktStepIndex":17}
]}
"""

@Suite struct StrengthWorkoutsTests {
    @Test func keepsOnlyStrengthWorkoutsInsideTheRange() throws {
        let items = try JSONDecoder().decode(CalendarDTO.self, from: Data(calendarJSON.utf8)).calendarItems
        let strength = PlannedWorkouts.workoutItems(items, sport: StrengthWorkouts.sport, from: Day(year: 2026, month: 11, day: 16), through: Day(year: 2026, month: 11, day: 22))
        #expect(strength.map(\.workoutId) == [20])
    }

    @Test func groupsExercisesIntoBlocksWithSetsAndRest() throws {
        let dto = try JSONDecoder().decode(WorkoutDTO.self, from: Data(strengthJSON.utf8))

        let workout = StrengthWorkouts.workout(dto, day: "2026-11-18", fallbackTitle: nil)

        #expect(workout.title == "MMII (quarta)")
        #expect(workout.blocks.count == 3)
        #expect(workout.blocks[0].sets == 3)
        #expect(workout.blocks[0].restSeconds == 60)
        #expect(workout.blocks[0].exercises == [StrengthExercise(name: "Ponte dinamica com dumbell", detail: "45 s", category: "HIP_RAISE", exerciseKey: nil, reps: nil, seconds: 45)])
        #expect(workout.blocks[1].exercises.map(\.name) == ["Panturrilha maquina sentado (PTP)", "Agachamento livre (TPH)"])
        #expect(workout.blocks[1].exercises[1].detail == "30 rep")
        #expect(workout.blocks[1].restSeconds == nil)
        #expect(workout.blocks[2].sets == 1)
        #expect(workout.blocks[2].exercises[0].name == "Plank")
        #expect(workout.blocks[2].exercises[0].detail == "20 rep")
        #expect(workout.totalSets == 3 * 1 + 3 * 2 + 1)
    }

    @Test func readsOnlyActiveSetsWithWeightInKilograms() throws {
        let sets = try ExerciseSets.parse(Data(setsJSON.utf8))

        #expect(sets.count == 2)
        #expect(sets[0] == StrengthSet(stepIndex: 0, category: "HIP_RAISE", exerciseKey: nil, reps: 7, seconds: 45, weight: nil))
        #expect(sets[1].weight == 40)
        #expect(sets[1].exerciseKey == "BARBELL_BACK_SQUAT")
    }
}
