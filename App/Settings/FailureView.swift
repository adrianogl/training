import SwiftUI

struct FailureView: View {
    let failure: SyncFailure
    var onKeyHelp: (() -> Void)?

    var body: some View {
        DSNotice(tone: .error, text: failure.message) {
            if failure.suggestsNewKey {
                Link(FailureViewConstants.newKey, destination: AppConstants.createKeyURL).buttonStyle(.ds(.text))
            }
            if failure.needsKeyHelp, let onKeyHelp {
                Button(GarminKeyHelpConstants.openLink, action: onKeyHelp).buttonStyle(.ds(.text))
            }
        }
    }
}
