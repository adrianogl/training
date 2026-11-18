import SwiftUI

struct VerifyEmailView: View {
    let model: AccountModel
    let token: String
    let close: () -> Void
    @State private var state = VerifyState.checking

    private typealias C = AccountConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch state {
            case .checking:
                DSLoadingState(title: C.verifying)
            case .verified:
                badge("checkmark", tint: BrandColors.accent)
                Text(C.verifiedTitle).font(BrandFonts.largeTitle).foregroundStyle(BrandColors.text)
                Text(C.verifiedText).foregroundStyle(BrandColors.dim)
                AccountPrimaryButton(title: C.continueLabel, action: close)
            case .expired:
                badge("exclamationmark", tint: BrandColors.attention)
                Text(C.expiredTitle).font(BrandFonts.largeTitle).foregroundStyle(BrandColors.text)
                Text(C.expiredText).foregroundStyle(BrandColors.dim)
                if model.isSignedIn {
                    AccountMessage(error: nil, notice: model.notice)
                    Button(C.resend) { Task { await model.resendVerification() } }
                        .buttonStyle(.ds(.secondary))
                }
                Button(C.close, action: close)
                    .buttonStyle(.ds(.text))
                    .frame(maxWidth: .infinity)
            }
        }
        .task {
            guard state == .checking else { return }
            state = await model.verifyEmail(token: token) ? .verified : .expired
        }
    }

    private func badge(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 64, height: 64)
            .background(tint.opacity(0.14), in: Circle())
    }
}
