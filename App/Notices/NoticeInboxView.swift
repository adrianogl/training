import SwiftUI

struct NoticeInboxView: View {
    private typealias C = NoticeInboxViewConstants

    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var app: AppModel?
    let inbox: NoticeInboxModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.s4) {
                HStack {
                    Button(NoticeInboxText.markAllRead) { inbox.markAllRead() }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(BrandColors.accent)
                        .disabled(inbox.unreadCount == 0)
                    Spacer(minLength: DSSpacing.s2)
                    Button { dismiss() } label: {
                        Image(systemName: C.closeSymbol).font(.subheadline.weight(.bold))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .tint(BrandColors.text)
                    .accessibilityLabel(NoticeInboxText.close)
                }
                .padding(.top, DSSpacing.s5)
                Text(NoticeInboxText.title)
                    .font(BrandFonts.largeTitle)
                    .foregroundStyle(BrandColors.text)
                    .accessibilityAddTraits(.isHeader)
                if inbox.entries.isEmpty {
                    Text(NoticeInboxText.empty).font(.subheadline).foregroundStyle(BrandColors.dim)
                }
                section(NoticeInboxText.fresh, entries: inbox.fresh, highlightsPlan: true)
                section(NoticeInboxText.earlier, entries: inbox.earlier, highlightsPlan: false)
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.bottom, DSSpacing.s6)
        }
        .background(BrandBackground())
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func section(_ title: String, entries: [NoticeEntry], highlightsPlan: Bool) -> some View {
        if !entries.isEmpty {
            let plans = highlightsPlan ? entries.filter { $0.link == C.planLink } : []
            let rows = entries.filter { !plans.contains($0) }
            VStack(alignment: .leading, spacing: DSSpacing.s3) {
                DSSectionTitle(title).padding(.top, DSSpacing.s2)
                ForEach(plans) { entry in
                    NoticePlanCard(entry: entry) { open(entry) } status: { garminStatus }
                }
                if !rows.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 { Divider().overlay(BrandColors.line).padding(.leading, C.rowDividerInset) }
                            Button { open(entry) } label: { NoticeRow(entry: entry) }
                                .buttonStyle(.cardLink)
                        }
                    }
                    .padding(.horizontal, DSSpacing.s4)
                    .padding(.vertical, DSSpacing.s1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BrandColors.card, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous).strokeBorder(BrandColors.cardBorder, lineWidth: 1))
                }
            }
        }
    }

    @ViewBuilder
    private var garminStatus: some View {
        if let app, app.trainer.sendsToGarmin {
            NoticeGarminRow(pending: app.trainer.pendingGarminSends(), sending: app.trainer.isSendingToGarmin) {
                Task { await app.sendPendingToGarmin() }
            }
        }
    }

    private func open(_ entry: NoticeEntry) {
        dismiss()
        inbox.open(entry)
    }
}
