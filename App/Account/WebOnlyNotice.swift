import SwiftUI

struct WebOnlyNotice: View {
    private typealias C = AccountConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(C.webOnlyTitle).font(.title3.bold()).foregroundStyle(BrandColors.text)
            Text(C.webOnlyText).foregroundStyle(BrandColors.dim)
            Text(C.siteLabel)
                .font(.headline)
                .foregroundStyle(BrandColors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 12))
            Link(destination: C.siteURL) {
                Text(C.openSite)
                    .font(.headline)
                    .foregroundStyle(BrandColors.onAccent)
                    .frame(maxWidth: .infinity, minHeight: C.buttonHeight)
                    .background(BrandColors.accentFill, in: RoundedRectangle(cornerRadius: C.cornerRadius))
            }
        }
        .padding(20)
        .background(BrandColors.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(BrandColors.cardBorder))
    }
}
