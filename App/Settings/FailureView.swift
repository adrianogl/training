import SwiftUI

struct FailureView: View {
    let failure: SyncFailure

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(BrandColors.race)
            if failure.suggestsNewKey {
                Link("Criar chave nova no Garmin Connect", destination: AppConstants.createKeyURL)
            }
        }
    }
}
