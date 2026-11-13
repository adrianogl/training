import Charts
import SwiftUI

struct HeartRateChart: View {
    let series: [(t: Double, bpm: Int)]
    let bands: [ZoneBand]
    let spans: [BlockSpan]

    var body: some View {
        let domain = yDomain
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(visibleBands(in: domain), id: \.zone) { band in
                    RectangleMark(
                        yStart: .value("de", band.low),
                        yEnd: .value("até", band.high)
                    )
                    .foregroundStyle(BrandColors.zone(band.zone).opacity(WorkoutDetailConstants.zoneBandOpacity))
                }
                ForEach(Array(spans.enumerated()), id: \.offset) { _, span in
                    RectangleMark(
                        xStart: .value("início", span.start / WorkoutDetailConstants.secondsPerMinute),
                        xEnd: .value("fim", span.end / WorkoutDetailConstants.secondsPerMinute)
                    )
                    .foregroundStyle(BrandColors.text.opacity(WorkoutDetailConstants.activeBlockOpacity))
                }
                ForEach(Array(series.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("min", point.t / WorkoutDetailConstants.secondsPerMinute),
                        y: .value("bpm", point.bpm)
                    )
                    .foregroundStyle(BrandColors.text)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                    .interpolationMethod(.monotone)
                }
            }
            .chartYScale(domain: domain)
            .chartXScale(domain: xDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine().foregroundStyle(BrandColors.line)
                    AxisValueLabel {
                        if let minutes = value.as(Double.self) {
                            Text("\(Int(minutes)) min")
                        }
                    }
                    .foregroundStyle(BrandColors.dim)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(BrandColors.line)
                    AxisValueLabel().foregroundStyle(BrandColors.dim)
                }
            }
            .frame(height: WorkoutDetailConstants.heartRateChartHeight)
            .accessibilityLabel("Curva de frequência cardíaca")
            if !bands.isEmpty || !spans.isEmpty {
                legend(domain)
            }
        }
        .brandCard()
    }

    private var yDomain: ClosedRange<Double> {
        let values = series.map { Double($0.bpm) }
        let padding = WorkoutDetailConstants.heartRateDomainPadding
        let low = (values.min() ?? 0) - padding
        let high = (values.max() ?? 0) + padding
        return low...max(high, low + 1)
    }

    private var xDomain: ClosedRange<Double> {
        let minutes = series.map { $0.t / WorkoutDetailConstants.secondsPerMinute }
        let low = minutes.min() ?? 0
        return low...max(minutes.max() ?? 0, low + 1)
    }

    private func visibleBands(in domain: ClosedRange<Double>) -> [ZoneBand] {
        bands.compactMap { band in
            let low = max(band.low, domain.lowerBound)
            let high = min(band.high, domain.upperBound)
            return high > low ? ZoneBand(zone: band.zone, low: low, high: high) : nil
        }
    }

    private func legend(_ domain: ClosedRange<Double>) -> some View {
        HStack(spacing: 12) {
            ForEach(visibleBands(in: domain), id: \.zone) { band in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(BrandColors.zone(band.zone))
                        .frame(width: 8, height: 8)
                    Text("Z\(band.zone)")
                }
            }
            if !spans.isEmpty {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(BrandColors.text.opacity(0.3))
                        .frame(width: 12, height: 8)
                    Text("blocos ativos")
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(BrandColors.dim)
    }
}
