import Foundation
import GarminAPI
import TrainingCore

enum GarminRaceSuggestionBuilder {
    private typealias C = GarminRaceConstants

    static func build(events: [GarminRaceEvent], races: [KnownRace], links: GarminRaceLinks) -> GarminRaceSuggestions {
        let suggestions = events.filter { event in
            !links.declined.contains(event.id) && links.imported[event.id] == nil && !races.contains { matches($0, event) }
        }
        let changes = events.compactMap { event -> GarminRaceChange? in
            guard let link = links.imported[event.id], let race = races.first(where: { $0.id == link.raceId }) else { return nil }
            let lines = differences(from: link.event, to: event)
            return lines.isEmpty ? nil : GarminRaceChange(event: event, raceId: race.id, raceName: race.name, lines: lines)
        }
        return GarminRaceSuggestions(suggestions: suggestions, changes: changes)
    }

    static func matches(_ race: KnownRace, _ event: GarminRaceEvent) -> Bool {
        guard race.day == event.day else { return false }
        guard let meters = event.distanceMeters, race.distance > 0 else { return true }
        return abs(race.distance - meters) / race.distance <= C.distanceTolerance
    }

    static func differences(from old: GarminRaceEvent, to new: GarminRaceEvent) -> [String] {
        var lines: [String] = []
        if old.day != new.day { lines.append(String(format: C.changeFormat, C.dayLabel, dayText(old.day), dayText(new.day))) }
        if old.startTime != new.startTime {
            lines.append(String(format: C.changeFormat, C.startLabel, old.startTime ?? C.noValue, new.startTime ?? C.noValue))
        }
        if old.distanceMeters != new.distanceMeters {
            lines.append(String(format: C.changeFormat, C.distanceLabel, kmText(old.distanceMeters), kmText(new.distanceMeters)))
        }
        return lines
    }

    static func meta(_ event: GarminRaceEvent) -> String {
        [
            Day(iso: event.day).map(shortDay),
            event.startTime.map { String(format: C.startFormat, $0) },
            event.distanceMeters.map { kmText($0) },
            event.courseId == nil ? nil : C.course,
        ].compactMap { $0 }.joined(separator: C.separator)
    }

    static func shortDay(_ day: Day) -> String {
        weekdayFormatter.string(from: day.chartDate).replacingOccurrences(of: ".", with: "")
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: C.locale)
        formatter.timeZone = .current
        formatter.dateFormat = C.weekdayFormat
        return formatter
    }()

    private static func dayText(_ iso: String) -> String {
        Day(iso: iso).map(RacesText.shortDate) ?? iso
    }

    static func kmText(_ meters: Double?) -> String {
        guard let meters else { return C.noValue }
        return RacesText.distanceText(meters)
    }
}
