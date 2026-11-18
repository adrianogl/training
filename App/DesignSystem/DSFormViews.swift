import SwiftUI

struct DSTextField: View {
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
            .frame(height: DSFieldConstants.height)
            .background(BrandColors.card, in: RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous).stroke(BrandColors.cardBorder))
            .accessibilityLabel(label)
        }
    }
}
