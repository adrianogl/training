import Insights
import SwiftUI

enum TrainerCycleConstants {
    static let chartHeight: CGFloat = 72
    static let barSpacing: CGFloat = 4
    static let barRadius: CGFloat = 2
    static let belowShare = 0.8
    static let iconSize: CGFloat = 38
    static let iconRadius: CGFloat = 10
    static let iconFillOpacity = 0.10
    static let progressHeight: CGFloat = 4
    static let legendWidth: CGFloat = 9
    static let legendHeight: CGFloat = 4
    static let maximumReasons = 3
    static let referencePredictionMeters = 10_000.0

    static func color(for verdict: TrainerCycleVerdict) -> Color {
        switch verdict {
        case .increase: BrandColors.accent
        case .keep: BrandColors.fitness
        case .decrease: BrandColors.attention
        }
    }

    static func symbol(for verdict: TrainerCycleVerdict) -> String {
        switch verdict {
        case .increase: "arrow.up"
        case .keep: "minus"
        case .decrease: "arrow.down"
        }
    }

    static func isBelow(done: Double, total: Double) -> Bool {
        total > 0 && done / total < belowShare
    }

    static func shareColor(done: Double, total: Double) -> Color {
        isBelow(done: done, total: total) ? BrandColors.attention : BrandColors.accentFill
    }
}
