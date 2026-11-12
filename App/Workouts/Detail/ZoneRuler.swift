import SwiftUI

struct ZoneRuler: View {
    let data: ZoneRulerData

    var body: some View {
        let range = data.range
        VStack(alignment: .leading, spacing: 6) {
            bar(title: WorkoutDetailConstants.rulerWatchTitle, zones: data.watch, range: range)
            if let threshold = data.threshold, let title = data.thresholdTitle {
                bar(title: title, zones: threshold, range: range)
                    .padding(.top, 10)
            }
            if let note = data.note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(data.divergence == nil ? BrandColors.dim : BrandColors.attention)
                    .padding(.top, 8)
            }
        }
        .glassCard()
    }

    private func bar(title: String, zones: ZoneBar, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.medium))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(BrandColors.dim)
            band(zones.segments(in: range))
            scale(zones.marks(in: range))
            if let time = zones.timeText {
                Text(time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BrandColors.text.opacity(0.8))
                    .accessibilityLabel(time)
            }
        }
    }

    private func band(_ segments: [ZoneSegment]) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                ForEach(segments, id: \.zone) { segment in
                    let width = max(0, (segment.end - segment.start) * proxy.size.width)
                    Rectangle()
                        .fill(BrandColors.zone(segment.zone))
                        .overlay {
                            Text("Z\(segment.zone)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(BrandColors.onAccent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(width: width)
                        .offset(x: segment.start * proxy.size.width)
                }
            }
        }
        .frame(height: WorkoutDetailConstants.rulerBarHeight)
        .clipShape(RoundedRectangle(cornerRadius: WorkoutDetailConstants.rulerBarCornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private func scale(_ marks: [ZoneMark]) -> some View {
        GeometryReader { proxy in
            ForEach(marks) { mark in
                VStack(spacing: 2) {
                    Rectangle()
                        .fill(BrandColors.dim)
                        .frame(width: 1, height: WorkoutDetailConstants.rulerTickHeight)
                    Text("\(mark.bpm)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(BrandColors.text.opacity(0.7))
                        .fixedSize()
                }
                .position(x: mark.position * proxy.size.width, y: WorkoutDetailConstants.rulerScaleHeight / 2)
            }
        }
        .frame(height: WorkoutDetailConstants.rulerScaleHeight)
        .accessibilityElement(children: .combine)
    }
}
