import SwiftUI

struct AccountField: View {
    let label: String
    @Binding var text: String
    var secure = false
    var content: UITextContentType?
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.footnote).foregroundStyle(BrandColors.dim)
            Group {
                if secure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                        .autocorrectionDisabled()
                }
            }
            .textContentType(content)
            .padding(.horizontal, 16)
            .frame(height: AccountConstants.fieldHeight)
            .background(BrandColors.card, in: RoundedRectangle(cornerRadius: AccountConstants.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: AccountConstants.cornerRadius).stroke(BrandColors.cardBorder))
            .accessibilityLabel(label)
        }
    }
}

struct AccountPrimaryButton: View {
    let title: String
    var isWorking = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(isWorking ? 0 : 1)
                if isWorking { BrandLoader(size: .mini) }
            }
            .font(.headline)
            .foregroundStyle(BrandColors.onAccent)
            .frame(maxWidth: .infinity, minHeight: AccountConstants.buttonHeight)
            .background(BrandColors.accentFill, in: RoundedRectangle(cornerRadius: AccountConstants.cornerRadius))
        }
        .buttonStyle(.plain)
        .disabled(disabled || isWorking)
        .opacity(disabled ? 0.5 : 1)
    }
}

struct AccountMessage: View {
    let error: String?
    let notice: String?

    var body: some View {
        if let error {
            Text(error).font(.footnote).foregroundStyle(BrandColors.danger)
        } else if let notice {
            Text(notice).font(.footnote).foregroundStyle(BrandColors.accent)
        }
    }
}
