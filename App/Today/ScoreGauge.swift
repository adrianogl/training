import SwiftUI

struct ScoreGauge: View {
    let score: Int
    let size: Double
    var moderate = TodayConstants.moderateThreshold
    var hard = TodayConstants.hardThreshold
    var accessibilityName = TodayConstants.readinessTitle

    private typealias C = TodayConstants

    var body: some View {
        ZStack {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                arc(from: segment.from + C.gaugeGap, to: segment.to - C.gaugeGap)
                    .stroke(segment.color.opacity(C.gaugeTrackOpacity), style: StrokeStyle(lineWidth: C.gaugeLineWidth, lineCap: .round))
            }
            arc(from: 0, to: fraction)
                .stroke(fill, style: StrokeStyle(lineWidth: C.gaugeLineWidth, lineCap: .round))
            Circle()
                .fill(BrandColors.text)
                .overlay(Circle().strokeBorder(BrandColors.background, lineWidth: 3))
                .frame(width: C.gaugeMarkerSize, height: C.gaugeMarkerSize)
                .offset(markerOffset)
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(BrandFonts.number(size * C.gaugeScoreRatio))
                    .foregroundStyle(textColor)
                Text(C.gaugeScale)
                    .font(.caption2)
                    .foregroundStyle(BrandColors.dim)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(accessibilityName) \(score) de 100")
    }

    private var fill: Color {
        if score < moderate { return BrandColors.rest }
        if score < hard { return BrandColors.attention }
        return BrandColors.accentFill
    }

    private var textColor: Color {
        if score < moderate { return BrandColors.rest }
        if score < hard { return BrandColors.attention }
        return BrandColors.accent
    }

    private var fraction: Double { min(max(Double(score) / 100, 0), 1) }

    private var segments: [(from: Double, to: Double, color: Color)] {
        let low = Double(moderate) / 100
        let high = Double(hard) / 100
        return [(0, low, BrandColors.rest), (low, high, BrandColors.attention), (high, 1, BrandColors.accentFill)]
    }

    private func arc(from start: Double, to end: Double) -> some Shape {
        Circle()
            .trim(from: start * C.gaugeSweep, to: end * C.gaugeSweep)
            .rotation(.degrees(C.gaugeStartDegrees))
    }

    private var markerOffset: CGSize {
        let radians = (C.gaugeStartDegrees + fraction * C.gaugeSweep * 360) * .pi / 180
        let radius = size / 2
        return CGSize(width: radius * cos(radians), height: radius * sin(radians))
    }
}
