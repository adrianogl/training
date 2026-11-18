import SwiftUI

struct SignupView: View {
    let model: AccountModel
    @Binding var screen: AccountScreen
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var localError: String?

    private typealias C = AccountConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(C.signupTitle).font(BrandFonts.largeTitle).foregroundStyle(BrandColors.text)
                Text(C.signupSubtitle).foregroundStyle(BrandColors.dim)
                if model.legacyKey?() != nil {
                    Text(C.legacyNote).font(.footnote).foregroundStyle(BrandColors.accent)
                }
            }
            DSTextField(label: C.nameLabel, text: $name, content: .name)
            DSTextField(label: C.emailLabel, text: $email, content: .username, keyboard: .emailAddress)
            DSTextField(label: C.passwordLabel, text: $password, secure: true, content: .newPassword)
            Text(C.passwordHint).font(.caption).foregroundStyle(BrandColors.dim)
            DSTextField(label: C.confirmLabel, text: $confirmation, secure: true, content: .newPassword)
            AccountMessage(error: localError ?? model.errorMessage, notice: nil)
            AccountPrimaryButton(title: C.create, isWorking: model.isWorking, disabled: name.isEmpty || email.isEmpty || password.isEmpty) {
                submit()
            }
            HStack(spacing: 4) {
                Text(C.haveAccount).foregroundStyle(BrandColors.dim)
                Button(C.enter) { screen = .login }.foregroundStyle(BrandColors.accent)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }

    private func submit() {
        localError = nil
        guard password.count >= C.passwordMinLength else {
            localError = C.shortPassword
            return
        }
        guard password == confirmation else {
            localError = C.mismatch
            return
        }
        Task { _ = await model.signup(name: name, email: email, password: password) }
    }
}
