import SwiftUI

struct OverloadCard: View {
    let alert: OverloadAlert

    private typealias C = OverloadConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(C.title, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(BrandColors.attention)
            Text(String(format: C.summaryFormat, alert.days)).font(.subheadline).foregroundStyle(BrandColors.text)
            if let now = alert.restingNow, let base = alert.restingBase {
                row(C.resting, String(format: C.baseFormat, base), "\(now)", flagged: alert.restingHigh)
            }
            if let now = alert.hrvNow, let base = alert.hrvBase {
                row(C.hrv, String(format: C.baseHrvFormat, base), "\(now)", flagged: alert.hrvLow)
            }
            if let ratio = alert.ratio {
                row(C.load, C.loadRange, TodayText.decimal(ratio, fractionDigits: 1), flagged: alert.loadHigh)
            }
            Text(C.advice).font(.caption).foregroundStyle(BrandColors.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrandConstants.cardPadding)
        .background(BrandColors.attention.opacity(0.1), in: RoundedRectangle(cornerRadius: BrandConstants.cardCornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: BrandConstants.cardCornerRadius, style: .continuous).strokeBorder(BrandColors.attention.opacity(0.5), lineWidth: 1))
    }

    private func row(_ label: String, _ base: String, _ value: String, flagged: Bool) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(BrandColors.text)
            Spacer()
            Text(base).font(BrandFonts.number(13)).foregroundStyle(BrandColors.dim)
            Text(value).font(BrandFonts.number(15)).foregroundStyle(flagged ? BrandColors.rest : BrandColors.text)
                .frame(minWidth: 40, alignment: .trailing)
        }
    }
}
