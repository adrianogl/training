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

@Suite struct PlannedStrengthItemsTests {
    @Test func keepsOnlyStrengthWorkoutsInsideTheRange() throws {
        let items = try JSONDecoder().decode(CalendarDTO.self, from: Data(calendarJSON.utf8)).calendarItems
        let strength = PlannedWorkouts.workoutItems(items, sport: "strength_training", from: Day(year: 2026, month: 11, day: 16), through: Day(year: 2026, month: 11, day: 22))
        #expect(strength.map(\.workoutId) == [20])
    }
}
