import Foundation
import Testing
import TrainingCore
@testable import GarminAPI

private let json = """
{"calendarItems":[
 {"id":29995077,"itemType":"event","title":"Live! Run XP","date":"2026-11-22","isRace":true,"activityTypeId":1,
  "eventTimeLocal":{"startTimeHhMm":"07:00","timeZoneId":"America/Sao_Paulo"},
  "completionTarget":{"value":10.0,"unit":"kilometer","unitType":"distance"},"courseId":514884211,"url":"https://www.liverun.com.br/etapa"},
 {"id":25207054,"itemType":"event","title":"27 Volta Internacional da Pampulha","date":"2026-12-06","isRace":true,"activityTypeId":1,
  "eventTimeLocal":{"startTimeHhMm":"06:00","timeZoneId":"America/Sao_Paulo"},
  "completionTarget":{"value":18.82,"unit":"kilometer","unitType":"distance"}},
 {"id":25207054,"itemType":"event","title":"27 Volta Internacional da Pampulha","date":"2026-12-06","isRace":true,"activityTypeId":1},
 {"id":1,"itemType":"event","title":"Aniversário","date":"2026-12-10","isRace":false},
 {"id":2,"itemType":"event","title":"Prova passada","date":"2026-10-01","isRace":true},
 {"id":3,"itemType":"event","title":"Travessia","date":"2026-12-20","isRace":true,"activityTypeId":5},
 {"id":4,"itemType":"workout","title":"Corrida fácil","date":"2026-11-23","workoutId":9,"sportTypeKey":"running"}
]}
"""

@Test func readsUpcomingRunningRacesFromTheCalendar() throws {
    let items = try JSONDecoder().decode(CalendarDTO.self, from: Data(json.utf8)).calendarItems
    let events = GarminRaceEvents.events(items, from: Day(iso: "2026-11-17")!)

    #expect(events.map(\.id) == [29_995_077, 25_207_054])
    #expect(events[0] == GarminRaceEvent(
        id: 29_995_077, name: "Live! Run XP", day: "2026-11-22", startTime: "07:00",
        distanceMeters: 10_000, courseId: 514_884_211, url: "https://www.liverun.com.br/etapa"
    ))
    #expect(abs((events[1].distanceMeters ?? 0) - 18_820) < 0.01)
    #expect(events[1].courseId == nil)
}
