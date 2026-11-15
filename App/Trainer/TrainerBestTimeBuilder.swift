import Insights

enum TrainerBestTimeBuilder {
    static func make(weather: [HourlyWeather]) -> TrainerBestTime? {
        let mornings = PlannedBriefingBuilder.bestHours(weather)
        guard let best = mornings.min(by: { ($0.temperature, $0.hour) < ($1.temperature, $1.hour) }) else { return nil }
        let heat = TrainerHeat.assess(temperature: best.temperature)
        let later = weather.sorted { $0.hour < $1.hour }.first { $0.hour > best.hour && TrainerHeat.assess(temperature: $0.temperature).isHot }
        return TrainerBestTime(hour: best.hour, temperature: best.temperature, heat: heat, laterHotHour: heat.isHot ? nil : later?.hour)
    }
}
