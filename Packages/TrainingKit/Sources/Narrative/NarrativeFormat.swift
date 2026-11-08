import Foundation
import WorkoutAnalysis

enum NarrativeFormat {
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
