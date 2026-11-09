import Insights
import SwiftUI

enum EvolutionColors {
    static func trend(_ trend: IndicatorTrend) -> Color {
        switch trend {
        case .better: BrandColors.accent
        case .worse: BrandColors.attention
        case .same, .unknown: BrandColors.dim
        }
    }
}
