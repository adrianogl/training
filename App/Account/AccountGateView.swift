import SwiftUI

struct AccountGateView: View {
    let model: AccountModel
    @State private var screen = AccountScreen.login

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Logo(showsTagline: true)
                    .padding(.top, 48)
                Group {
                    switch screen {
                    case .login: LoginView(model: model, screen: $screen)
                    case .signup: SignupView(model: model, screen: $screen)
                    case .forgot: ForgotPasswordView(model: model, screen: $screen)
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
        .onChange(of: screen) { model.clearMessages() }
    }
}
