import SwiftUI

struct TrainerLegSwapCard: View {
    let swap: TrainerLegSwap
    let onSwap: () -> Void
    let onKeep: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(TrainerMFITText.swapHeadline(swap)).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.attention)
            Text(TrainerMFITText.swapBody(swap)).font(.footnote).foregroundStyle(BrandColors.text)
            HStack(spacing: 8) {
                Button(TrainerMFITConstants.swapButton, action: onSwap).buttonStyle(TrainerPrimaryButtonStyle())
                Button(TrainerMFITConstants.keepButton, action: onKeep).buttonStyle(TrainerSecondaryButtonStyle())
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandColors.attention.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(BrandColors.attention.opacity(0.55), lineWidth: 1.5))
    }
}
