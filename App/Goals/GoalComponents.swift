import Insights
import Storage
import SwiftData
import SwiftUI
import TrainingCore
import WorkoutAnalysis

struct GoalStatusChip: View {
    let status: GoalStatus

    var body: some View {
        DSChip(text: status.text, tone: status.good ? .accent : .attention)
    }
}

struct GoalPredictionBar: View {
    let today: Double
    let target: Double

    var body: some View {
        GeometryReader { proxy in
            let slowest = max(today, target) * 1.08
            let fastest = min(today, target) * 0.97
            let x = { (seconds: Double) in (slowest - seconds) / (slowest - fastest) * proxy.size.width }
            ZStack(alignment: .leading) {
                Capsule().fill(BrandColors.track)
                Capsule()
                    .fill(LinearGradient(colors: [BrandColors.race.opacity(0.25), BrandColors.race.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(proxy.size.height, x(today)))
                Capsule().fill(BrandColors.accent).frame(width: 3, height: proxy.size.height * 2).offset(x: x(target) - 1.5)
            }
        }
        .frame(height: GoalsConstants.barHeight)
        .padding(.vertical, GoalsConstants.barHeight / 2)
        .accessibilityHidden(true)
    }
}
