import TrainingCore

public enum GarminRaceEvents {
    private typealias C = GarminRaceEventConstants

    public static func upcoming(client: GarminAccountClient, from today: Day) async throws -> [GarminRaceEvent] {
        let months = (0..<C.monthsAhead).map { offset -> (Int, Int) in
            let total = today.year * 12 + (today.month - 1) + offset
            return (total / 12, total % 12 + 1)
        }
        return events(try await PlannedWorkouts.calendarItems(client: client, months: months), from: today)
    }

    static func events(_ items: [CalendarDTO.Item], from today: Day) -> [GarminRaceEvent] {
        var seen = Set<Int64>()
        return items.compactMap { item -> GarminRaceEvent? in
            guard item.itemType == C.eventItem, item.isRace == true, item.activityTypeId == nil || item.activityTypeId == C.runningActivityType,
                  let id = item.id, !seen.contains(id), let iso = item.date, let day = Day(iso: iso), day >= today,
                  let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }
            seen.insert(id)
            return GarminRaceEvent(
                id: id, name: title, day: iso, startTime: item.eventTimeLocal?.startTimeHhMm,
                distanceMeters: meters(item.completionTarget), courseId: item.courseId, url: item.url
            )
        }
        .sorted { $0.day < $1.day }
    }

    private static func meters(_ target: CalendarDTO.Item.Target?) -> Double? {
        guard let target, target.unitType == C.distanceUnitType, let value = target.value, value > 0,
              let unit = target.unit, let factor = C.metersPerUnit[unit] else { return nil }
        return value * factor
    }
}
