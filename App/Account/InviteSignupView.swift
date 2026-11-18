import RemoteSync
import SwiftUI

struct InviteSignupView: View {
    let model: AccountModel
    let token: String
    let close: () -> Void
    @State private var preview: InvitePreview?
    @State private var loaded = false
    @State private var name = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var localError: String?

    private typealias C = AccountConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.isSignedIn {
                Text(C.inviteSignedInTitle).font(BrandFonts.largeTitle).foregroundStyle(BrandColors.text)
                Text(C.inviteSignedInText).foregroundStyle(BrandColors.dim)
                AccountPrimaryButton(title: C.close, action: close)
            } else if let preview {
                form(preview)
            } else if loaded {
                Text(C.inviteExpiredTitle).font(BrandFonts.largeTitle).foregroundStyle(BrandColors.text)
                Text(model.errorMessage ?? C.invalidInvite).foregroundStyle(BrandColors.dim)
                AccountPrimaryButton(title: C.close, action: close)
            } else {
                BrandLoader(size: .mini).frame(maxWidth: .infinity)
            }
        }
        .task {
            guard !model.isSignedIn, preview == nil else { return }
            preview = await model.invitePreview(token: token)
            name = preview?.name ?? ""
            loaded = true
        }
    }

    @ViewBuilder
    private func form(_ preview: InvitePreview) -> some View {
        if let inviter = preview.inviterName {
            Text(String(format: C.inviteFromFormat, inviter))
                .font(.caption.weight(.bold))
                .foregroundStyle(BrandColors.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(BrandColors.accentFill.opacity(0.15), in: Capsule())
        }
        VStack(alignment: .leading, spacing: 6) {
            Text(C.signupTitle).font(BrandFonts.largeTitle).foregroundStyle(BrandColors.text)
            Text(String(format: C.inviteSubtitleFormat, preview.expiresAt.formatted(.dateTime.day().month(.twoDigits))))
                .foregroundStyle(BrandColors.dim)
        }
        AccountField(label: C.nameLabel, text: $name, content: .name)
        if let email = preview.email {
            VStack(alignment: .leading, spacing: 6) {
                Text(C.emailLabel).font(.footnote).foregroundStyle(BrandColors.dim)
                Text(email)
                    .foregroundStyle(BrandColors.dim)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: C.fieldHeight, alignment: .leading)
                    .background(BrandColors.track, in: RoundedRectangle(cornerRadius: C.cornerRadius))
            }
        }
        AccountField(label: C.passwordLabel, text: $password, secure: true, content: .newPassword)
        Text(C.passwordHint).font(.caption).foregroundStyle(BrandColors.dim)
        AccountField(label: C.confirmLabel, text: $confirmation, secure: true, content: .newPassword)
        AccountMessage(error: localError ?? model.errorMessage, notice: nil)
        AccountPrimaryButton(title: C.create, isWorking: model.isWorking, disabled: name.isEmpty || password.isEmpty || preview.email == nil) {
            submit(email: preview.email ?? "")
        }
    }

    private func submit(email: String) {
        localError = AccountPasswordRule.problem(password: password, confirmation: confirmation)
        guard localError == nil else { return }
        Task {
            if await model.signup(name: name, email: email, password: password, inviteToken: token) { close() }
        }
    }
}
