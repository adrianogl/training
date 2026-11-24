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
                    .font(.subheadline.weight(.semibold))
                    .frame(width: C.bellIconSize, height: C.bellIconSize)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .tint(BrandColors.accent)
            .controlSize(.small)
            .overlay(alignment: .topTrailing) { badge(inbox.unreadCount) }
            .accessibilityLabel(NoticeInboxText.bellLabel(unread: inbox.unreadCount))
            .sheet(isPresented: $showsList) {
                NoticeInboxView(inbox: inbox)
            }
        }
    }

    @ViewBuilder
    private func badge(_ count: Int) -> some View {
        if count > 0 {
            Text(NoticeInboxText.badge(count))
                .font(.caption2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, DSSpacing.s1)
                .frame(minWidth: C.badgeMinSize, minHeight: C.badgeMinSize)
                .background(BrandColors.danger, in: Capsule())
                .overlay(Capsule().strokeBorder(BrandColors.background, lineWidth: C.badgeOutline))
                .offset(x: C.badgeOffset, y: -C.badgeOffset)
                .accessibilityHidden(true)
        }
    }
}
