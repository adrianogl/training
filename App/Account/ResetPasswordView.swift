import SwiftUI

struct ResetPasswordView: View {
    let model: AccountModel
    let token: String
    let close: () -> Void
    @State private var password = ""
    @State private var confirmation = ""
    @State private var localError: String?

    private typealias C = AccountConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(C.resetTitle).font(BrandFonts.largeTitle).foregroundStyle(BrandColors.text)
                Text(C.resetSubtitle).foregroundStyle(BrandColors.dim)
            }
            DSTextField(label: C.newPasswordLabel, text: $password, secure: true, content: .newPassword)
            Text(C.passwordHint).font(.caption).foregroundStyle(BrandColors.dim)
            DSTextField(label: C.confirmNewLabel, text: $confirmation, secure: true, content: .newPassword)
            AccountMessage(error: localError ?? model.errorMessage, notice: nil)
            AccountPrimaryButton(title: C.savePassword, isWorking: model.isWorking, disabled: password.isEmpty) {
                submit()
            }
            Button(C.backToLogin, action: close)
                .font(.subheadline)
                .foregroundStyle(BrandColors.accent)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    private func submit() {
        localError = AccountPasswordRule.problem(password: password, confirmation: confirmation)
        guard localError == nil else { return }
        Task {
            if await model.resetPassword(token: token, password: password) { close() }
        }
    }
}
