import Insights

enum TrainerHeatDayBuilder {
    private typealias C = TrainerConstants

    static func make(weather: [HourlyWeather], longPace: Double? = nil, usualHour: Int = C.heatDefaultHour, hotSessions: Int = 0) -> TrainerHeatDay? {
        let pace = longPace ?? C.defaultLongPace
        let hours = weather
            .filter { C.heatHours.contains($0.hour) }
            .sorted { $0.hour < $1.hour }
            .map { hour in
                TrainerHeatHour(
                    hour: hour.hour, temperature: hour.temperature, dewPoint: hour.dewPoint,
                    heat: TrainerHeat.assess(
                        temperature: hour.temperature, dewPoint: hour.dewPoint, radiation: hour.radiation, pace: pace, hotSessions: hotSessions
                    )
                )
            }
        guard let index = DayAdjust.closestIndex(to: usualHour, in: hours.map(\.hour)) else { return nil }
        let usual = hours[index]
        let best = hours
            .filter { C.heatSuggestionHours.contains($0.hour) }
            .min { ($0.heat.paceOffset, abs($0.hour - usual.hour)) < ($1.heat.paceOffset, abs($1.hour - usual.hour)) }
        let gain = usual.heat.paceOffset - (best?.heat.paceOffset ?? usual.heat.paceOffset)
        let suggested = best.flatMap { $0.hour != usual.hour && gain >= C.heatSuggestionSeconds ? $0.hour : nil }
        return TrainerHeatDay(hours: hours, usualHour: usual.hour, suggestedHour: suggested, hotSessions: hotSessions)
    }
}
