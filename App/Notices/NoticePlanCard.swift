import SwiftUI

struct NoticePlanCard<Status: View>: View {
    private typealias C = NoticeInboxViewConstants

    let entry: NoticeEntry
    let onOpen: () -> Void
    @ViewBuilder var status: Status

    var body: some View {
        VStack(alignment: .leading, spacing: C.cardSpacing) {
            VStack(alignment: .leading, spacing: C.cardSpacing) {
                HStack {
                    Text(NoticeInboxText.fullDate(entry.deliveredAt))
                    Spacer(minLength: DSSpacing.s2)
                    Text(NoticeInboxText.planSource)
                }
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
                HStack(spacing: C.titleDotSpacing) {
                    if !entry.isRead {
                        Circle().fill(BrandColors.accent).frame(width: C.dotSize, height: C.dotSize)
                    }
                    Text(NoticeInboxText.title(entry)).font(.headline).foregroundStyle(BrandColors.text)
                }
                Text(entry.text).font(.subheadline).foregroundStyle(BrandColors.text).fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .accessibilityElement(children: .combine)
            status
            Button(action: onOpen) {
                CardLinkFooter(title: NoticeInboxText.planLink)
            }
            .buttonStyle(.cardLink)
        }
        .brandCard()
    }
}

extension NoticePlanCard where Status == EmptyView {
    init(entry: NoticeEntry, onOpen: @escaping () -> Void) {
        self.init(entry: entry, onOpen: onOpen) { EmptyView() }
    }
}
