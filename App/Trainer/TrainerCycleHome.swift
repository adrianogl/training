import Insights
import SwiftUI

struct TrainerCycleBanner: View {
    let review: TrainerCycleReview
    let dated: Bool

    var body: some View {
        DSNotice(tone: .success, title: TrainerCycleText.bannerTitle, text: TrainerCycleText.banner(review, dated: dated), trailing: CardLinkChevron())
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
