import SwiftUI
import TrainingCore

struct RunWeatherCard: View {
    private typealias C = RunWeatherBandConstants
    let effect: WeatherEffect
    var fillsHeight = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(String(format: C.degreeFormat, Int(effect.weather.temperature.rounded())))
                    .font(BrandFonts.number(C.cardDegreeFontSize))
                    .foregroundStyle(tint)
                Text(RunWeatherText.title(effect))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 0) {
                ForEach(Array(RunWeatherText.rows(effect).enumerated()), id: \.offset) { index, row in
                    if index > 0 { Divider().overlay(BrandColors.line) }
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.label).foregroundStyle(BrandColors.dim)
                        Spacer(minLength: 12)
                        Text(row.value).fontWeight(.semibold).foregroundStyle(BrandColors.text).multilineTextAlignment(.trailing)
                    }
                    .font(.subheadline.monospacedDigit())
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard(fillsHeight: fillsHeight)
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        effect.isCold ? BrandColors.fitness : effect.isHeat ? BrandColors.race : BrandColors.text
    }
}
