import SwiftUI

struct AnimatedScoreGauge: View, Animatable {
    let score: Int
    var progress: Double
    let size: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        ScoreGauge(
            score: Int((Double(score) * progress).rounded()),
            size: size,
            moderate: ScoreConstants.moderateThreshold,
            hard: ScoreConstants.strongThreshold,
            accessibilityName: ScoreConstants.breakdownTitle
        )
        .accessibilityLabel("\(ScoreConstants.breakdownTitle) \(score) de 100")
    }
}
