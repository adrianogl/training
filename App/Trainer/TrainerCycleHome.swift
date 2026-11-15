import Insights
import SwiftUI

struct TrainerCycleBanner: View {
    let review: TrainerCycleReview
    let dated: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("✓").foregroundStyle(BrandColors.accent).accessibilityHidden(true)
            (Text(TrainerCycleText.bannerTitle).fontWeight(.bold).foregroundStyle(BrandColors.accent)
                + Text(" \(TrainerCycleText.banner(review, dated: dated))").foregroundStyle(BrandColors.text))
                .font(.footnote)
            Spacer(minLength: 6)
            Text(TrainerCycleText.bannerAction).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(BrandColors.accentGlow, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(BrandColors.accent.opacity(0.35), lineWidth: 1))
    }
}

struct TrainerCycleSummaryRow: View {
    let summary: TrainerCycleSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(summary.title).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
            Text(TrainerCycleText.summaryLine(summary)).font(.caption).foregroundStyle(BrandColors.dim)
        }
        .brandCard()
    }
}
