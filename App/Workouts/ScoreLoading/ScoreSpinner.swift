import SwiftUI

struct ScoreSpinner: View {
    let size: Double
    let lineWidth: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias C = ScoreLoadingConstants

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            ZStack {
                Circle()
                    .stroke(BrandColors.text.opacity(C.trackOpacity), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: C.arcLength)
                    .stroke(BrandColors.accentFill, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(reduceMotion ? 0 : angle(context.date)))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func angle(_ date: Date) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: C.turnSeconds) / C.turnSeconds * 360
    }
}
