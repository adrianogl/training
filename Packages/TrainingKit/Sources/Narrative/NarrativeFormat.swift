import Foundation
import WorkoutAnalysis

enum NarrativeFormat {
    static func kilometerRange(_ facts: [String: Double]) -> String {
        typealias C = FindingDetailConstants
        let from = integer(facts[FindingFact.fromKilometer])
        let to = integer(facts[FindingFact.toKilometer])
        if to <= from { return "\(C.kilometer) \(from)" }
        let joiner = to == from + 1 ? C.and : C.rangeTo
        return "\(C.kilometer) \(from) \(joiner) \(to)"
    }

    static func elevation(_ facts: [String: Double]) -> String {
        let climb = integer(facts[FindingFact.climb])
        let descent = integer(facts[FindingFact.descent])
        let minimum = Int(AnalysisConstants.elevationMinimum)
        let parts = [climb >= minimum ? "+\(climb) m" : nil, descent >= minimum ? "−\(descent) m" : nil].compactMap { $0 }
        return parts.joined(separator: " \(FindingDetailConstants.and) ")
    }

    static func elevationSegment(_ facts: [String: Double]) -> String {
        let pace = facts[FindingFact.pace].map { WorkoutFormat.clock($0) } ?? ""
        return "\(kilometerRange(facts)): \(elevation(facts)) \(FindingDetailConstants.at) \(pace)\(NarrativeConstants.paceUnit)"
    }

    static func integer(_ value: Double?) -> Int {
        Int((value ?? 0).rounded())
    }

    static func decimal(_ value: Double?) -> String {
        (value ?? 0).formatted(.number.precision(.fractionLength(2)).locale(WorkoutFormat.locale))
    }

    static func percent(_ value: Double?) -> String {
        "\(Int(((value ?? 0) * 100).rounded()))%"
    }

    static func distance(_ meters: Double) -> String {
        meters < NarrativeConstants.metersPerKilometer
            ? "\(Int(meters.rounded())) m"
            : (meters / NarrativeConstants.metersPerKilometer)
                .formatted(.number.precision(.fractionLength(2)).locale(WorkoutFormat.locale)) + " \(NarrativeConstants.distanceUnit)"
    }

    static func distanceText(_ meters: Double) -> String {
        meters < NarrativeConstants.metersPerKilometer ? "\(Int(meters.rounded())) m" : "\(kilometers(meters)) \(NarrativeConstants.distanceUnit)"
    }

    static func kilometers(_ meters: Double) -> String {
        (meters / NarrativeConstants.metersPerKilometer).formatted(.number.precision(.fractionLength(0 ... 2)).locale(WorkoutFormat.locale))
    }

    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        guard total >= 60 else { return "\(total) s" }
        return total % 60 == 0 ? "\(total / 60) min" : "\(total / 60) min \(total % 60) s"
    }

    static func paceClock(metersPerSecond speed: Double?) -> String? {
        guard let speed, speed > 0 else { return nil }
        return WorkoutFormat.clock(NarrativeConstants.metersPerKilometer / speed)
    }

    static func pace(metersPerSecond speed: Double?) -> String? {
        paceClock(metersPerSecond: speed).map { "\($0) \(NarrativeConstants.paceUnit)" }
    }

    static func label(_ finding: Finding, blocks: [WorkoutBlock]) -> String? {
        finding.blockOrdinal.flatMap { blocks.indices.contains($0) ? blocks[$0].label : nil }
    }

    static func status(_ finding: Finding, blocks: [WorkoutBlock]) -> BlockStatus? {
        finding.blockOrdinal.flatMap { blocks.indices.contains($0) ? blocks[$0].status : nil }
    }
}
