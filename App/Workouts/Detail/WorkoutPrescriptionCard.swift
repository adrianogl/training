import Insights
import SwiftUI

struct WorkoutPrescriptionCard: View {
    let prescription: WorkoutPrescription
    let bands: [TrainerZoneBand]

    var body: some View {
        let workout = prescription.workout
        VStack(alignment: .leading, spacing: 12) {
            numbers
            if !workout.steps.isEmpty {
                Divider().overlay(BrandColors.line)
                TrainerShapeChart(bars: TrainerText.shapeBars(workout.steps))
                TrainerStepList(rows: TrainerText.stepRows(workout), bands: bands)
            }
            if let rationale = prescription.rationale {
                Divider().overlay(BrandColors.line)
                why(rationale)
            }
            NavigationLink { TrainerDayView(iso: prescription.iso) } label: {
                CardLinkFooter(title: WorkoutPrescriptionText.dayLink)
            }
            .buttonStyle(.cardLink)
        }
        .brandCard()
    }

    private var numbers: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(prescription.numbers) { item in
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.value).font(BrandFonts.number(17)).foregroundStyle(BrandColors.text).lineLimit(1).minimumScaleFactor(0.7)
                    Text(item.label).font(.caption2).foregroundStyle(BrandColors.dim)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func why(_ rationale: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            DSCardLabel(WorkoutPrescriptionText.whyLabel)
            Text(rationale).font(.footnote).foregroundStyle(BrandColors.text)
            if let method = prescription.methodLine {
                Text(method).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.dim)
            }
        }
    }
}
