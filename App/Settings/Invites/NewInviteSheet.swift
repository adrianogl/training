import RemoteSync
import SwiftUI

struct NewInviteSheet: View {
    let model: InvitesModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var channel = InviteChannel.email
    @State private var email = ""

    private typealias C = InvitesConstants

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(C.nameLabel, text: $name)
                        .textContentType(.name)
                    Picker(C.channelLabel, selection: $channel) {
                        ForEach(InviteChannel.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if channel == .email {
                        TextField(C.emailLabel, text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        AccountMessage(error: model.errorMessage, notice: nil)
                        Text(C.hint)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BrandBackground())
            .navigationTitle(C.newInvite)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(C.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(channel == .email ? C.send : C.create) {
                        Task { if await model.create(name: name, channel: channel, email: email) { dismiss() } }
                    }
                    .disabled(!canSend || model.isWorking)
                }
            }
        }
    }

    private var canSend: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (channel != .email || email.contains("@"))
    }
}
