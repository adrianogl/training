import SwiftUI

enum DSNoticeTone {
    case success, attention, error, info

    var color: Color {
        switch self {
        case .success: BrandColors.accent
        case .attention: BrandColors.attention
        case .error: BrandColors.danger
        case .info: BrandColors.dim
        }
    }

    var symbol: String {
        switch self {
        case .success: "checkmark"
        case .attention, .error: "exclamationmark"
        case .info: "info"
        }
    }
}

struct DSNotice<Trailing: View, Content: View>: View {
    let tone: DSNoticeTone
    var title: String?
    let text: String?
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous)
        HStack(alignment: .top, spacing: DSSpacing.s3) {
            Image(systemName: tone.symbol)
                .font(.system(size: DSNoticeConstants.symbolSize, weight: .heavy))
                .foregroundStyle(BrandColors.onAccent)
                .frame(width: DSNoticeConstants.iconSize, height: DSNoticeConstants.iconSize)
                .background(tone == .success ? BrandColors.accentFill : tone.color, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DSSpacing.s2) {
                VStack(alignment: .leading, spacing: 2) {
                    if let title {
                        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                    }
                    if let text {
                        Text(text).font(.footnote).foregroundStyle(title == nil ? BrandColors.text : BrandColors.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, DSNoticeConstants.horizontalPadding)
        .padding(.vertical, DSNoticeConstants.verticalPadding)
        .background(tone.color.opacity(DSNoticeConstants.fillOpacity), in: shape)
        .overlay(shape.strokeBorder(tone.color.opacity(DSNoticeConstants.borderOpacity), lineWidth: 1))
    }
}

extension DSNotice where Trailing == EmptyView, Content == EmptyView {
    init(tone: DSNoticeTone, title: String? = nil, text: String?) {
        self.init(tone: tone, title: title, text: text, trailing: { EmptyView() }, content: { EmptyView() })
    }
}

extension DSNotice where Content == EmptyView {
    init(tone: DSNoticeTone, title: String? = nil, text: String?, trailing: Trailing) {
        self.init(tone: tone, title: title, text: text, trailing: { trailing }, content: { EmptyView() })
    }
}

extension DSNotice where Trailing == EmptyView {
    init(tone: DSNoticeTone, title: String? = nil, text: String?, @ViewBuilder content: () -> Content) {
        self.init(tone: tone, title: title, text: text, trailing: { EmptyView() }, content: content)
    }
}
