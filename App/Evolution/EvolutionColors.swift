import Insights
import SwiftUI

extension IndicatorTrend {
    var ds: DSTrend {
        switch self {
        case .better: .better
        case .worse: .worse
        case .same, .unknown: .same
        }
    }
}

enum EvolutionColors {
    static func trend(_ trend: IndicatorTrend) -> Color {
        DSDelta.color(trend.ds)
    }

    static func trendFill(_ trend: IndicatorTrend) -> Color {
        switch trend {
        case .better: BrandColors.accentFill
        case .worse: BrandColors.attention
        case .same, .unknown: BrandColors.neutralBar
        }
    }
}
