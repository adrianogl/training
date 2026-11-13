import SwiftUI

struct GarminAccountSection: View {
    let model: GarminAccountModel
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""

    private typealias C = GarminAccountConstants

    var body: some View {
        Section {
            if model.isSignedIn {
                LabeledContent(C.sectionTitle) {
                    Text(C.connected).foregroundStyle(BrandColors.accent)
                }
                Button(C.signOut, role: .destructive) { model.signOut() }
            } else if case .needsCode = model.phase {
                TextField(C.codePlaceholder, text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                Button(C.confirmCode) {
                    Task { await model.verify(code: code) }
                }
                .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)
            } else {
                TextField(C.emailPlaceholder, text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField(C.passwordPlaceholder, text: $password)
                    .textContentType(.password)
                Button(model.phase == .working ? C.signingIn : C.signIn) {
                    Task {
                        await model.signIn(email: email, password: password)
                        password = ""
                    }
                }
                .disabled(model.phase == .working || email.isEmpty || password.isEmpty)
            }
            if let message = model.message {
                Text(message).font(.footnote).foregroundStyle(BrandColors.attention)
            }
        } header: {
            Text(C.sectionTitle)
        } footer: {
            Text(C.footer)
        }
    }
}
