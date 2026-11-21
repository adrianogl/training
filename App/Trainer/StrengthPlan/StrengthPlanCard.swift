import SwiftUI

struct StrengthPlanCard: View {
    let summary: StrengthPlanCardSummary
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: StrengthPlanUIConstants.spacing) {
            StrengthPlanCardHeader(left: summary.label, right: summary.builder)
            Text(summary.title).font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
            Text(summary.period).font(.footnote).foregroundStyle(BrandColors.dim)
            StrengthPlanMeter(share: summary.share)
            Text(summary.progress).font(.footnote).foregroundStyle(BrandColors.dim)
            Button(action: onEdit) { StrengthPlanFooterLink(title: StrengthPlanText.editPlan) }
                .buttonStyle(.plain)
        }
        .brandCard()
    }
}

struct StrengthMFITCard: View {
    let summary: StrengthMFITSummary

    var body: some View {
        VStack(alignment: .leading, spacing: StrengthPlanUIConstants.spacing) {
            StrengthPlanCardHeader(left: StrengthPlanText.mfitLabel, right: StrengthPlanText.mfitTeacher)
            Text(summary.title).font(.headline).foregroundStyle(BrandColors.text)
            Text(summary.subtitle).font(.footnote).foregroundStyle(BrandColors.dim)
        }
        .brandCard()
    }
}
