import SwiftUI

struct AccountLinkSheet: View {
    let model: AccountModel
    let link: AccountLink
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Logo(showsTagline: true)
                    .padding(.top, 32)
                Group {
                    switch link {
                    case .invite(let token): InviteSignupView(model: model, token: token, close: close)
                    case .verify(let token): VerifyEmailView(model: model, token: token, close: close)
                    case .reset(let token): ResetPasswordView(model: model, token: token, close: close)
                    }
                }
                .frame(maxWidth: AccountConstants.formMaxWidth)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(BrandBackground())
    }

    private func close() {
        model.pendingLink = nil
        dismiss()
    }
}
