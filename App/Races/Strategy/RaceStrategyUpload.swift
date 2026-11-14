import GarminAPI
import Metrics
import SwiftUI
import TrainingCore

enum RaceStrategyUpload {
    static func steps(_ strategy: [KmPlan], distance: Double) -> [UploadStep] {
        let full = RacesConstants.metersPerKm
        return strategy.sorted { $0.index < $1.index }.map { km in
            let meters = min(full, distance - Double(km.index) * full)
            return UploadStep(
                meters: max(meters, 1),
                fastestSecondsPerKm: km.pace - RaceStrategyConstants.bandSeconds,
                slowestSecondsPerKm: km.pace + RaceStrategyConstants.bandSeconds
            )
        }
    }
}

struct RaceStrategyUploadCard: View {
    let info: RaceInfo
    let strategy: [KmPlan]
    let client: GarminAccountClient?
    @State private var confirming = false
    @State private var sending = false
    @State private var message: String?

    private typealias C = RaceStrategyConstants

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .font(.title2)
                .foregroundStyle(BrandColors.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(C.title).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                Text(message ?? (client == nil ? C.needsLogin : String(format: C.detailFormat, strategy.count, Int(C.bandSeconds))))
                    .font(.caption)
                    .foregroundStyle(BrandColors.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if sending {
                ProgressView()
            } else {
                Button(C.send) { confirming = true }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BrandColors.onAccent)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(BrandColors.accentFill, in: Capsule())
                    .buttonStyle(.plain)
                    .disabled(client == nil || strategy.isEmpty)
                    .opacity(client == nil || strategy.isEmpty ? 0.4 : 1)
            }
        }
        .brandCard()
        .confirmationDialog(C.confirmTitle, isPresented: $confirming, titleVisibility: .visible) {
            Button(C.confirmAction) { send() }
            Button(RacesConstants.cancel, role: .cancel) {}
        } message: {
            Text(String(format: C.confirmMessageFormat, RacesText.dateText(info.day)))
        }
    }

    private func send() {
        guard let client else { return }
        sending = true
        Task {
            do {
                _ = try await GarminWorkoutUpload.upload(
                    client: client,
                    name: String(format: C.workoutNameFormat, info.name),
                    steps: RaceStrategyUpload.steps(strategy, distance: info.distance),
                    day: info.day
                )
                message = C.sent
            } catch {
                message = C.failed
            }
            sending = false
        }
    }
}
