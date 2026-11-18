import WorkoutAnalysis

extension NarrativeFormat {
    static func temperature(_ value: Double?) -> String {
        "\(integer(value)) \(NarrativeConstants.degreeUnit)"
    }

    static func weather(_ facts: [String: Double]) -> String {
        let temperature = temperature(facts[FindingFact.temperature])
        guard facts[FindingFact.cold] != 1, let dewPoint = facts[FindingFact.dewPoint] else { return temperature }
        return "\(temperature), \(NarrativeConstants.dewPointLabel) \(self.temperature(dewPoint))"
    }

    static func weatherPercent(_ facts: [String: Double]) -> String {
        let value = (facts[FindingFact.weatherFactor] ?? 0) * 100
        return "\(value.formatted(.number.precision(.fractionLength(1)).locale(WorkoutFormat.locale)))%"
    }

    static func hasWeather(_ facts: [String: Double]) -> Bool {
        facts[FindingFact.temperature] != nil
    }
}
