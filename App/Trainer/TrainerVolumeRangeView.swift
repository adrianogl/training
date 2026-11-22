import Insights
import SwiftUI

struct TrainerVolumeRangeView: View {
    let rows: [TrainerVolumeRangeRow]
    let current: Int
    let peakMeters: Double
    let suggestedRuns: Int?
    let select: (Int) -> Void

    private typealias K = TrainerVolumeRangeConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSCardLabel(TrainerDaysText.volumeRangeTitle)
            VStack(spacing: K.rowSpacing) {
                ForEach(rows) { row in
                    Button { select(row.runs) } label: { line(row) }
                        .buttonStyle(.plain)
                }
            }
            HStack(spacing: 8) {
                Color.clear.frame(width: K.labelWidth, height: 1)
                HStack {
                    Text(TrainerDaysText.axisValue(axis.lowerBound))
                    Spacer()
                    Text(TrainerDaysText.axisValue(axis.upperBound))
                }
                Color.clear.frame(width: K.valueWidth, height: 1)
            }
            .font(.caption2.monospacedDigit()).foregroundStyle(BrandColors.dim)
            Text(TrainerDaysText.volumeRangeCaption(
                range: rows.first { $0.runs == current }?.range, runs: current, peakMeters: peakMeters, suggestedRuns: suggestedRuns
            ))
            .font(.caption).foregroundStyle(BrandColors.dim)
        }
    }

    private var axis: ClosedRange<Double> {
        let low = rows.map(\.range.minimum).min() ?? 0
        let high = max(rows.map(\.range.limit).max() ?? 0, peakMeters)
        let lower = (low / K.axisStepMeters).rounded(.down) * K.axisStepMeters
        let upper = max((high / K.axisStepMeters).rounded(.up) * K.axisStepMeters, lower + K.axisStepMeters)
        return lower...upper
    }

    private func line(_ row: TrainerVolumeRangeRow) -> some View {
        let isCurrent = row.runs == current
        return HStack(spacing: 8) {
            Text(TrainerDaysText.runsLabel(row.runs))
                .font(.footnote.weight(isCurrent ? .semibold : .regular))
                .foregroundStyle(isCurrent ? BrandColors.text : BrandColors.dim)
                .frame(width: K.labelWidth, alignment: .leading)
            bar(row.range, isCurrent: isCurrent)
            Text(TrainerDaysText.rangeValue(row.range))
                .font(.footnote.monospacedDigit().weight(isCurrent ? .semibold : .regular))
                .foregroundStyle(isCurrent ? BrandColors.text : BrandColors.dim)
                .frame(width: K.valueWidth, alignment: .trailing)
        }
        .contentShape(Rectangle())
    }

    private func position(_ meters: Double, width: CGFloat) -> CGFloat {
        let clamped = min(max(meters, axis.lowerBound), axis.upperBound)
        return CGFloat((clamped - axis.lowerBound) / (axis.upperBound - axis.lowerBound)) * width
    }

    private func bar(_ range: TrainerVolumeRange, isCurrent: Bool) -> some View {
        GeometryReader { proxy in
            let x = { (meters: Double) in position(meters, width: proxy.size.width) }
            ZStack(alignment: .leading) {
                Capsule().fill(BrandColors.line)
                Capsule().fill(BrandColors.accentFill.opacity(K.limitOpacity))
                    .frame(width: max(x(range.limit) - x(range.minimum), 0)).offset(x: x(range.minimum))
                Capsule().fill(BrandColors.accentFill.opacity(isCurrent ? 1 : K.otherRowOpacity))
                    .frame(width: max(x(range.comfortable) - x(range.minimum), 0)).offset(x: x(range.minimum))
                Capsule().fill(BrandColors.text)
                    .frame(width: K.markerWidth, height: K.barHeight + K.markerOverhang * 2)
                    .offset(x: x(peakMeters) - K.markerWidth / 2)
            }
        }
        .frame(height: K.barHeight)
    }
}
