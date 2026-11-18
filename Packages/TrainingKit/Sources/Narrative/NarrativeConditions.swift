import WorkoutAnalysis

extension NarrativeFormat {
    private typealias C = FindingDetailConstants

    static func dayCause(_ facts: [String: Double]) -> String? {
        var state: [String] = []
        if let sleep = facts[FindingFact.sleepSeconds] {
            let minutes = integer(sleep / 60)
            state.append(String(format: C.causeSleepFormat, minutes / 60, minutes % 60))
        } else if let score = facts[FindingFact.sleepScore] {
            state.append(String(format: C.causeSleepScoreFormat, integer(score)))
        }
        if facts[FindingFact.hrvLow] == 1 { state.append(C.causeHrvLow) }
        if let battery = facts[FindingFact.bodyBattery] { state.append(String(format: C.causeBatteryFormat, integer(battery))) }
        let previous = facts[FindingFact.previousDay].flatMap { PreviousDayLoad(rawValue: integer($0)) }.flatMap { C.causePreviousDay[$0] }
        guard !state.isEmpty || previous != nil else { return nil }
        let lead = state.isEmpty ? nil : C.causeLead + list(state) + "."
        return [lead, previous.map { String(format: C.causePreviousFormat, $0) }].compactMap { $0 }.joined(separator: " ")
    }

    static func formEvidence(_ facts: [String: Double]) -> String? {
        var parts: [String] = []
        if let from = facts[FindingFact.cadenceFrom], let to = facts[FindingFact.cadenceTo] {
            parts.append(String(format: C.cadenceFormat, integer(from), integer(to)))
        }
        if let from = facts[FindingFact.stanceFrom], let to = facts[FindingFact.stanceTo], from > 0 {
            parts.append(String(format: C.stanceFormat, integer(from), integer(to), integer((to / from - 1) * 100)))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func windSpeed(_ value: Double?) -> String {
        "\(integer(value)) \(C.speedUnit)"
    }

    private static func list(_ items: [String]) -> String {
        guard items.count > 1, let last = items.last else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " \(C.and) " + last
    }
}
