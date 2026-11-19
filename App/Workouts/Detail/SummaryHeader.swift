import SwiftUI
import TrainingCore

struct SummaryHeader: View {
    let summary: WorkoutSummary
    var weather: WeatherEffect?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.dateText)
                        .font(.subheadline)
                        .foregroundStyle(BrandColors.dim)
                    Text(summary.title)
                        .font(.title2.bold())
                        .foregroundStyle(BrandColors.text)
                }
                Spacer(minLength: 0)
            }
            if summary.hasPrescription || !summary.subtitle.isEmpty {
                HStack(spacing: 8) {
                    if summary.hasPrescription {
                        PlannedBadge()
                    }
                    Text(summary.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(BrandColors.dim)
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(row) { item in
                            DSStat(value: item.value, label: item.caption, size: .large)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(0..<max(columns - row.count, 0), id: \.self) { _ in
                            Color.clear.frame(height: 1)
                        }
                    }
                }
            }
            .padding(.top, 12)
            if let weather {
                weatherCard(weather).padding(.top, 14)
            }
        }
        .padding(.bottom, weather == nil ? 0 : RunWeatherBandConstants.headerBottomSpacing)
    }

    private var items: [SummaryStatItem] {
        [
            (summary.distanceText, "km"), (summary.durationText, "tempo"), (summary.paceText.map(stripUnit), "pace médio"),
            (summary.averageHeartRateText, "FC média"), (summary.elevationText, "desnível"), (summary.loadText, summary.loadCaption),
            (summary.bestKilometerText, SummaryHeaderConstants.bestKilometer), (summary.maxHeartRateText, SummaryHeaderConstants.maxHeartRate),
        ].compactMap { value, caption in value.map { SummaryStatItem(value: $0, caption: caption) } }
    }

    private func weatherCard(_ weather: WeatherEffect) -> some View {
        let tint = RunWeatherText.tint(weather)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: RunWeatherBandConstants.symbol).font(.subheadline.weight(.semibold))
                Text(RunWeatherText.degrees(weather)).font(BrandFonts.number(24))
                Text(RunWeatherText.caption(weather, pace: summary.paceSeconds)).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(tint)
            Text(RunWeatherText.summary(weather, pace: summary.paceSeconds))
                .font(.footnote)
                .foregroundStyle(BrandColors.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RunWeatherBandConstants.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(RunWeatherBandConstants.backgroundOpacity), in: RoundedRectangle(cornerRadius: RunWeatherBandConstants.cornerRadius, style: .continuous))
    }

    private var columns: Int { SummaryHeaderConstants.columns }

    private var rows: [[SummaryStatItem]] {
        stride(from: 0, to: items.count, by: columns).map { Array(items[$0..<min($0 + columns, items.count)]) }
    }

    private func stripUnit(_ pace: String) -> String {
        pace.replacingOccurrences(of: " \(WorkoutConstants.paceUnit)", with: "")
    }
}
