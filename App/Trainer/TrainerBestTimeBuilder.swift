import Insights

enum TrainerBestTimeBuilder {
    static func make(weather: [HourlyWeather], longPace: Double? = nil) -> TrainerBestTime? {
        let pace = longPace ?? TrainerConstants.defaultLongPace
        let mornings = PlannedBriefingBuilder.bestHours(weather)
        guard let best = mornings.min(by: { ($0.temperature, $0.hour) < ($1.temperature, $1.hour) }) else { return nil }
        let heat = TrainerHeat.assess(temperature: best.temperature, dewPoint: best.dewPoint, pace: pace)
        let later = weather.sorted { $0.hour < $1.hour }.lazy
            .filter { $0.hour > best.hour }
            .map { (hour: $0.hour, heat: TrainerHeat.assess(temperature: $0.temperature, dewPoint: $0.dewPoint, pace: pace)) }
            .first { $0.heat.isHot }
        let shown = heat.isHot ? nil : later
        return TrainerBestTime(
            hour: best.hour, temperature: best.temperature, heat: heat,
            laterHotHour: shown?.hour, laterBlockReduction: shown?.heat.blockReduction ?? 0
        )
    }
}
