import SwiftUI
import TrainingCore

struct RunWeatherBand: View {
    private typealias C = RunWeatherBandConstants
    let effect: WeatherEffect

    var body: some View {
        HStack(spacing: C.padding) {
            Text(String(format: C.degreeFormat, Int(effect.weather.temperature.rounded())))
                .font(BrandFonts.number(C.degreeFontSize))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(RunWeatherText.title(effect))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.text)
                if let detail = RunWeatherText.detail(effect) {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(BrandColors.dim)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(C.padding)
        .background(tint.opacity(C.backgroundOpacity), in: RoundedRectangle(cornerRadius: C.cornerRadius))
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        effect.isCold ? BrandColors.fitness : effect.isHeat ? BrandColors.race : BrandColors.dim
    }
}

enum RunWeatherText {
    private typealias C = RunWeatherBandConstants

    static func title(_ effect: WeatherEffect) -> String {
        if effect.isCold { return C.coldTitle }
        guard let dewPoint = effect.weather.dewPoint else { return C.mildTitle }
        let dew = String(format: C.dewPointFormat, Int(dewPoint.rounded()))
        return dewPoint >= C.muggyDewPoint ? dew + C.separator + C.muggy : dew
    }

    static func detail(_ effect: WeatherEffect) -> String? {
        guard effect.paceFactor > 0 else { return nil }
        return String(format: effect.isCold ? C.coldFormat : C.heatFormat, percent(effect.paceFactor))
    }

    static func percent(_ factor: Double) -> String {
        (factor * C.percentScale).formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "pt_BR"))) + "%"
    }
}
