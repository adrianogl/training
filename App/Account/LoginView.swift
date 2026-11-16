import SwiftUI

struct LoginView: View {
    let model: AccountModel
    @Binding var screen: AccountScreen
    @State private var email = ""
    @State private var password = ""

    private typealias C = AccountConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(C.loginTitle).font(BrandFonts.largeTitle).foregroundStyle(BrandColors.text)
                Text(C.loginSubtitle).foregroundStyle(BrandColors.dim)
            }
            AccountField(label: C.emailLabel, text: $email, content: .username, keyboard: .emailAddress)
            AccountField(label: C.passwordLabel, text: $password, secure: true, content: .password)
            Button(C.forgotLink) { screen = .forgot }
                .font(.subheadline)
                .foregroundStyle(BrandColors.accent)
                .frame(maxWidth: .infinity, alignment: .trailing)
            AccountMessage(error: model.errorMessage, notice: model.notice)
            AccountPrimaryButton(title: C.enter, isWorking: model.isWorking, disabled: email.isEmpty || password.isEmpty) {
                Task { _ = await model.login(email: email, password: password) }
            }
            HStack(spacing: 4) {
                Text(C.noAccount).foregroundStyle(BrandColors.dim)
                Button(C.create) { screen = .signup }.foregroundStyle(BrandColors.accent)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }
}
