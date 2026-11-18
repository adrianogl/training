import SwiftUI

struct TrainerLegSwapCard: View {
    let swap: TrainerLegSwap
    let onSwap: () -> Void
    let onKeep: () -> Void

    var body: some View {
        DSNotice(tone: .attention, title: TrainerMFITText.swapHeadline(swap), text: TrainerMFITText.swapBody(swap)) {
            HStack(spacing: DSSpacing.s2) {
                Button(TrainerMFITConstants.swapButton, action: onSwap).buttonStyle(.ds(.primary))
                Button(TrainerMFITConstants.keepButton, action: onKeep).buttonStyle(.ds(.secondary))
            }
        }
    }
}
