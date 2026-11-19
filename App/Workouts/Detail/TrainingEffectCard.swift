import SwiftUI
import WorkoutAnalysis

struct TrainingEffectCard: View {
    let effect: TrainingEffectData
    var framed = true
    var showsLabel = true

    private typealias C = WorkoutDetailConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsLabel { DSCardLabel(C.effectTitle) }
            Text(effect.label.flatMap { C.effectLabels[$0] } ?? C.effectFallback)
                .font(BrandFonts.number(24))
                .foregroundStyle(BrandColors.accent)
            if effect.aerobic == nil && effect.anaerobic == nil {
                Text(C.effectEmpty).font(.subheadline).foregroundStyle(BrandColors.dim)
            }
            VStack(spacing: 10) {
                if let aerobic = effect.aerobic { bar(C.effectAerobicShort, aerobic, BrandColors.fitness) }
                if let anaerobic = effect.anaerobic { bar(C.effectAnaerobicShort, anaerobic, BrandColors.race) }
            }
            if let seconds = effect.highZoneSeconds {
                HStack {
                    Text(C.effectHighZones).foregroundStyle(BrandColors.dim)
                    Spacer()
                    Text(WorkoutFormat.clock(seconds)).font(BrandFonts.number(15)).foregroundStyle(BrandColors.text)
                }
                .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard(framed: framed, fillsHeight: true)
    }

    private func bar(_ name: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.footnote).foregroundStyle(BrandColors.text)
                Text(level(value)).font(.caption2).foregroundStyle(BrandColors.dim)
            }
            .frame(width: C.effectNameWidth, alignment: .leading)
            DSProgressBar(value: min(value / C.effectScale, 1), color: color, height: C.effectBarHeight)
            Text(TodayText.decimal(value, fractionDigits: 1))
                .font(BrandFonts.number(15))
                .foregroundStyle(BrandColors.text)
                .frame(width: C.effectValueWidth, alignment: .trailing)
        }
    }

    private func level(_ value: Double) -> String {
        let index = min(max(Int(value), 0), C.effectLevels.count - 1)
        return C.effectLevels[index]
    }
}
