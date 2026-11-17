import Foundation
import WorkoutAnalysis

enum ScoreRows {
    static func perfectLine(_ score: WorkoutScore, blocks: [WorkoutBlock]) -> String? {
        guard score.value >= ScoreConstants.perfectScore else { return nil }
        let targeted = blocks.filter { block in
            guard block.kind == .active, let step = block.prescribed else { return false }
            if case .open = step.target { return false }
            return block.status != .noTarget
        }.count
        guard targeted > 0 else { return ScoreConstants.perfectLineAllTargets }
        let noun = targeted == 1 ? ScoreConstants.perfectLineBlockSingular : ScoreConstants.perfectLineBlockPlural
        return "\(targeted) de \(targeted) \(noun) \(ScoreConstants.perfectLineSuffix)"
    }

    static func rows(_ score: WorkoutScore) -> [ScoreRowData] {
        score.items.compactMap { item in
            let name = ScoreConstants.partNames[item.part] ?? item.part.rawValue
            let reason = item.reason.flatMap { ScoreConstants.reasonTexts[$0] }
            if item.maximum > 0 {
                return ScoreRowData(
                    part: item.part, name: name, points: item.points, maximum: item.maximum,
                    pointsText: "\(Int(item.points.rounded()))/\(Int(item.maximum.rounded()))", reasonText: reason
                )
            }
            guard item.reason != .noPrescription else { return nil }
            return ScoreRowData(
                part: item.part, name: name, points: 0, maximum: 0,
                pointsText: nil, reasonText: reason.map { "\(ScoreConstants.excludedSuffix): \($0)" }
            )
        }
    }
}
