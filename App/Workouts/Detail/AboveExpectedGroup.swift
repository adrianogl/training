import SwiftUI
import WorkoutAnalysis

struct AboveExpectedGroup: View {
    let signals: [AboveExpectedSignal]

    private typealias C = WorkoutDetailConstants

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: C.aboveExpectedCornerRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            Label(C.aboveExpectedTitle, systemImage: C.aboveExpectedSymbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(BrandColors.fitness)
            ForEach(Array(signals.enumerated()), id: \.offset) { index, signal in
                if index > 0 { Divider().overlay(BrandColors.line) }
                item(signal)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandColors.fitness.opacity(C.aboveExpectedTint), in: shape)
        .overlay(shape.strokeBorder(BrandColors.fitness, lineWidth: C.aboveExpectedBorderWidth))
    }

    private func item(_ signal: AboveExpectedSignal) -> some View {
        let scale = max(signal.before, signal.today, 1)
        return VStack(alignment: .leading, spacing: 6) {
            Text(C.aboveExpectedTitles[signal.kind] ?? "")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandColors.text)
            bar(String(format: C.aboveExpectedBeforeFormat, signal.compared), value: signal.before, scale: scale, color: BrandColors.neutralBar, valueColor: BrandColors.text)
            bar(C.aboveExpectedToday, value: signal.today, scale: scale, color: BrandColors.fitness, valueColor: BrandColors.fitness)
        }
        .accessibilityElement(children: .combine)
    }

    private func bar(_ label: String, value: Double, scale: Double, color: Color, valueColor: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
                .frame(width: C.aboveExpectedLabelWidth, alignment: .leading)
            GeometryReader { proxy in
                Capsule()
                    .fill(color)
                    .frame(width: max(4, proxy.size.width * value / scale))
            }
            .frame(height: C.aboveExpectedBarHeight)
            .background(BrandColors.track, in: Capsule())
            Text("\(Int(value)) \(C.aboveExpectedUnit)")
                .font(BrandFonts.number(14))
                .foregroundStyle(valueColor)
                .frame(width: C.aboveExpectedValueWidth, alignment: .trailing)
        }
    }
}
