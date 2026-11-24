import Insights
import SwiftUI

struct RaceCandidatesCard: View {
    let candidates: [RaceCandidate]
    let onConfirm: (Int64) -> Void
    let onDecline: (Int64) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                DSCardLabel(RacesConstants.candidatesTitle)
                Spacer()
                Text("\(candidates.count)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(BrandColors.attention)
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
    }
}
