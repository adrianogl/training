import Charts
import Insights
import SwiftUI

struct ReadinessHistoryChart: View {
    let history: [ReadinessDayScore]

    private typealias C = ReadinessHistoryConstants

    var body: some View {
        let scores = history.map(\.score)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(C.title)
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(BrandColors.dim)
                Spacer(minLength: 8)
                averages(scores)
            }
            chart(scores)
                .frame(height: C.height)
            legend
        }
        .brandCard()
    }

    private func averages(_ scores: [Int?]) -> some View {
        let short = readinessAverage(scores.suffix(C.averageDays)).map { Int($0.rounded()) }
        let long = readinessAverage(scores).map { Int($0.rounded()) }
        return HStack(spacing: 4) {
            if let short {
                Text(C.averageShortPrefix).foregroundStyle(BrandColors.dim)
                Text("\(short)").foregroundStyle(BrandColors.text).bold()
            }
            if let long {
                Text("· \(C.averageLongPrefix)").foregroundStyle(BrandColors.dim)
                Text("\(long)").foregroundStyle(BrandColors.text).bold()
            }
        }
        .font(.caption)
        .monospacedDigit()
    }

    private func chart(_ scores: [Int?]) -> some View {
        let average = readinessMovingAverage(scores, window: C.averageDays)
        let lastIndex = history.count - 1
        return Chart {
            ForEach(Array(scores.enumerated()), id: \.offset) { index, score in
                if let score {
                    RectangleMark(
                        xStart: .value(C.dayAxis, Double(index) - C.barWidthRatio / 2),
                        xEnd: .value(C.dayAxis, Double(index) + C.barWidthRatio / 2),
                        yStart: .value(C.scoreAxis, 0),
                        yEnd: .value(C.scoreAxis, score)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: C.barCorner))
                        .foregroundStyle(ReadinessRuler.color(for: score).opacity(index == lastIndex ? 1 : C.pastOpacity))
                        .annotation(position: .top, spacing: 2) {
                            if index == lastIndex {
                                Text("\(score)").font(.caption2.weight(.bold)).foregroundStyle(BrandColors.text)
                            }
                        }
                }
            }
            ForEach([TodayConstants.moderateThreshold, TodayConstants.hardThreshold], id: \.self) { threshold in
                RuleMark(y: .value(C.scoreAxis, threshold))
                    .foregroundStyle(BrandColors.line)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: C.thresholdDash))
            }
            ForEach(Array(average.enumerated()), id: \.offset) { index, value in
                if let value {
                    LineMark(x: .value(C.dayAxis, index), y: .value(C.scoreAxis, value), series: .value(C.averageSeries, C.averageSeries))
                        .foregroundStyle(BrandColors.text.opacity(C.averageOpacity))
                        .lineStyle(StrokeStyle(lineWidth: C.averageLineWidth, lineJoin: .round))
                        .interpolationMethod(.monotone)
                }
            }
        }
        .chartXScale(domain: -0.5...(Double(lastIndex) + 0.5))
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .leading, values: [TodayConstants.moderateThreshold, TodayConstants.hardThreshold]) { _ in
                AxisValueLabel().foregroundStyle(BrandColors.dim)
            }
        }
        .chartXAxis {
            AxisMarks(values: labelIndices(lastIndex)) { value in
                AxisValueLabel(anchor: anchor(value.as(Int.self), lastIndex: lastIndex), collisionResolution: .disabled) {
                    if let index = value.as(Int.self), history.indices.contains(index) {
                        let day = history[index].day
                        Text("\(day.day)/\(day.month)").foregroundStyle(BrandColors.dim)
                    }
                }
            }
        }
        .accessibilityLabel(C.title)
    }

    private func anchor(_ index: Int?, lastIndex: Int) -> UnitPoint {
        if index == 0 { return .topLeading }
        if index == lastIndex { return .topTrailing }
        return .top
    }

    private func labelIndices(_ lastIndex: Int) -> [Int] {
        guard lastIndex > 0 else { return [0] }
        let step = Double(lastIndex) / Double(C.labelCount - 1)
        return (0..<C.labelCount).map { Int((Double($0) * step).rounded()) }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            swatch(BrandColors.accent, C.legendHard)
            swatch(BrandColors.form, C.legendModerate)
            swatch(BrandColors.rest, C.legendRest)
        }
        .font(.caption2)
        .foregroundStyle(BrandColors.dim)
    }

    private func swatch(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: C.legendSwatch, height: C.legendSwatch)
            Text(text)
        }
    }
}
