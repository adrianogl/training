import SwiftUI
import TrainingCore

struct SummaryHeader: View {
    let summary: WorkoutSummary
    var weather: WeatherEffect?
    @Environment(\.horizontalSizeClass) private var sizeClass

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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: columns), alignment: .leading, spacing: 12) {
                stat(summary.distanceText, "km")
                stat(summary.durationText, "tempo")
                stat(summary.paceText.map(stripUnit), "pace médio")
                stat(summary.averageHeartRateText, "FC média")
                stat(summary.elevationText, "desnível")
                stat(summary.loadText, "carga")
                if let weather {
                    stat(RunWeatherText.degrees(weather), RunWeatherText.caption(weather), color: RunWeatherText.tint(weather))
                }
            }
            .padding(.top, 12)
            if let weather {
                Label {
                    Text(RunWeatherText.summary(weather))
                        .foregroundStyle(BrandColors.text.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: RunWeatherBandConstants.symbol)
                        .foregroundStyle(RunWeatherText.tint(weather))
                }
                .font(.footnote)
                .padding(.top, 8)
            }
        }
        .padding(.bottom, weather == nil ? 0 : RunWeatherBandConstants.headerBottomSpacing)
    }

    private var columns: Int {
        let count = [summary.distanceText, summary.durationText, summary.paceText, summary.averageHeartRateText, summary.elevationText, summary.loadText]
            .compactMap { $0 }.count + (weather == nil ? 0 : 1)
        guard sizeClass == .regular else { return count > 6 ? 4 : 3 }
        return max(count, 6)
    }

    @ViewBuilder
    private func stat(_ value: String?, _ caption: String, color: Color = BrandColors.text) -> some View {
        if let value {
            DSStat(value: value, label: caption, color: color, size: .large)
        }
    }

    private func stripUnit(_ pace: String) -> String {
        pace.replacingOccurrences(of: " \(WorkoutConstants.paceUnit)", with: "")
    }
}
