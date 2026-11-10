import Foundation
import WorkoutAnalysis

enum ScoreRows {
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
