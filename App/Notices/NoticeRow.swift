import SwiftUI

struct NoticeRow: View {
    private typealias C = NoticeInboxViewConstants

    let entry: NoticeEntry

    var body: some View {
        HStack(spacing: C.rowSpacing) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(NoticeInboxText.title(entry)).font(.body.weight(.semibold)).foregroundStyle(BrandColors.text).lineLimit(1)
                Text(entry.text).font(.caption).foregroundStyle(BrandColors.dim).lineLimit(1)
            }
            Spacer(minLength: 0)
            if entry.isRead {
                Text(NoticeInboxText.when(entry.deliveredAt)).font(.caption2).foregroundStyle(BrandColors.dim)
            } else {
                Circle().fill(BrandColors.accent).frame(width: C.dotSize, height: C.dotSize)
            }
            CardLinkChevron()
        }
        .padding(.vertical, C.rowVerticalPadding)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(NoticeInboxText.rowLabel(entry))
        .accessibilityAddTraits(.isButton)
    }

    private var icon: some View {
        let style = C.icons.first { entry.link.hasPrefix($0.linkPrefix) } ?? C.defaultIcon
        return Image(systemName: style.symbol)
            .font(.system(size: C.iconSymbolSize, weight: .semibold))
            .foregroundStyle(foreground(style.tone))
            .frame(width: C.iconSize, height: C.iconSize)
            .background(background(style.tone), in: RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous))
            .accessibilityHidden(true)
    }

    private func foreground(_ tone: NoticeTone) -> Color {
        switch tone {
        case .neutral: BrandColors.text
        case .danger: BrandColors.danger
        case .record: BrandColors.record
        case .race: BrandColors.race
        }
    }

    private func background(_ tone: NoticeTone) -> Color {
        tone == .neutral ? BrandColors.iconTile : foreground(tone).opacity(C.toneFillOpacity)
    }
}
