import Foundation
import Testing
@testable import GarminAPI

private let setsJSON = """
{"activityId":5,"exerciseSets":[
 {"exercises":[{"category":"BENCH_PRESS","name":"INCLINE_BARBELL_BENCH_PRESS","probability":99.6}],"duration":45.0,"repetitionCount":10,"weight":16000,"setType":"ACTIVE"},
 {"exercises":[],"duration":60.0,"repetitionCount":null,"weight":null,"setType":"REST"},
 {"exercises":[{"category":"PLANK","name":null}],"duration":30.0,"repetitionCount":null,"weight":0,"setType":"ACTIVE"}
]}
"""

@Suite struct ExerciseSetsTests {
    @Test func keepsActiveSetsWithWeightInKilograms() throws {
        let sets = try ExerciseSets.parse(Data(setsJSON.utf8))
        #expect(sets == [
            StrengthSet(category: "BENCH_PRESS", exerciseKey: "INCLINE_BARBELL_BENCH_PRESS", reps: 10, weight: 16),
            StrengthSet(category: "PLANK", exerciseKey: nil, reps: nil, weight: nil),
        ])
    }
}
