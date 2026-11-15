import Insights
import SwiftUI

struct TrainerDayCell: View {
    let weekday: Int
    let kind: TrainerDayKind
    let meters: Double
    let warned: Bool
    let alternates: Bool

    private var label: String {
        alternates && (kind == .threshold || kind == .vo2max) ? TrainerDaysText.alternatingShort : TrainerText.kindShort(kind)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(TrainerText.weekdayName(weekday - 1)).font(.caption2).foregroundStyle(BrandColors.dim)
            Text(label)
                .font(.caption.weight(.semibold)).foregroundStyle(BrandColors.text).lineLimit(1).minimumScaleFactor(0.6)
            Capsule().fill(TrainerConstants.color(for: kind)).frame(height: TrainerDaysConstants.barHeight).padding(.horizontal, 4)
            Text(TrainerDaysText.kilometers(meters))
                .font(.caption2).foregroundStyle(BrandColors.dim).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(BrandColors.track, in: RoundedRectangle(cornerRadius: TrainerDaysConstants.cellCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TrainerDaysConstants.cellCorner, style: .continuous)
                .stroke(warned ? BrandColors.attention : .clear, lineWidth: TrainerDaysConstants.warningBorder)
        )
    }
}
