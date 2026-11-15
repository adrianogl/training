import Insights
import SwiftUI

struct RaceCandidatesCard: View {
    let candidates: [RaceCandidate]
    let onConfirm: (Int64) -> Void
    let onDecline: (Int64) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(RacesConstants.candidatesTitle)
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(BrandColors.attention)
                Spacer()
                Text("\(candidates.count)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(BrandColors.dim)
            }
            ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                if index > 0 { Divider().overlay(BrandColors.line) }
                RaceCandidateRow(
                    candidate: candidate,
                    onConfirm: { onConfirm(candidate.activityId) },
                    onDecline: { onDecline(candidate.activityId) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
        .overlay {
            RoundedRectangle(cornerRadius: BrandConstants.cardCornerRadius, style: .continuous)
                .strokeBorder(BrandColors.attention.opacity(0.4), lineWidth: 1)
        }
    }
}
