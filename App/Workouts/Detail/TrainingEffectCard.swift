import SwiftUI
import WorkoutAnalysis

struct TrainingEffectCard: View {
    let effect: TrainingEffectData

    private typealias C = WorkoutDetailConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(C.effectTitle).padding(.top, 0).padding(.bottom, 0)
            Text(effect.label.flatMap { C.effectLabels[$0] } ?? C.effectFallback)
                .font(BrandFonts.number(28))
                .foregroundStyle(BrandColors.accent)
            if let aerobic = effect.aerobic, let anaerobic = effect.anaerobic {
                Text(String(format: C.effectSentenceFormat, number(aerobic), level(aerobic), number(anaerobic), level(anaerobic)))
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.text.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(C.effectEmpty).font(.subheadline).foregroundStyle(BrandColors.dim)
            }
            VStack(spacing: 0) {
                row(C.effectHighZones, effect.highZoneSeconds.map { WorkoutFormat.clock($0) })
                row(C.effectAerobic, effect.aerobic.map { "\(number($0)) · \(level($0))" })
                row(C.effectAnaerobic, effect.anaerobic.map { "\(number($0)) · \(level($0))" })
                row(C.effectLoad, effect.load.map { "\(Int($0.rounded()))" })
            }
        }
        .brandCard(fillsHeight: true)
    }

    @ViewBuilder
    private func row(_ name: String, _ value: String?) -> some View {
        if let value {
            HStack {
                Text(name).foregroundStyle(BrandColors.dim)
                Spacer()
                Text(value).font(BrandFonts.number(15)).foregroundStyle(BrandColors.text)
            }
            .font(.footnote)
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) { Rectangle().fill(BrandColors.line).frame(height: 1) }
        }
    }

    private func number(_ value: Double) -> String {
        TodayText.decimal(value, fractionDigits: 1)
    }

    private func level(_ value: Double) -> String {
        let index = min(max(Int(value), 0), C.effectLevels.count - 1)
        return C.effectLevels[index]
    }
}
