import Reports
import SwiftUI
import WorkoutAnalysis

struct PredictionsCard: View {
    let predictions: [Prediction]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(TodayConstants.predictionsTitle)
                .padding(.top, 0)
                .padding(.bottom, 0)
            HStack {
                ForEach(predictions, id: \.label) { prediction in
                    VStack(spacing: 2) {
                        Text(prediction.label).font(.caption2).foregroundStyle(BrandColors.dim)
                        Text(prediction.seconds.map(WorkoutFormat.clock) ?? "—")
                            .font(BrandFonts.number(16))
                            .foregroundStyle(BrandColors.text)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .brandCard()
    }
}
