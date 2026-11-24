import Insights
import SwiftUI

struct RaceCandidateRow: View {
    let candidate: RaceCandidate
    let onConfirm: () -> Void
    let onDecline: () -> Void

    private var detailText: String {
        var parts = [WorkoutListModel.distanceText(candidate.distance), WorkoutListModel.clockText(candidate.seconds)]
        if let heartRate = candidate.averageHeartRate {
            parts.append("\(heartRate) \(RacesConstants.candidateHeartRateUnit)")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(RacesText.dateText(candidate.day)).font(.caption).foregroundStyle(BrandColors.dim)
                Text(candidate.name).font(.headline).foregroundStyle(BrandColors.text).lineLimit(2)
                Text(detailText).font(BrandFonts.number(15)).foregroundStyle(BrandColors.dim)
            }
            HStack(spacing: 10) {
                Button(RacesConstants.confirmCandidate, action: onConfirm).buttonStyle(.ds(.primary))
                Button(RacesConstants.declineCandidate, action: onDecline).buttonStyle(.ds(.secondary))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
