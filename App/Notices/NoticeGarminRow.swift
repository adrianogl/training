import SwiftUI

struct NoticeGarminRow: View {
    private typealias C = NoticeInboxViewConstants

    let pending: Int
    let sending: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: DSSpacing.s3) {
            Image(systemName: C.garminSymbol)
                .font(.system(size: C.iconSymbolSize, weight: .semibold))
                .foregroundStyle(BrandColors.text)
                .frame(width: C.iconSize, height: C.iconSize)
                .background(BrandColors.iconTile, in: RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(NoticeInboxText.garmin).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.text)
                Text(pending > 0 ? NoticeInboxText.garminPending(pending) : NoticeInboxText.garminCurrent)
                    .font(.caption)
                    .foregroundStyle(pending > 0 ? BrandColors.attention : BrandColors.dim)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: DSSpacing.s2)
            if pending > 0 {
                Button(NoticeInboxText.garminSend, action: onSend)
                    .font(.footnote.weight(.bold))
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(BrandColors.accentFill)
                    .foregroundStyle(BrandColors.onAccent)
                    .controlSize(.small)
                    .disabled(sending)
            }
        }
        .padding(DSSpacing.s3)
        .background(BrandColors.background, in: RoundedRectangle(cornerRadius: DSRadius.medium, style: .continuous))
    }
}
