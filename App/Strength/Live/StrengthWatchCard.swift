import Insights
import SwiftUI
import TrainingCore

private typealias C = StrengthWatchCardConstants
private typealias T = StrengthLiveText

struct StrengthWatchCard: View {
    let plan: LiveStrengthPlan
    let onResend: () -> Void

    var body: some View {
        let _ = StrengthLiveModel.shared.plansRevision
        let name = WatchLink.shared.deviceName
        let ready = WorkoutSender.isOnWatch(plan)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Circle().fill(Color.black)
                    .overlay(Circle().stroke(BrandColors.line, lineWidth: C.ringWidth))
                    .overlay(Circle().fill(name == nil ? BrandColors.dim : ready ? BrandColors.accent : BrandColors.attention).frame(width: C.dotSize, height: C.dotSize))
                    .frame(width: C.dialSize, height: C.dialSize)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name ?? T.watchFallbackName).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                    Text(name == nil ? T.watchNone : ready ? T.watchReady(plan.title) : T.watchPending(plan.title))
                        .font(.caption).foregroundStyle(name != nil && !ready ? BrandColors.attention : BrandColors.dim)
                }
            }
            if name == nil {
                button(T.watchChoose, primary: true) { WatchLink.shared.selectDevice() }
            } else if ready {
                hint(Text(T.watchHintPrefix) + Text(T.watchHintApp).bold().foregroundStyle(BrandColors.text) + Text(T.watchHintSuffix), tint: BrandColors.accent)
            } else {
                hint(Text(T.watchPendingHint), tint: BrandColors.attention)
                button(T.watchResend, primary: false, action: onResend)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func hint(_ text: Text, tint: Color) -> some View {
        text.font(.footnote).foregroundStyle(BrandColors.dim)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(tint.opacity(C.hintOpacity), in: .dsInner)
    }

    private func button(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: C.buttonHeight)
        }
        .buttonStyle(.plain)
        .foregroundStyle(primary ? BrandColors.onAccent : BrandColors.text)
        .background(primary ? BrandColors.accentFill : BrandColors.line, in: .dsInner)
    }
}
