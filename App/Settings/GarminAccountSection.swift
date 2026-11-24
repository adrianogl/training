import SwiftUI

struct GarminAccountSection: View {
    let model: GarminAccountModel
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var confirmsDisconnect = false

    private typealias C = GarminAccountConstants

    var body: some View {
        Section {
            if model.isSignedIn {
                LabeledContent(C.sectionTitle) {
                    Text(C.connected).foregroundStyle(BrandColors.accent)
                }
                Button(C.disconnect, role: .destructive) { confirmsDisconnect = true }
                    .confirmationDialog(C.disconnectTitle, isPresented: $confirmsDisconnect, titleVisibility: .visible) {
                        Button(C.disconnect, role: .destructive) { model.signOut() }
                        Button(C.cancel, role: .cancel) {}
                    } message: {
                        Text(C.disconnectMessage)
                    }
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
                DSNotice(tone: model.messageIsInfo ? .info : .error, text: message)
            }
        } header: {
            DSSectionTitle(C.sectionTitle)
        } footer: {
            Text(C.footer)
        }
    }
}
