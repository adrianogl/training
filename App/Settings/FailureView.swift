import SwiftUI

struct FailureView: View {
    let failure: SyncFailure
    var onKeyHelp: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(BrandColors.race)
            if failure.suggestsNewKey {
                Link("Criar chave nova no Garmin Connect", destination: AppConstants.createKeyURL)
            }
            if failure.needsKeyHelp, let onKeyHelp {
                Button(GarminKeyHelpConstants.openLink, action: onKeyHelp)
            }
        }
    }
}
