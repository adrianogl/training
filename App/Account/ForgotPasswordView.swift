import SwiftUI

struct ForgotPasswordView: View {
    let model: AccountModel
    @Binding var screen: AccountScreen
    @State private var email = ""
    @State private var sent = false

    private typealias C = AccountConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if sent {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 44))
                    .foregroundStyle(BrandColors.accent)
                Text(C.forgotSentTitle).font(.largeTitle.bold()).foregroundStyle(BrandColors.text)
                Text(C.forgotSentText).foregroundStyle(BrandColors.dim)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(C.forgotTitle).font(.largeTitle.bold()).foregroundStyle(BrandColors.text)
                    Text(C.forgotSubtitle).foregroundStyle(BrandColors.dim)
                }
                AccountField(label: C.emailLabel, text: $email, content: .username, keyboard: .emailAddress)
                AccountMessage(error: model.errorMessage, notice: nil)
                AccountPrimaryButton(title: C.sendLink, isWorking: model.isWorking, disabled: email.isEmpty) {
                    Task { sent = await model.forgotPassword(email: email) }
                }
            }
            Button(C.backToLogin) { screen = .login }
                .font(.subheadline)
                .foregroundStyle(BrandColors.accent)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }
}
