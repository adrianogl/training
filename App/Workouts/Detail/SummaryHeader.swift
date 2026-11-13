import SwiftUI

struct SummaryHeader: View {
    let summary: WorkoutSummary
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.dateText)
                .font(.subheadline)
                .foregroundStyle(BrandColors.dim)
            Text(summary.title)
                .font(.title2.bold())
                .foregroundStyle(BrandColors.text)
            if summary.hasPrescription || !summary.subtitle.isEmpty {
                HStack(spacing: 8) {
                    if summary.hasPrescription {
                        TreinusBadge()
                    }
                    Text(summary.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(BrandColors.dim)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: sizeClass == .regular ? 6 : 3), alignment: .leading, spacing: 12) {
                stat(summary.distanceText, "km")
                stat(summary.durationText, "tempo")
                stat(summary.paceText.map(stripUnit), "pace médio")
                stat(summary.averageHeartRateText, "FC média")
                stat(summary.elevationText, "desnível")
                stat(summary.loadText, "carga")
            }
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private func stat(_ value: String?, _ caption: String) -> some View {
        if let value {
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(BrandFonts.number(26))
                    .foregroundStyle(BrandColors.text)
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(BrandColors.dim)
            }
        }
    }

    private func stripUnit(_ pace: String) -> String {
        pace.replacingOccurrences(of: " \(WorkoutConstants.paceUnit)", with: "")
    }
}
