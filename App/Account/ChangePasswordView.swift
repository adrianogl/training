import SwiftUI

struct ChangePasswordView: View {
    let model: AccountModel
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var next = ""
    @State private var confirmation = ""
    @State private var endOthers = true
    @State private var localError: String?

    private typealias C = AccountConstants

    var body: some View {
        Form {
            Section {
                SecureField(C.currentPasswordLabel, text: $current).textContentType(.password)
            }
            Section {
                SecureField(C.newPasswordLabel, text: $next).textContentType(.newPassword)
                SecureField(C.confirmNewLabel, text: $confirmation).textContentType(.newPassword)
            } footer: {
                Text(C.newPasswordHint)
            }
            Section {
                Toggle(C.endOthers, isOn: $endOthers)
            }
            Section {
                Button(C.savePassword) { submit() }
                    .disabled(current.isEmpty || next.isEmpty || model.isWorking)
            } footer: {
                AccountMessage(error: localError ?? model.errorMessage, notice: nil)
            }
        }
        .scrollContentBackground(.hidden)
        .background(BrandBackground())
        .navigationTitle(C.changePasswordTitle)
        .toolbarTitleDisplayMode(.inline)
    }

    private func submit() {
        localError = nil
        guard next.count >= C.passwordMinLength else {
            localError = C.shortPassword
            return
        }
        guard next == confirmation else {
            localError = C.mismatch
            return
        }
        Task {
            if await model.changePassword(current: current, next: next, endOtherSessions: endOthers) { dismiss() }
        }
    }
}
