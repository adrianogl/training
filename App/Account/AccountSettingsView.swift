import SwiftUI

struct AccountSettingsView: View {
    let model: AccountModel
    @State private var name = ""
    @State private var confirmsDelete = false

    private typealias C = AccountConstants

    var body: some View {
        Group {
            Section {
                TextField(C.nameLabel, text: $name)
                    .textContentType(.name)
                    .onSubmit { Task { await model.rename(name) } }
                LabeledContent(C.emailLabel, value: model.user?.email ?? "")
                if model.user?.emailVerified == false {
                    Button(C.resend) { Task { await model.resendVerification() } }
                }
            } header: {
                Text(C.accountTitle)
            } footer: {
                if model.user?.emailVerified == false { Text(C.unverified) }
            }
            Section {
                NavigationLink(C.changePasswordTitle) { ChangePasswordView(model: model) }
            }
            if !model.sessions.isEmpty {
                Section(C.sessionsTitle) {
                    ForEach(model.sessions) { session in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.device)
                                Text(session.current ? C.thisDevice : session.lastSeenAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(session.current ? BrandColors.accent : BrandColors.dim)
                            }
                            Spacer()
                            if !session.current {
                                Button(C.endSession) { Task { await model.endSession(session.id) } }
                                    .buttonStyle(.ds(.text))
                            }
                        }
                    }
                }
            }
            Section {
                Button(C.signOut) { Task { await model.signOut() } }
                Button(C.deleteAccount, role: .destructive) { confirmsDelete = true }
                    .confirmationDialog(C.deleteConfirmTitle, isPresented: $confirmsDelete, titleVisibility: .visible) {
                        Button(C.deleteAccount, role: .destructive) { Task { _ = await model.deleteAccount() } }
                        Button(C.cancel, role: .cancel) {}
                    } message: {
                        Text(C.deleteConfirmText)
                    }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    AccountMessage(error: model.errorMessage, notice: model.notice)
                    Text(C.deleteNote)
                }
            }
        }
        .task {
            name = model.user?.name ?? ""
            await model.refresh()
            name = model.user?.name ?? name
        }
    }
}
