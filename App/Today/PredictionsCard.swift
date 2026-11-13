import Reports
import SwiftUI
import WorkoutAnalysis

struct PredictionsCard: View {
    let predictions: [Prediction]

    private typealias C = TodayConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(C.predictionsTitle).padding(.top, 0).padding(.bottom, 6)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 0) {
                GridRow {
                    Text(C.predictionsDistance)
                    Text(C.predictionsToday).gridColumnAlignment(.trailing)
                    Text(C.predictionsYearAgo).gridColumnAlignment(.trailing)
                }
                .font(.caption2)
                .foregroundStyle(BrandColors.dim)
                .padding(.bottom, 6)
                ForEach(predictions, id: \.label) { prediction in
                    Divider().overlay(BrandColors.line)
                    GridRow {
                        Text(prediction.label).font(.subheadline).foregroundStyle(BrandColors.dim)
                        Text(prediction.seconds.map(WorkoutFormat.clock) ?? "—")
                            .font(BrandFonts.number(19))
                            .foregroundStyle(BrandColors.text)
                        delta(prediction)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .brandCard(fillsHeight: true)
    }

    @ViewBuilder
    private func delta(_ prediction: Prediction) -> some View {
        if let now = prediction.seconds, let before = prediction.yearAgoSeconds {
            let difference = now - before
            let sign = difference < 0 ? C.minusSign : "+"
            Text("\(sign)\(WorkoutFormat.clock(abs(difference)))")
                .font(BrandFonts.number(14))
                .foregroundStyle(difference <= 0 ? BrandColors.accent : BrandColors.attention)
        } else {
            Text("—").font(.caption).foregroundStyle(BrandColors.dim)
        }
    }
}
