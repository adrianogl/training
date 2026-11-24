import SwiftUI

struct NoticeBellButton: View {
    private typealias C = NoticeInboxViewConstants

    @Environment(NoticeInboxModel.self) private var inbox: NoticeInboxModel?
    @State private var showsList = false

    var body: some View {
        if let inbox {
            Button {
                inbox.reload()
                showsList = true
            } label: {
                Image(systemName: C.bellSymbol)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(BrandColors.text)
                    .frame(width: C.bellTapSize, height: C.bellTapSize)
                    .overlay(alignment: .topTrailing) { unreadDot(inbox.unreadCount > 0) }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NoticeInboxText.bellLabel(unread: inbox.unreadCount))
            .sheet(isPresented: $showsList) {
                NoticeInboxView(inbox: inbox)
            }
        }
    }

    @ViewBuilder
    private func unreadDot(_ visible: Bool) -> some View {
        if visible {
            Circle()
                .fill(BrandColors.accentFill)
                .frame(width: C.bellDotSize, height: C.bellDotSize)
                .overlay(Circle().strokeBorder(BrandColors.background, lineWidth: C.bellDotOutline))
                .offset(x: -C.bellDotInset, y: C.bellDotInset)
                .accessibilityHidden(true)
        }
    }
}
